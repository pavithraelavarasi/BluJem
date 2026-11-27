'use strict';

const catalyst = require('zcatalyst-sdk-node');
const crypto = require('crypto');
const { Readable } = require('stream');
const { SLOTS, defaultSlot, publishAt, openingTime, isReleased, isIsoDate, indiaDate } = require('./lib/slots');
const { asBool, puzzleFromRow, playerView, answersOf, isComplete } = require('./lib/puzzle-views');
const { patternOf } = require('./lib/puzzle-text');
const { prepareUpload, cartoonKey, imageType } = require('./lib/upload');
const { uploadPage } = require('./lib/upload-page');
const { keyMatches, cartoonSource, wordlessSource, prepareDraft, draftPlace } = require('./lib/gpt-upload');
const { wordlessKey, isWordlessKey, cartoonKeysFor } = require('./lib/wordless');
const { announceOnPublish, dueAtTimer, announce } = require('./lib/notify');
const { cleanAbout, aboutProblem, aboutKey } = require('./lib/profile');

/**
 * Puzzle and completion data for Daily Jumble.
 *
 * The mobile SDK cannot reach the Data Store or Stratus without a Catalyst
 * session, and this app signs people in with its own Users table instead. So
 * every read and write goes through here: the caller proves who they are with
 * the token jumble_auth issued, and this function does the work with admin
 * scope. Publishing is refused to anyone who is not an admin, which is the
 * check that actually counts — hiding the tab in the app only tidies the UI.
 */

// Table and bucket names come from the function's environment where set, so
// moving to another Catalyst project is a settings change, not a code one.
const PUZZLES = process.env.PUZZLES_TABLE || 'Puzzles';
const COMPLETIONS = process.env.COMPLETIONS_TABLE || 'PuzzleCompletions';
const USERS = process.env.USERS_TABLE || 'Users';
const PUZZLE_SCORES = process.env.PUZZLE_SCORES_TABLE || 'PuzzleScores';
const USER_SCORES = process.env.USER_SCORES_TABLE || 'UserScores';
const LEADERBOARD_SIZE = 20;
const BUCKET = process.env.PUZZLES_BUCKET || 'blujem';

/**
 * The first day players' History reaches back to, yyyy-MM-dd (e.g. the launch
 * day). Unset, every puzzle shows. Earlier puzzles are kept, only not listed.
 */
const historyStart = () => (isIsoDate(process.env.HISTORY_START || '') ? process.env.HISTORY_START : '');

/**
 * Apps from before answers were hidden check words against the plain answer.
 * Until STRIP_ANSWERS_FOR_ALL is 'true', a caller that does not say it is the
 * newer app (client >= 2) still gets them, so nobody is broken mid-update.
 */
const stripForAll = () => process.env.STRIP_ANSWERS_FOR_ALL === 'true';
const MAX_SHEET_BYTES = 10 * 1024 * 1024;
const TOKEN_HEADER = 'x-jumble-token';
/** Tokens issued by the old DailyJumble project carry its user ids, so only BluJem's are accepted. */
const TOKEN_PROJECT = 'blujem';

// ------------------------------------------------------------------ helpers

function sendJson(res, statusCode, data) {
	res.writeHead(statusCode, { 'Content-Type': 'application/json' });
	res.end(JSON.stringify(data));
}

function readBody(req) {
	return new Promise((resolve, reject) => {
		if (req.body && typeof req.body === 'object') return resolve(req.body);
		if (req.body && typeof req.body === 'string') {
			try { return resolve(JSON.parse(req.body)); } catch (e) { return resolve({}); }
		}
		let data = '';
		req.on('data', (chunk) => { data += chunk; });
		req.on('end', () => {
			try { resolve(data ? JSON.parse(data) : {}); } catch (e) { resolve({}); }
		});
		req.on('error', reject);
	});
}

const b64url = (buf) => Buffer.from(buf).toString('base64')
	.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/** Returns the caller described by the token, or null if it does not hold up. */
function readToken(req) {
	const secret = process.env.JUMBLE_TOKEN_SECRET;
	if (!secret) return null;

	// Deliberately not the Authorization header: Catalyst reads that one itself
	// and rejects the call with INVALID_TOKEN before this function ever runs.
	const token = String(req.headers[TOKEN_HEADER] || '').trim();
	const [payload, signature] = token.split('.');
	if (!payload || !signature) return null;

	const expected = b64url(crypto.createHmac('sha256', secret).update(payload).digest());
	const a = Buffer.from(signature);
	const b = Buffer.from(expected);
	if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;

	try {
		const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
		if (!claims.exp || Date.now() > claims.exp) return null;
		if (claims.project !== TOKEN_PROJECT) return null;
		return claims;
	} catch (e) {
		return null;
	}
}

/** ZCQL takes single-quoted strings, so a quote in the input must be doubled. */
const quote = (value) => String(value).replace(/'/g, "''");

async function zcql(app, query) {
	const rows = await app.zcql().executeZCQLQuery(query);
	return rows;
}

// ------------------------------------------------------------------ puzzles

/**
 * The puzzles a caller may see. Players: published, released (their slot's
 * time has come), from HISTORY_START on, answers hashed. Admins: every
 * published one, upcoming too, answers and all — with `all`, unpublished
 * uploads as well.
 */
async function listPuzzles(app, caller, body, res) {
	const admin = caller.role === 'admin';
	const where = admin && body.all ? '' : `WHERE Published = 'true' `;
	const rows = await allRows(app, PUZZLES, `SELECT * FROM ${PUZZLES} ${where}ORDER BY PublishDate DESC`);
	const now = Date.now();
	const from = historyStart();
	const hashed = stripForAll() || Number(body.client || 0) >= 2;
	const puzzles = rows
		.filter((row) => admin || (isReleased(row, now) && isComplete(row) && (!from || String(row.PublishDate) >= from)))
		.map((row) => (admin || !hashed ? puzzleFromRow(row) : playerView(row)));
	return sendJson(res, 200, { puzzles, serverTime: now });
}

/**
 * A puzzle's answers, for a player who has started it (the server's clock
 * runs, so a hint or a reveal can be given) or finished it. Never before.
 */
async function puzzleAnswers(app, caller, body, res) {
	const puzzleId = String(body.puzzleId || '').trim();
	if (!puzzleId) return sendJson(res, 400, { error: 'puzzleId is required.' });
	const puzzle = await publishedPuzzle(app, puzzleId);
	if (!puzzle) return sendJson(res, 404, { error: 'That puzzle is not out yet.' });
	if (caller.role !== 'admin') {
		const [started, finished] = await Promise.all([
			scoreRow(app, caller.id, puzzleId),
			zcql(app, `SELECT ROWID FROM ${COMPLETIONS} WHERE UserId = '${quote(caller.id)}' AND PuzzleId = '${quote(puzzleId)}'`)
		]);
		if (!started && !finished.length) return sendJson(res, 403, { error: 'Start the puzzle first.' });
	}
	return sendJson(res, 200, answersOf(puzzle));
}

/**
 * Stores [bytes] as the wordless picture of the cartoon at [sheetKey] (see
 * lib/wordless.js). Returns a problem to show, or null once it is saved.
 */
async function saveWordless(app, sheetKey, bytes) {
	if (!bytes || !bytes.length) return null;
	const type = imageType(bytes);
	if (!type) return 'The wordless cartoon must be a PNG or JPEG picture.';
	if (bytes.length > MAX_SHEET_BYTES) return 'That wordless cartoon is too large (10 MB at most).';
	await app.stratus().bucket(BUCKET)
		.putObject(wordlessKey(sheetKey), Readable.from([bytes]), { overwrite: true, contentType: type });
	return null;
}

/**
 * The admin's upload: date, slot, the cartoon and the puzzle text, with the
 * answers when he has them. Checked with the parser, the cartoon put in
 * Stratus under puzzles/{date}/{slot}/, and the slot's one row written —
 * a second upload for the same date and slot replaces the first. Puzzles
 * for later dates are welcome: they stay hidden until their time.
 * `dryRun` only checks, and returns what was read.
 */
async function uploadPuzzle(app, caller, body, res) {
	if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can upload puzzles.' });
	const prepared = prepareUpload(body);
	if (prepared.problems.length) {
		return sendJson(res, 400, { problems: prepared.problems, error: prepared.problems.join('\n'), parsed: prepared.parsed || null, goesLive: '' });
	}
	const { values } = prepared;
	const existing = (await zcql(app,
		`SELECT * FROM ${PUZZLES} WHERE PublishDate = '${quote(values.PublishDate)}'`
	)).map((r) => r[PUZZLES]).filter(Boolean)
		.filter((r) => (r.Slot || defaultSlot(values.PublishDate)) === values.Slot);
	// The one already out comes first: it is what this upload replaces.
	existing.sort((a, b) => Number(asBool(b.Published)) - Number(asBool(a.Published)));
	const current = existing[0];
	const now = Date.now();
	values.PublishAt = openingTime(values.PublishDate, values.Slot, now, current);
	const goesLive = liveText(values.PublishAt, now);
	if (body.dryRun) {
		return sendJson(res, 200, { problems: [], parsed: prepared.parsed || null, goesLive });
	}

	let sheetKey = current?.SheetKey || '';
	const cartoon = String(body.cartoonBase64 || '');
	if (cartoon) {
		const bytes = Buffer.from(cartoon, 'base64');
		const type = imageType(bytes);
		if (!type) return sendJson(res, 400, { problems: ['The cartoon must be a PNG or JPEG picture.'] });
		if (bytes.length > MAX_SHEET_BYTES) return sendJson(res, 413, { problems: ['That cartoon is too large (10 MB at most).'] });
		sheetKey = cartoonKey(values.PublishDate, values.Slot);
		await app.stratus().bucket(BUCKET)
			.putObject(sheetKey, Readable.from([bytes]), { overwrite: true, contentType: type });
	}
	if (!sheetKey) return sendJson(res, 400, { problems: ['Choose the cartoon picture.'] });
	const wordlessProblem = await saveWordless(app, sheetKey, Buffer.from(String(body.wordlessBase64 || ''), 'base64'));
	if (wordlessProblem) return sendJson(res, 400, { problems: [wordlessProblem] });

	const row = { ...values, SheetKey: sheetKey };
	if (current && !body.explanation) row.FinalExplanation = current.FinalExplanation || '';
	if (current && !body.clue) row.FinalClue = current.FinalClue || row.FinalClue;
	const table = app.datastore().table(PUZZLES);
	const saved = current
		? await table.updateRow({ ROWID: current.ROWID, PuzzleId: current.PuzzleId, ...row })
		: await table.insertRow({ PuzzleId: crypto.randomUUID(), ...row });
	// Older duplicates of this slot (before uniqueness was kept) step aside.
	for (const extra of existing.slice(1)) {
		await table.updateRow({ ROWID: extra.ROWID, Published: 'false' });
	}
	const puzzle = { ...current, ...row, ...saved };
	const notified = announceOnPublish(puzzle, current, now)
		? await announce(puzzle)
		: { sent: false, skipped: 'not out yet, or already announced' };
	return sendJson(res, 200, {
		problems: [],
		warnings: prepared.warnings,
		published: values.Published === 'true',
		goesLive,
		notified,
		puzzle: puzzleFromRow(puzzle)
	});
}

/**
 * A puzzle from the BluJem Custom GPT: checked like the admin's upload and
 * stored as a draft (unpublished, not announced). It carries GPT_UPLOAD_KEY
 * (header x-blujem-key) instead of a sign-in; unset, nothing is accepted.
 */
async function gptUpload(req, res) {
	if (!keyMatches(req.headers['x-blujem-key'], process.env.GPT_UPLOAD_KEY)) {
		return sendJson(res, 401, { error: 'Not allowed.' });
	}
	const body = await readBody(req);
	const prepared = prepareDraft(body);
	if (prepared.problems.length) return sendJson(res, 400, { problems: prepared.problems });
	const source = cartoonSource(body);
	if (source.problem) return sendJson(res, 400, { problems: [source.problem] });

	const app = catalyst.initialize(req, { scope: 'admin' });
	const { values } = prepared;
	const rows = (await zcql(app, `SELECT * FROM ${PUZZLES} WHERE PublishDate = '${quote(values.PublishDate)}'`))
		.map((r) => r[PUZZLES]).filter(Boolean);
	const place = draftPlace(rows, values.PublishDate, values.Slot);
	if (place.conflict) return sendJson(res, 409, { problems: [place.conflict] });

	let bytes;
	if (source.url) {
		const download = await fetch(source.url);
		if (!download.ok) return sendJson(res, 400, { problems: ['The cartoon could not be downloaded from ChatGPT.'] });
		bytes = Buffer.from(await download.arrayBuffer());
	} else {
		bytes = Buffer.from(source.base64, 'base64');
	}
	const type = imageType(bytes);
	if (!type) return sendJson(res, 400, { problems: ['The cartoon must be a PNG or JPEG picture.'] });
	if (bytes.length > MAX_SHEET_BYTES) return sendJson(res, 413, { problems: ['That cartoon is too large (10 MB at most).'] });

	// Its own key, so a draft never touches the picture of a published puzzle.
	const sheetKey = `drafts/${values.PublishDate}/${values.Slot}/cartoon.${type === 'image/png' ? 'png' : 'jpg'}`;
	await app.stratus().bucket(BUCKET).putObject(sheetKey, Readable.from([bytes]), { overwrite: true, contentType: type });

	// A second picture, when sent, is the wordless cartoon for the share card.
	const wordless = wordlessSource(body);
	if (wordless.problem) return sendJson(res, 400, { problems: [wordless.problem] });
	if (wordless.url || wordless.base64) {
		let extra;
		if (wordless.url) {
			const got = await fetch(wordless.url);
			if (!got.ok) return sendJson(res, 400, { problems: ['The wordless cartoon could not be downloaded from ChatGPT.'] });
			extra = Buffer.from(await got.arrayBuffer());
		} else {
			extra = Buffer.from(wordless.base64, 'base64');
		}
		const problem = await saveWordless(app, sheetKey, extra);
		if (problem) return sendJson(res, 400, { problems: [problem] });
	}

	const row = { ...values, SheetKey: sheetKey };
	const table = app.datastore().table(PUZZLES);
	const saved = place.replace
		? await table.updateRow({ ROWID: place.replace.ROWID, PuzzleId: place.replace.PuzzleId, ...row })
		: await table.insertRow({ PuzzleId: crypto.randomUUID(), ...row });
	return sendJson(res, 200, {
		draft: true,
		message: `Saved as a draft for ${values.PublishDate} (${SLOTS[values.Slot].label}). An admin checks and publishes it on the upload page.`,
		puzzleId: saved.PuzzleId || place.replace?.PuzzleId || ''
	});
}

/**
 * The admin publishes a draft as it is. Refused if its slot has a published
 * puzzle by now; otherwise it opens at its slot's time (or now, if that has
 * passed) and players are told when it opens.
 */
async function publishDraft(app, caller, body, res) {
	if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can publish puzzles.' });
	const puzzleId = String(body.id || '').trim();
	const draft = (await zcql(app, `SELECT * FROM ${PUZZLES} WHERE PuzzleId = '${quote(puzzleId)}'`))
		.map((r) => r[PUZZLES]).filter(Boolean)[0];
	if (!draft) return sendJson(res, 404, { error: 'That draft is gone.' });
	if (asBool(draft.Published)) return sendJson(res, 200, { puzzle: puzzleFromRow(draft), notified: { sent: false } });
	if (!isComplete(draft)) return sendJson(res, 400, { error: 'That draft has no answers yet.' });
	const date = String(draft.PublishDate);
	const slot = draft.Slot || defaultSlot(date);
	const rows = (await zcql(app, `SELECT * FROM ${PUZZLES} WHERE PublishDate = '${quote(date)}'`))
		.map((r) => r[PUZZLES]).filter(Boolean).filter((r) => r.PuzzleId !== puzzleId);
	const place = draftPlace(rows, date, slot);
	if (place.conflict) return sendJson(res, 409, { error: place.conflict });

	const now = Date.now();
	const values = { Published: 'true', PublishAt: openingTime(date, slot, now, null) };
	await app.datastore().table(PUZZLES).updateRow({ ROWID: draft.ROWID, ...values });
	const puzzle = { ...draft, ...values };
	const notified = announceOnPublish(puzzle, null, now)
		? await announce(puzzle)
		: { sent: false, skipped: 'not out yet: announced when it opens' };
	return sendJson(res, 200, { puzzle: puzzleFromRow(puzzle), goesLive: liveText(values.PublishAt, now), notified });
}

/** "Sat 7 Nov, 4:00 pm" in India, or "now" when it is already out. */
function liveText(ms, now = Date.now()) {
	if (ms <= now) return 'now';
	return new Date(ms).toLocaleString('en-IN', {
		timeZone: 'Asia/Kolkata', weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit'
	});
}

/**
 * Gives every puzzle row from before slots its slot, release time and answer
 * pattern. Safe to run again: rows that have them are left alone, and nothing
 * is ever deleted. Two rows on one date and slot are reported, not changed.
 */
async function migrateSlots(app, caller, res) {
	if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can run migrations.' });
	const rows = await allRows(app, PUZZLES, `SELECT * FROM ${PUZZLES}`);
	const table = app.datastore().table(PUZZLES);
	let updated = 0;
	const seen = new Map();
	const clashes = [];
	for (const row of rows) {
		const date = String(row.PublishDate || '');
		if (!isIsoDate(date)) continue;
		const slot = SLOTS[row.Slot] ? row.Slot : defaultSlot(date);
		if (asBool(row.Published)) {
			const key = `${date}/${slot}`;
			if (seen.has(key)) clashes.push(key);
			seen.set(key, row.PuzzleId);
		}
		const change = {};
		if (row.Slot !== slot) change.Slot = slot;
		if (!Number(row.PublishAt)) change.PublishAt = publishAt(date, slot);
		if (!row.FinalPattern && row.FinalAnswer) change.FinalPattern = patternOf(row.FinalAnswer);
		if (Object.keys(change).length) {
			await table.updateRow({ ROWID: row.ROWID, ...change });
			updated++;
		}
	}
	return sendJson(res, 200, { rows: rows.length, updated, clashes });
}

async function publishPuzzle(app, caller, body, res) {
	if (caller.role !== 'admin') {
		return sendJson(res, 403, { error: 'Only an admin can publish sheets.' });
	}
	const puzzleId = String(body.id || '').trim();
	if (!puzzleId || !body.publishDate) {
		return sendJson(res, 400, { error: 'id and publishDate are required.' });
	}

	let sheetKey = String(body.sheetKey || '').trim();

	// The sheet image travels as base64 so one call publishes everything.
	if (body.sheetBase64) {
		const bytes = Buffer.from(String(body.sheetBase64), 'base64');
		if (bytes.length === 0) {
			return sendJson(res, 400, { error: 'The sheet image could not be read.' });
		}
		if (bytes.length > MAX_SHEET_BYTES) {
			return sendJson(res, 413, { error: 'That sheet image is too large.' });
		}
		sheetKey = sheetKey || `sheets/${puzzleId}.png`;
		// overwrite: a sheet keeps its key, and Stratus refuses a second write to
		// the same one otherwise — which broke every re-publish with a 409.
		await app.stratus()
			.bucket(BUCKET)
			.putObject(sheetKey, Readable.from(bytes), { overwrite: true });
	}
	if (body.wordlessBase64) {
		const problem = await saveWordless(app, sheetKey, Buffer.from(String(body.wordlessBase64), 'base64'));
		if (problem) return sendJson(res, 400, { error: problem });
	}

	const publishDate = String(body.publishDate);
	const slot = SLOTS[body.slot] ? String(body.slot) : (isIsoDate(publishDate) ? defaultSlot(publishDate) : 'morning');
	const values = {
		PuzzleId: puzzleId,
		PublishDate: publishDate,
		Slot: slot,
		PublishAt: 0,
		SheetDate: String(body.sheetDate || ''),
		Difficulty: String(body.difficulty || 'Easy'),
		TimeLimitSeconds: Number(body.timeLimitSeconds || 300),
		SheetKey: sheetKey,
		AspectRatio: Number(body.aspectRatio || 1),
		Published: body.published === false ? 'false' : 'true',
		FinalAnswer: String(body.finalAnswer || ''),
		FinalClue: String(body.finalClue || ''),
		FinalExplanation: String(body.finalExplanation || ''),
		FinalBoxes: String(body.finalBoxes || '[]'),
		FinalGroupSizes: String(body.finalGroupSizes || '[]'),
		Words: String(body.words || '[]'),
		// The answer boxes as typed, line breaks and all; else read off the answer.
		FinalPattern: String(body.finalPattern || '') || patternOf(body.finalAnswer)
	};

	const table = app.datastore().table(PUZZLES);
	const existing = (await zcql(app,
		`SELECT * FROM ${PUZZLES} WHERE PuzzleId = '${quote(puzzleId)}'`
	)).map((r) => r[PUZZLES]).filter(Boolean)[0];
	const rowId = existing?.ROWID;

	// One puzzle per date and slot: publishing another takes the old one down.
	let rivals = [];
	if (values.Published === 'true') {
		rivals = (await zcql(app,
			`SELECT * FROM ${PUZZLES} WHERE PublishDate = '${quote(publishDate)}' AND Published = 'true'`
		)).map((r) => r[PUZZLES]).filter(Boolean)
			.filter((r) => r.PuzzleId !== puzzleId && (r.Slot || defaultSlot(publishDate)) === slot);
		for (const rival of rivals) await app.datastore().table(PUZZLES).updateRow({ ROWID: rival.ROWID, Published: 'false' });
	}
	// What players already had in this slot: this sheet as it was, or the one it replaces.
	const now = Date.now();
	const previous = existing && asBool(existing.Published) ? existing : rivals[0] || existing;
	if (isIsoDate(publishDate)) values.PublishAt = openingTime(publishDate, slot, now, previous);

	// Republishing the same sheet updates it rather than adding a duplicate.
	const saved = rowId
		? await table.updateRow({ ROWID: rowId, ...values })
		: await table.insertRow(values);

	const notified = announceOnPublish(values, previous, now)
		? await announce(values)
		: { sent: false, skipped: 'not out yet, or already announced' };

	return sendJson(res, 200, {
		puzzle: puzzleFromRow({ ...values, ...saved }),
		notified
	});
}

/**
 * The timer's call, at 6:00, 10:00 and 16:00 India time: announces today's
 * puzzles whose fixed opening has just come. It carries CRON_KEY instead of
 * a player's sign-in (header x-cron-key, or ?key=); unset, nothing runs.
 */
async function timerNotify(req, res) {
	const key = process.env.CRON_KEY || '';
	// A header where the console allows one; else ?key= on the URL.
	const url = new URL(req.url, 'https://localhost');
	const given = String(req.headers['x-cron-key'] || url.searchParams.get('key') || '');
	if (!key || given.length !== key.length || !crypto.timingSafeEqual(Buffer.from(given), Buffer.from(key))) {
		return sendJson(res, 401, { error: 'Not allowed.' });
	}
	const app = catalyst.initialize(req, { scope: 'admin' });
	const now = Date.now();
	const rows = (await zcql(app,
		`SELECT * FROM ${PUZZLES} WHERE PublishDate = '${indiaDate(now)}' AND Published = 'true'`
	)).map((r) => r[PUZZLES]).filter(Boolean);
	const announced = [];
	for (const row of dueAtTimer(rows, now)) {
		announced.push({ slot: row.Slot, ...(await announce(row)) });
	}
	return sendJson(res, 200, { announced });
}

// Pictures already found to be out. A puzzle that is out stays out, so this
// instance need not read the Puzzles table again for them (one Data Store read
// saved per picture download); a picture not out yet is always checked.
const releasedSheets = new Set();

async function streamSheet(app, caller, body, res) {
	const key = String(body.key || '').trim();
	if (!key) return sendJson(res, 400, { error: 'key is required.' });

	// A player only gets the picture of a puzzle that is out.
	if (caller.role !== 'admin' && !releasedSheets.has(key)) {
		// A wordless picture goes with its cartoon: out when that puzzle is.
		const keys = isWordlessKey(key) ? cartoonKeysFor(key) : [key];
		const where = keys.map((k) => `SheetKey = '${quote(k)}'`).join(' OR ');
		const rows = (await zcql(app, `SELECT * FROM ${PUZZLES} WHERE ${where}`))
			.map((r) => r[PUZZLES]).filter(Boolean);
		if (!rows.some((r) => asBool(r.Published) && isReleased(r))) {
			return sendJson(res, 404, { error: 'That puzzle is not out yet.' });
		}
		releasedSheets.add(key);
	}

	const bucket = app.stratus().bucket(BUCKET);
	const head = await bucket.headObject(key, { throwErr: false });
	if (!head) return sendJson(res, 404, { error: 'That sheet is not in storage.' });

	const stream = await bucket.getObject(key);
	res.writeHead(200, { 'Content-Type': key.endsWith('.jpg') ? 'image/jpeg' : 'image/png' });
	stream.pipe(res);
}

// -------------------------------------------------------------- completions

function completionFromRow(row) {
	return {
		puzzleId: row.PuzzleId,
		sheetDate: row.SheetDate || '',
		finalAnswer: row.FinalAnswer || '',
		seconds: Number(row.Seconds || 0),
		hintsUsed: Number(row.HintsUsed || 0),
		completedAt: Number(row.CompletedAt || 0)
	};
}

async function listCompletions(app, caller, res) {
	const rows = await zcql(app,
		`SELECT * FROM ${COMPLETIONS} WHERE UserId = '${quote(caller.id)}' ` +
		`ORDER BY CompletedAt DESC LIMIT 0, 300`
	);
	const completions = rows.map((r) => r[COMPLETIONS]).filter(Boolean).map(completionFromRow);
	return sendJson(res, 200, { completions });
}

/**
 * The fastest finishers of one day's sheet.
 *
 * Ordered on hints first and time second, the same way a player's own best run
 * is chosen: a two-minute solve that leaned on three hints has not beaten a
 * three-minute solve that used none, and ranking on the clock alone would say
 * it had.
 *
 * Only a display name and a time go out — never an email, never a user id. The
 * caller's own row is flagged so the app can point it out, which is the one
 * piece of identity anybody needs here.
 */
async function leaderboard(app, caller, body, res) {
	const sheetDate = String(body.sheetDate || '').trim();
	if (!sheetDate) return sendJson(res, 400, { error: 'sheetDate is required.' });

	const rows = await zcql(app,
		`SELECT UserId, Seconds, HintsUsed, CompletedAt FROM ${COMPLETIONS} ` +
		`WHERE SheetDate = '${quote(sheetDate)}' ` +
		`ORDER BY HintsUsed ASC, Seconds ASC LIMIT 0, ${LEADERBOARD_SIZE}`
	);
	const runs = rows.map((r) => r[COMPLETIONS]).filter(Boolean);
	if (runs.length === 0) return sendJson(res, 200, { sheetDate, entries: [] });

	// One lookup for every name on the board, rather than one per row.
	const names = await handles(app, runs.map((r) => r.UserId));

	const entries = runs.map((run, index) => ({
		rank: index + 1,
		name: names.get(String(run.UserId)) || 'Player',
		seconds: Number(run.Seconds || 0),
		hintsUsed: Number(run.HintsUsed || 0),
		you: String(run.UserId) === String(caller.id)
	}));
	return sendJson(res, 200, { sheetDate, entries });
}

async function recordCompletion(app, caller, body, res) {
	const puzzleId = String(body.puzzleId || '').trim();
	if (!puzzleId) return sendJson(res, 400, { error: 'puzzleId is required.' });

	const run = {
		// The user is taken from the token, never from the body, so nobody can
		// file a result against someone else's account.
		UserId: caller.id,
		PuzzleId: puzzleId,
		SheetDate: String(body.sheetDate || ''),
		FinalAnswer: String(body.finalAnswer || ''),
		Seconds: Number(body.seconds || 0),
		HintsUsed: Number(body.hintsUsed || 0),
		CompletedAt: Number(body.completedAt || Date.now())
	};

	const existing = await zcql(app,
		`SELECT * FROM ${COMPLETIONS} WHERE UserId = '${quote(caller.id)}' ` +
		`AND PuzzleId = '${quote(puzzleId)}'`
	);
	const previous = existing.map((r) => r[COMPLETIONS]).filter(Boolean)[0];
	const table = app.datastore().table(COMPLETIONS);

	if (!previous) {
		await table.insertRow(run);
		return sendJson(res, 201, { completion: completionFromRow(run), kept: true });
	}

	// Keep the better run: fewest hints first, then the faster time.
	const better = run.HintsUsed < Number(previous.HintsUsed || 0) ||
		(run.HintsUsed === Number(previous.HintsUsed || 0) &&
			run.Seconds < Number(previous.Seconds || 0));

	if (!better) {
		return sendJson(res, 200, { completion: completionFromRow(previous), kept: false });
	}
	await table.updateRow({ ROWID: previous.ROWID, ...run });
	return sendJson(res, 200, { completion: completionFromRow(run), kept: true });
}

// ------------------------------------------------------------------ points
//
// Every point is worked out here, never on the phone. The app says what the
// player did — which squares hold which letters, which words were revealed,
// how many hints were shown — and this checks the letters against the answers
// stored with the published sheet, takes the higher of the hint count the app
// reports and the one the hint service saw, and times the run with its own
// clock, started when the player tapped Start. A sheet is scored once per
// player; asking again returns the same score.
//
// Speed multiplies rather than adds: what the words and the answer earned is
// worth five times as much inside a minute, falling a step at 1:30, 2:00 and
// 3:00, and plain from there. The server's clock never stops — leaving the app
// does not hold it — so the phone's strip counts the same way.

/** Points for a word solved after this many hints: none, one, two, three. */
const WORD_POINTS = [20, 15, 10, 5];
const FINAL_POINTS = 30;

/** Seconds, and the multiplier for finishing within them. Slower is 1x. */
const MULTIPLIERS = [[60, 5], [90, 4], [120, 3], [180, 2]];

/** Faster than this is not a person solving a Jumble, and earns no multiplier. */
const MIN_PLAUSIBLE_SECONDS = 15;

/** The multiplier a run of this many seconds earns. */
function multiplierFor(seconds) {
	if (seconds == null || seconds < MIN_PLAUSIBLE_SECONDS) return 1;
	const tier = MULTIPLIERS.find(([limit]) => seconds <= limit);
	return tier ? tier[1] : 1;
}

const lettersOf = (text) => String(text || '').toUpperCase().replace(/[^A-Z]/g, '');

/**
 * The score for one run, from the puzzle as stored and what the player did.
 * Pure, so the rules can be tested without a database.
 */
function scoreRun({ answers, finalAnswer, played, serverHints, seconds, late = false }) {
	const words = answers.map((answer, i) => {
		const word = (played.words || [])[i] || {};
		const solved = lettersOf(word.letters) === lettersOf(answer) && lettersOf(answer) !== '';
		const hints = Math.min(3, Math.max(0,
			Number(word.hintsUsed) || 0,
			Number(serverHints[String(i + 1)]) || 0
		));
		const points = solved && !word.revealed ? WORD_POINTS[hints] : 0;
		return { solved, revealed: Boolean(word.revealed), hints, points };
	});
	const wordPoints = words.reduce((sum, w) => sum + w.points, 0);

	const finalSolved = lettersOf(played.finalLetters) === lettersOf(finalAnswer) &&
		lettersOf(finalAnswer) !== '';
	const finalAnswerPoints = finalSolved && !played.finalRevealed ? FINAL_POINTS : 0;

	// Only what was earned is multiplied, so a revealed word stays at nothing
	// however fast the rest went.
	const basePoints = wordPoints + finalAnswerPoints;
	const multiplier = multiplierFor(seconds);
	const fullPoints = basePoints * multiplier;
	// Full points belong to the day a puzzle comes out; solved on a later
	// day it earns half, rounded down.
	const totalPoints = late ? Math.floor(fullPoints / 2) : fullPoints;
	return {
		words, wordPoints, finalAnswerPoints, basePoints, multiplier,
		// The extra the multiplier added, kept in the existing TimeBonus column.
		timeBonus: fullPoints - basePoints,
		latePenalty: fullPoints - totalPoints,
		totalPoints
	};
}

async function scoreRow(app, userId, puzzleId) {
	const rows = await zcql(app,
		`SELECT * FROM ${PUZZLE_SCORES} WHERE UserId = '${quote(userId)}' ` +
		`AND PuzzleId = '${quote(puzzleId)}'`
	);
	return rows.map((r) => r[PUZZLE_SCORES]).filter(Boolean)[0] || null;
}

async function publishedPuzzle(app, puzzleId) {
	const rows = await zcql(app,
		`SELECT * FROM ${PUZZLES} WHERE PuzzleId = '${quote(puzzleId)}'`
	);
	const row = rows.map((r) => r[PUZZLES]).filter(Boolean)[0];
	return row && asBool(row.Published) && isReleased(row) ? row : null;
}

/**
 * The player tapped Start: the server's clock for this run starts now. Once
 * only — starting again later cannot win back time already spent — except
 * that `restart` after the time limit has run out, on a run not yet scored,
 * starts the clock (and the hints the server saw) over.
 */
async function startScore(app, caller, body, res) {
	const puzzleId = String(body.puzzleId || '').trim();
	if (!puzzleId) return sendJson(res, 400, { error: 'puzzleId is required.' });
	const puzzle = await publishedPuzzle(app, puzzleId);
	if (!puzzle) {
		return sendJson(res, 200, { scored: false, reason: 'not a published sheet' });
	}
	// How long the server's clock has been running, so the phone's strip shows
	// the multiplier that will actually be given — a sheet restarted after a
	// reset keeps the clock it started with.
	const existing = await scoreRow(app, caller.id, puzzleId);
	if (existing) {
		const startedAt = Number(existing.StartedAt || 0);
		const limitMillis = Number(puzzle.TimeLimitSeconds || 300) * 1000;
		const timeIsUp = startedAt && Date.now() - startedAt >= limitMillis;
		if (body.restart && !isScored(existing) && timeIsUp) {
			await app.datastore().table(PUZZLE_SCORES).updateRow({
				ROWID: existing.ROWID,
				StartedAt: Date.now(),
				HintLevels: '{}'
			});
			return sendJson(res, 200, { started: true, status: 'started', elapsedSeconds: 0 });
		}
		return sendJson(res, 200, {
			started: true,
			status: isScored(existing) ? 'completed' : existing.Status,
			elapsedSeconds: startedAt ? Math.max(0, Math.round((Date.now() - startedAt) / 1000)) : 0
		});
	}
	await app.datastore().table(PUZZLE_SCORES).insertRow({
		UserId: caller.id,
		UserName: String(caller.username || '').trim(),
		PuzzleId: puzzleId,
		Status: 'started',
		StartedAt: Date.now(),
		HintLevels: '{}'
	});
	return sendJson(res, 201, { started: true, status: 'started', elapsedSeconds: 0 });
}

/** A run that is over for scoring: solved, or given up by showing the answers. */
const isScored = (row) => row.Status === 'completed' || row.Status === 'revealed';

/** The player's standing across all time: rank, points, puzzles. */
async function allTimeStanding(app, userId) {
	const board = await userBoard(app);
	const index = board.findIndex((e) => e.userId === String(userId));
	return index === -1 ? null : { ...board[index], rank: index + 1 };
}

/** Scores a finished run — once. */
async function submitScore(app, caller, body, res) {
	const puzzleId = String(body.puzzleId || '').trim();
	if (!puzzleId) return sendJson(res, 400, { error: 'puzzleId is required.' });
	const puzzle = await publishedPuzzle(app, puzzleId);
	if (!puzzle) return sendJson(res, 200, { scored: false, reason: 'not a published sheet' });

	const table = app.datastore().table(PUZZLE_SCORES);
	const row = await scoreRow(app, caller.id, puzzleId);

	if (row && isScored(row)) {
		const standing = await allTimeStanding(app, caller.id);
		const wordPoints = Number(row.WordPoints || 0);
		const finalAnswerPoints = Number(row.FinalAnswerPoints || 0);
		const totalPoints = Number(row.TotalPoints || 0);
		const basePoints = wordPoints + finalAnswerPoints;
		const timeBonus = Number(row.TimeBonus || 0);
		return sendJson(res, 200, {
			scored: true,
			alreadyScored: true,
			latePenalty: Math.max(0, basePoints + timeBonus - totalPoints),
			wordPoints,
			finalAnswerPoints,
			basePoints,
			// Not stored on its own; runs scored before multipliers come out as
			// 1x with their old bonus still in the total.
			multiplier: basePoints > 0 && totalPoints % basePoints === 0
				? Math.max(1, totalPoints / basePoints) : 1,
			timeBonus: Number(row.TimeBonus || 0),
			totalPoints,
			rank: standing ? standing.rank : null
		});
	}

	let words = [];
	try { words = JSON.parse(puzzle.Words || '[]'); } catch (e) { words = []; }
	let serverHints = {};
	try { serverHints = JSON.parse((row && row.HintLevels) || '{}'); } catch (e) { serverHints = {}; }

	const now = Date.now();
	const startedAt = row ? Number(row.StartedAt || 0) : 0;
	const seconds = startedAt ? Math.round((now - startedAt) / 1000) : null;

	const score = scoreRun({
		answers: words.map((w) => w.answer || ''),
		finalAnswer: puzzle.FinalAnswer || '',
		played: body,
		serverHints,
		seconds,
		late: indiaDate(now) > String(puzzle.PublishDate || '')
	});

	// Asking for the answers is not solving: the run is closed at nothing
	// ('revealed'), and the player's totals and puzzle counts stay as they were.
	const gaveUp = Boolean(body.finalRevealed) && score.totalPoints === 0;

	const values = {
		UserId: caller.id,
		UserName: String(caller.username || '').trim(),
		PuzzleId: puzzleId,
		Status: gaveUp ? 'revealed' : 'completed',
		WordPoints: score.wordPoints,
		FinalAnswerPoints: score.finalAnswerPoints,
		TimeBonus: score.timeBonus,
		TotalPoints: score.totalPoints,
		CompletionTime: seconds == null ? 0 : seconds,
		CompletedAt: now
	};
	if (row) await table.updateRow({ ROWID: row.ROWID, ...values });
	else await table.insertRow({ ...values, StartedAt: 0, HintLevels: '{}' });

	// The running total, kept in one row per player so the all-time board is
	// one small read.
	const totals = gaveUp ? [] : await zcql(app,
		`SELECT * FROM ${USER_SCORES} WHERE UserId = '${quote(caller.id)}'`
	);
	const total = totals.map((r) => r[USER_SCORES]).filter(Boolean)[0];
	const users = app.datastore().table(USER_SCORES);
	const time = seconds == null ? 0 : seconds;
	if (gaveUp) {
		// Nothing to add.
	} else if (total) {
		await users.updateRow({
			ROWID: total.ROWID,
			UserName: values.UserName,
			TotalPoints: Number(total.TotalPoints || 0) + score.totalPoints,
			PuzzlesCompleted: Number(total.PuzzlesCompleted || 0) + 1,
			TotalTime: Number(total.TotalTime || 0) + time,
			UpdatedAt: now
		});
	} else {
		await users.insertRow({
			UserId: caller.id,
			UserName: values.UserName,
			TotalPoints: score.totalPoints,
			PuzzlesCompleted: 1,
			TotalTime: time,
			UpdatedAt: now
		});
	}

	const standing = await allTimeStanding(app, caller.id);
	return sendJson(res, 200, {
		scored: true,
		alreadyScored: false,
		wordPoints: score.wordPoints,
		finalAnswerPoints: score.finalAnswerPoints,
		basePoints: score.basePoints,
		multiplier: score.multiplier,
		timeBonus: score.timeBonus,
		latePenalty: score.latePenalty,
		totalPoints: score.totalPoints,
		seconds,
		rank: standing ? standing.rank : null
	});
}

// ------------------------------------------------------------------ profiles

async function readAbout(app, userId) {
	const bucket = app.stratus().bucket(BUCKET);
	const head = await bucket.headObject(aboutKey(userId), { throwErr: false });
	if (!head) return '';
	const chunks = [];
	for await (const chunk of await bucket.getObject(aboutKey(userId))) chunks.push(Buffer.from(chunk));
	try {
		return cleanAbout(JSON.parse(Buffer.concat(chunks).toString('utf8')).about);
	} catch (error) {
		return '';
	}
}

/**
 * A player's name and About me: the caller's own, or — by the key the
 * leaderboard shows — anyone's on the board. Only signed-in players get here.
 */
async function getProfile(app, caller, body, res) {
	let userId = String(caller.id);
	if (body.key) {
		const hit = (await userBoard(app)).find((e) => boardKey(e.userId) === String(body.key));
		if (!hit) return sendJson(res, 404, { error: 'That player is not on the board.' });
		userId = String(hit.userId);
	}
	const names = await handles(app, [userId]);
	return sendJson(res, 200, {
		name: names.get(userId) || 'Player',
		about: await readAbout(app, userId),
		you: userId === String(caller.id)
	});
}

/** Saves the caller's own About me; empty clears it. */
async function saveAbout(app, caller, body, res) {
	const about = cleanAbout(body.about);
	const problem = aboutProblem(about);
	if (problem) return sendJson(res, 400, { error: problem });
	const json = Buffer.from(JSON.stringify({ about, updatedAt: Date.now() }));
	await app.stratus().bucket(BUCKET)
		.putObject(aboutKey(caller.id), Readable.from([json]), { overwrite: true, contentType: 'application/json' });
	return sendJson(res, 200, { about });
}

/** Every row of a query, however many pages it runs to. */
async function allRows(app, table, query) {
	const out = [];
	for (let start = 0; ; start += 300) {
		const rows = await zcql(app, `${query} LIMIT ${start}, 300`);
		const page = rows.map((r) => r[table]).filter(Boolean);
		out.push(...page);
		if (page.length < 300) return out;
	}
}

/**
 * The public handle for each of these players, read from Users at the time
 * the board is drawn. Nothing else about them leaves this function: a player
 * renamed a moment ago shows under the new name, and a real name is never on
 * the board — whatever older rows may still hold.
 */
async function handles(app, userIds) {
	const ids = [...new Set(userIds.map(String))].filter(Boolean);
	const names = new Map();
	for (let i = 0; i < ids.length; i += 100) {
		const chunk = ids.slice(i, i + 100);
		const rows = await zcql(app,
			`SELECT ROWID, Username FROM ${USERS} ` +
			`WHERE ROWID IN (${chunk.map((id) => `'${quote(id)}'`).join(', ')})`
		);
		for (const u of rows.map((r) => r[USERS]).filter(Boolean)) {
			const name = String(u.Username || '').trim();
			if (name) names.set(String(u.ROWID), name);
		}
	}
	return names;
}

/** A player's id on the leaderboard: stable, but not their account id. */
const boardKey = (userId) => crypto.createHash('sha256').update(`board:${userId}`).digest('hex').slice(0, 12);

/** Highest points first; equal points, the less total time first. */
const byStanding = (a, b) => b.points - a.points || a.seconds - b.seconds || a.name.localeCompare(b.name);

/** The all-time board, from the per-player totals. */
async function userBoard(app) {
	const rows = await allRows(app, USER_SCORES, `SELECT * FROM ${USER_SCORES}`);
	const names = await handles(app, rows.map((r) => r.UserId));
	return rows.map((r) => ({
		userId: String(r.UserId),
		name: names.get(String(r.UserId)) || 'Player',
		points: Number(r.TotalPoints || 0),
		puzzles: Number(r.PuzzlesCompleted || 0),
		seconds: Number(r.TotalTime || 0)
	})).sort(byStanding);
}

/** A board for a stretch of time, added up from the runs in it. */
async function periodBoard(app, since) {
	const rows = await allRows(app, PUZZLE_SCORES,
		`SELECT * FROM ${PUZZLE_SCORES} WHERE Status = 'completed' AND CompletedAt >= ${since}`
	);
	const byUser = new Map();
	for (const r of rows) {
		const id = String(r.UserId);
		const entry = byUser.get(id) ||
			{ userId: id, name: 'Player', points: 0, puzzles: 0, seconds: 0 };
		entry.points += Number(r.TotalPoints || 0);
		entry.puzzles += 1;
		entry.seconds += Number(r.CompletionTime || 0);
		byUser.set(id, entry);
	}
	const names = await handles(app, [...byUser.keys()]);
	for (const entry of byUser.values()) entry.name = names.get(entry.userId) || 'Player';
	return [...byUser.values()].sort(byStanding);
}

/** Midnight in India today, and on the Monday of this week, in milliseconds. */
function periodStart(period) {
	const IST = 5.5 * 3600 * 1000;
	const local = new Date(Date.now() + IST);
	const midnight = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - IST;
	if (period === 'today') return midnight;
	const sinceMonday = (local.getUTCDay() + 6) % 7;
	return midnight - sinceMonday * 24 * 3600 * 1000;
}

/**
 * The points board for today, this week or all time. Only names, points and
 * counts go out — never an email or a user id — and the caller's own row is
 * flagged, with their standing sent even when it falls outside the top.
 */
async function scoreBoard(app, caller, body, res) {
	const period = ['today', 'week', 'all'].includes(body.period) ? body.period : 'all';
	const board = period === 'all' ? await userBoard(app) : await periodBoard(app, periodStart(period));
	const entries = board.slice(0, 50).map((e, i) => ({
		rank: i + 1,
		// A stable handle for the row, so the app can animate a player moving
		// up or down — a hash, so it says nothing about who they are.
		key: boardKey(e.userId),
		name: e.name,
		points: e.points,
		puzzles: e.puzzles,
		you: e.userId === String(caller.id)
	}));
	const mine = board.findIndex((e) => e.userId === String(caller.id));
	const me = mine === -1 ? null : {
		rank: mine + 1, points: board[mine].points, puzzles: board[mine].puzzles
	};
	return sendJson(res, 200, { period, entries, me });
}

/**
 * The admin's player list: every account with when it joined, how many
 * puzzles it has finished and its points, most points first. Admins only —
 * players see the public board above, never this one.
 */
async function adminPlayers(app, caller, res) {
	if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can see the player list.' });
	const users = await allRows(app, USERS, `SELECT ROWID, Username, Name, CREATEDTIME FROM ${USERS}`);
	const totals = await allRows(app, USER_SCORES, `SELECT UserId, TotalPoints, PuzzlesCompleted FROM ${USER_SCORES}`);
	return sendJson(res, 200, { players: playerRows(users, totals) });
}

/** Users joined with their score totals; a player with no score yet shows 0. */
function playerRows(users, totals) {
	const byUser = new Map(totals.map((t) => [String(t.UserId), t]));
	return users.map((u) => {
		const t = byUser.get(String(u.ROWID)) || {};
		return {
			name: String(u.Username || '').trim() || String(u.Name || '').trim() || 'Player',
			since: String(u.CREATEDTIME || '').slice(0, 10),
			games: Number(t.PuzzlesCompleted || 0),
			points: Number(t.TotalPoints || 0)
		};
	}).sort((a, b) => b.points - a.points || b.games - a.games || a.since.localeCompare(b.since));
}

// ------------------------------------------------------------------ handler

module.exports = async (req, res) => {
	try {
		if (req.method === 'OPTIONS') {
			res.writeHead(204);
			return res.end();
		}
		const path = new URL(req.url, `https://${req.headers.host || 'localhost'}`).pathname;
		if (req.method === 'GET' && /\/(admin|upload)\/?$/.test(path)) {
			res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
			return res.end(uploadPage());
		}
		// The timer may call with GET or POST, whichever the console sends.
		if (/\/cron\/notify\/?$/.test(path)) return await timerNotify(req, res);
		// The BluJem Custom GPT: its own key, drafts only.
		if (req.method === 'POST' && /\/gpt\/puzzle\/?$/.test(path)) return await gptUpload(req, res);
		if (req.method !== 'POST') {
			return sendJson(res, 405, { error: 'Use POST.' });
		}

		const caller = readToken(req);
		if (!caller) {
			return sendJson(res, 401, { error: 'Sign in again.' });
		}

		const route = path.replace(/\/+$/, '').split('/').slice(-2).join('/');
		const body = await readBody(req);
		const app = catalyst.initialize(req, { scope: 'admin' });

		switch (route) {
			case 'puzzles/list': return await listPuzzles(app, caller, body, res);
			case 'puzzles/publish': return await publishPuzzle(app, caller, body, res);
			case 'puzzles/upload': return await uploadPuzzle(app, caller, body, res);
			case 'puzzles/publish-draft': return await publishDraft(app, caller, body, res);
			case 'puzzles/answers': return await puzzleAnswers(app, caller, body, res);
			case 'puzzles/sheet': return await streamSheet(app, caller, body, res);
			case 'admin/players': return await adminPlayers(app, caller, res);
			case 'admin/migrate-slots': return await migrateSlots(app, caller, res);
			case 'completions/list': return await listCompletions(app, caller, res);
			case 'completions/record': return await recordCompletion(app, caller, body, res);
			case 'completions/leaderboard': return await leaderboard(app, caller, body, res);
			case 'scores/start': return await startScore(app, caller, body, res);
			case 'scores/submit': return await submitScore(app, caller, body, res);
			case 'scores/leaderboard': return await scoreBoard(app, caller, body, res);
			case 'profile/get': return await getProfile(app, caller, body, res);
			case 'profile/about': return await saveAbout(app, caller, body, res);
			default: return sendJson(res, 404, { error: `Unknown route: ${route}` });
		}
	} catch (error) {
		console.error('jumble_data failed:', error);
		return sendJson(res, 500, { error: 'Something went wrong. Try again.' });
	}
};

// For tests: the scoring rules, which need no database.
module.exports.scoreRun = scoreRun;
module.exports.playerRows = playerRows;
