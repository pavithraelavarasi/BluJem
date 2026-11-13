'use strict';

const catalyst = require('zcatalyst-sdk-node');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');

/**
 * The AI half of Daily Jumble.
 *
 * The dictionary still decides what a word can be — this only chooses between
 * candidates it is given, writes hints in plainer English than a glossary can,
 * and reasons about the cartoon pun at the end. Everything it returns is
 * checked here before it is sent on, and the app checks it again, so a wrong or
 * missing answer costs a fallback rather than a broken puzzle.
 *
 * The API key lives in this function's environment and never reaches a phone.
 */

const MODEL = process.env.AI_MODEL || 'claude-opus-5';
const PROVIDER = process.env.AI_PROVIDER || 'anthropic';
const TOKEN_HEADER = 'x-jumble-token';
/** Tokens issued by the old DailyJumble project carry its user ids, so only BluJem's are accepted. */
const TOKEN_PROJECT = 'blujem';
const CACHE_DAYS = 2;

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

/** The caller, from the token jumble_auth issued, or null. */
function readToken(req) {
	const secret = process.env.JUMBLE_TOKEN_SECRET;
	if (!secret) return null;

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

/** Letters only, upper case — how every answer is compared. */
const letters = (text) => String(text || '').toUpperCase().replace(/[^A-Z]/g, '');

/** Same letters, any order. */
const sameLetters = (a, b) =>
	letters(a).split('').sort().join('') === letters(b).split('').sort().join('');

// -------------------------------------------------------------------- cache
//
// Hints cost money and never change for a given puzzle, word and level, so one
// is generated once and then served from the cache.

async function cached(app, key, produce) {
	const segment = app.cache().segment();
	const safeKey = key.replace(/[^A-Za-z0-9_.-]/g, '_').slice(0, 120);

	const hit = await segment.get(safeKey).catch(() => null);
	const cachedValue = hit && hit.cache_value;
	if (cachedValue) {
		try { return { ...JSON.parse(cachedValue), cached: true }; } catch (e) { /* fall through */ }
	}

	const fresh = await produce();
	if (fresh) {
		await segment.put(safeKey, JSON.stringify(fresh), CACHE_DAYS).catch(() => null);
	}
	return fresh;
}

// ----------------------------------------------------------------- the model

/** Whether an AI call can be made at all. */
const configured = () => Boolean(process.env.AI_API_KEY);

/**
 * Zia OCR is off unless it is switched on, and it needs no AI provider — it is
 * part of Catalyst. The app reads sheets perfectly well without it.
 */
const ziaEnabled = () => String(process.env.ZIA_OCR_ENABLED || '').toLowerCase() === 'true';

function client() {
	const apiKey = process.env.AI_API_KEY;
	if (!apiKey) throw new Error('AI_API_KEY is not set');
	if (PROVIDER !== 'anthropic') throw new Error(`Unsupported AI_PROVIDER: ${PROVIDER}`);
	return new Anthropic({ apiKey });
}

/** One short answer from the model, as plain text. */
async function askForText(system, prompt) {
	const response = await client().messages.create({
		model: MODEL,
		max_tokens: 1000,
		output_config: { effort: 'low' },
		system,
		messages: [{ role: 'user', content: prompt }]
	});
	if (response.stop_reason === 'refusal') return null;
	return response.content
		.filter((block) => block.type === 'text')
		.map((block) => block.text)
		.join(' ')
		.trim();
}

/** One answer from the model, shaped by a schema. */
async function askForJson(system, prompt, schema) {
	const response = await client().messages.create({
		model: MODEL,
		max_tokens: 2000,
		output_config: { effort: 'low', format: { type: 'json_schema', schema } },
		system,
		messages: [{ role: 'user', content: prompt }]
	});
	if (response.stop_reason === 'refusal') return null;

	const text = response.content
		.filter((block) => block.type === 'text')
		.map((block) => block.text)
		.join('');
	try { return JSON.parse(text); } catch (e) { return null; }
}

// ------------------------------------------------------------- zia agent
//
// Hints can come from a Zia agent instead: an agent built in Zia Agents
// (ziaagents.zoho.in) whose own instructions say how to write a Jumble hint.
// It is used whenever all six ZIA_AGENT_* settings are present, and the
// function behaves exactly as before when they are not.
//
// The agent is reached with a Zoho OAuth access token, made here from a
// long-lived refresh token (a Self Client in the Zoho API console, scope
// ZiaAgents.agents.TRIGGER). Access tokens last an hour, so one is kept and
// reused until shortly before it runs out.

const AGENT_BASE = process.env.ZIA_AGENT_BASE || 'https://ziaagents.zoho.in';
const AGENT_ACCOUNTS = process.env.ZIA_AGENT_ACCOUNTS || 'https://accounts.zoho.in';

// Each agent is reached at its own trigger URL (Integrate tab), which runs
// whatever version is deployed now — so redeploying an agent needs no change
// here. The older org, agent and version headers still work as a fallback.
const HINT_AGENT_URL = process.env.ZIA_HINT_AGENT_URL || '';

const agentCredentials = () => [
	'ZIA_AGENT_CLIENT_ID', 'ZIA_AGENT_CLIENT_SECRET', 'ZIA_AGENT_REFRESH_TOKEN'
].every((name) => Boolean(process.env[name]));

const agentConfigured = () => agentCredentials() && (Boolean(HINT_AGENT_URL) || [
	'ZIA_AGENT_ORG_ID', 'ZIA_AGENT_ID', 'ZIA_AGENT_VERSION_ID'
].every((name) => Boolean(process.env[name])));

/** Hints can be written at all: by the agent, or by the model. */
const hintsConfigured = () => agentConfigured() || configured();

let agentToken = null;
let agentTokenExpires = 0;

async function agentAccessToken() {
	if (agentToken && Date.now() < agentTokenExpires) return agentToken;
	const params = new URLSearchParams({
		refresh_token: process.env.ZIA_AGENT_REFRESH_TOKEN,
		client_id: process.env.ZIA_AGENT_CLIENT_ID,
		client_secret: process.env.ZIA_AGENT_CLIENT_SECRET,
		grant_type: 'refresh_token'
	});
	const reply = await fetch(`${AGENT_ACCOUNTS}/oauth/v2/token?${params}`, { method: 'POST' });
	const json = await reply.json().catch(() => ({}));
	if (!json.access_token) {
		throw new Error(`Zia agent token refused: ${json.error || reply.status}`);
	}
	agentToken = json.access_token;
	// Renewed five minutes early, so a call never goes out on a dying token.
	agentTokenExpires = Date.now() + ((Number(json.expires_in) || 3600) - 300) * 1000;
	return agentToken;
}

/**
 * The reply of the agent at [url] to [query], or null when it could not be
 * asked. With no url, the hint agent.
 */
async function askAgent(query, url = HINT_AGENT_URL) {
	const token = await agentAccessToken();
	const reply = url
		? await fetch(url, {
			method: 'POST',
			headers: {
				'Authorization': `Zoho-oauthtoken ${token}`,
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({ query })
		})
		: await fetch(`${AGENT_BASE}/ziaagents/api/v1/agents/query`, {
			method: 'POST',
			headers: {
				'Authorization': `Zoho-oauthtoken ${token}`,
				'Content-Type': 'application/json',
				'X-ZIAAGENTS-ORG': process.env.ZIA_AGENT_ORG_ID,
				'X-ZIAAGENTS-AGENT-ID': process.env.ZIA_AGENT_ID,
				'X-ZIAAGENTS-AGENT-VERSION-ID': process.env.ZIA_AGENT_VERSION_ID
			},
			body: JSON.stringify({ query })
		});
	const json = await reply.json().catch(() => ({}));
	if (!reply.ok) {
		// A token the agent rejects is dropped, so the next call makes a new one.
		if (reply.status === 401) agentToken = null;
		console.error('Zia agent call failed:', reply.status, JSON.stringify(json).slice(0, 300));
		return null;
	}
	const text = json && json.data && json.data.response;
	return typeof text === 'string' ? text.trim() : null;
}

// --------------------------------------------------------- sheet checker
//
// A second pair of eyes on an uploaded sheet: the sheet agent is shown the
// image and says what it reads — each scrambled word, how many squares it has,
// and the cartoon caption. The app compares that with its own detector and
// tells the admin where they disagree. The detector still decides where every
// square is; the agent's reading only checks it.

const SHEET_AGENT_URL = process.env.ZIA_SHEET_AGENT_URL || '';
const sheetAgentConfigured = () => agentCredentials() && Boolean(SHEET_AGENT_URL);

/** Uploads an image to Zia Agents, for an agent to be shown, and gives its file id. */
async function uploadToAgents(bytes, fileName, mimeType) {
	const form = new FormData();
	form.append('file', new Blob([bytes], { type: mimeType }), fileName);
	form.append('fileName', fileName);
	const headers = { 'Authorization': `Zoho-oauthtoken ${await agentAccessToken()}` };
	if (process.env.ZIA_AGENT_ORG_ID) headers['X-ZIAAGENTS-ORG'] = process.env.ZIA_AGENT_ORG_ID;
	const reply = await fetch(`${AGENT_BASE}/ziaagents/api/v1/files`, {
		method: 'POST', headers, body: form
	});
	const json = await reply.json().catch(() => ({}));
	const id = json && json.data && json.data.fileId;
	if (!id) {
		console.error('Zia file upload failed:', reply.status, JSON.stringify(json).slice(0, 300));
		return null;
	}
	return String(id);
}

/** The first {...} in [text], parsed — agents wrap JSON in code fences at times. */
function jsonIn(text) {
	const start = String(text || '').indexOf('{');
	const end = String(text || '').lastIndexOf('}');
	if (start === -1 || end <= start) return null;
	try { return JSON.parse(text.slice(start, end + 1)); } catch (e) { return null; }
}

async function checkSheet(caller, body, res) {
	if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can check sheets.' });
	if (!sheetAgentConfigured()) return sendJson(res, 503, { error: 'The sheet checker is not set up.' });

	const bytes = Buffer.from(String(body.imageBase64 || ''), 'base64');
	if (bytes.length === 0) return sendJson(res, 400, { error: 'imageBase64 is required.' });
	if (bytes.length > 10 * 1024 * 1024) return sendJson(res, 413, { error: 'That image is too large.' });
	const mimeType = bytes[0] === 0x89 ? 'image/png' : 'image/jpeg';

	const fileId = await uploadToAgents(bytes, `sheet_${Date.now()}.${mimeType === 'image/png' ? 'png' : 'jpg'}`, mimeType);
	if (!fileId) return sendJson(res, 502, { error: 'The sheet could not be sent to the checker.' });

	const reply = await fetch(SHEET_AGENT_URL, {
		method: 'POST',
		headers: {
			'Authorization': `Zoho-oauthtoken ${await agentAccessToken()}`,
			'Content-Type': 'application/json'
		},
		body: JSON.stringify({ query: 'Check this Jumble sheet.', attachments: [fileId] })
	});
	const json = await reply.json().catch(() => ({}));
	const text = json && json.data && json.data.response;
	const reading = typeof text === 'string' ? jsonIn(text) : null;
	if (!reply.ok || !reading || !Array.isArray(reading.words)) {
		console.error('Sheet checker gave no reading:', reply.status, String(text || JSON.stringify(json)).slice(0, 300));
		return sendJson(res, 502, { error: 'The checker could not read that sheet.' });
	}

	// Only what the agent reads reliably goes back: the words and the clue.
	// Its circles and box positions are not trusted, so they are not passed on.
	const words = reading.words
		.map((w) => ({
			scrambled: letters(w && w.scrambled) || '?',
			squares: Number(w && w.squares) || 0
		}))
		.filter((w) => w.squares > 0 || w.scrambled !== '?');
	return sendJson(res, 200, { words, clue: String(reading.clue || '').trim() });
}

// --------------------------------------------------------- layout agent
//
// Where everything is on an uploaded sheet, from the Zia layout agent: each
// word's answer squares, the circled ones, and the answer row. It answers in
// about half a minute, and this function is stopped at thirty seconds, so the
// call itself runs in the jumble_layout job. Here the image goes up to Zia and
// the job is started; the admin's phone then asks for the result until it is
// there. Players never come here — the layout is found once, at upload.

const LAYOUT_AGENT_URL = process.env.ZIA_LAYOUT_AGENT_URL || '';
const layoutConfigured = () => agentCredentials() && Boolean(LAYOUT_AGENT_URL) &&
	Boolean(process.env.LAYOUT_CACHE_SEGMENT_ID);
const layoutCache = (app) => app.cache().segment(process.env.LAYOUT_CACHE_SEGMENT_ID);

async function startLayoutDetection(app, caller, body, res) {
	if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can detect layouts.' });
	if (!layoutConfigured()) return sendJson(res, 503, { error: 'Layout detection is not set up.', reason: 'not_configured' });

	const bytes = Buffer.from(String(body.imageBase64 || ''), 'base64');
	if (bytes.length === 0) return sendJson(res, 400, { error: 'imageBase64 is required.' });
	if (bytes.length > 10 * 1024 * 1024) return sendJson(res, 413, { error: 'That image is too large.' });
	const mimeType = bytes[0] === 0x89 ? 'image/png' : 'image/jpeg';

	const fileId = await uploadToAgents(bytes, `layout_${Date.now()}.${mimeType === 'image/png' ? 'png' : 'jpg'}`, mimeType)
		.catch((error) => { console.error('Layout upload failed:', error); return null; });
	if (!fileId) return sendJson(res, 502, { error: 'The sheet could not be sent for detection.', reason: 'unavailable' });

	const requestId = `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
	try {
		await layoutCache(app).put(`layout_${requestId}`, JSON.stringify({ status: 'pending' }), 1);
		await app.jobScheduling().job().submitJob({
			job_name: 'detect_layout',
			jobpool_name: process.env.LAYOUT_JOB_POOL || 'LayoutPool',
			target_type: 'Function',
			target_name: 'jumble_layout',
			params: { requestId, fileId }
		});
	} catch (error) {
		console.error('Layout job could not start:', error);
		return sendJson(res, 502, { error: 'Layout detection could not start.', reason: 'unavailable' });
	}
	return sendJson(res, 202, { requestId });
}

async function layoutResult(app, caller, body, res) {
	if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can detect layouts.' });
	const requestId = String(body.requestId || '').replace(/[^A-Za-z0-9_]/g, '');
	if (!requestId) return sendJson(res, 400, { error: 'requestId is required.' });
	const value = await layoutCache(app).getValue(`layout_${requestId}`).catch(() => null);
	let result = null;
	try { result = value ? JSON.parse(value) : null; } catch (e) { result = null; }
	// A request the cache no longer knows has expired; it will not finish now.
	return sendJson(res, 200, result || { status: 'failed', reason: 'expired' });
}

const HINT_SYSTEM =
	'You write hints for a classic newspaper Jumble word puzzle. A hint nudges ' +
	'the player towards the answer without ever giving it away. Keep every hint ' +
	'to one short sentence, plain English, no quotation marks.';

// --------------------------------------------------------------- zia ocr
//
// A second pair of eyes on an uploaded sheet. ML Kit reads it on the phone
// first; this is only asked when a row came back unreadable, and its answer is
// a suggestion the dictionary still has to accept.

async function ziaReadSheet(app, body, res) {
	if (!ziaEnabled()) return sendJson(res, 503, { error: 'Zia OCR is not enabled.' });

	const bytes = Buffer.from(String(body.imageBase64 || ''), 'base64');
	if (bytes.length === 0) return sendJson(res, 400, { error: 'imageBase64 is required.' });
	if (bytes.length > 10 * 1024 * 1024) {
		return sendJson(res, 413, { error: 'That image is too large.' });
	}

	// Zia reads from a stream, so the upload lands in the function's own tmp
	// space and is removed again whatever happens.
	const file = path.join(os.tmpdir(), `sheet_${Date.now()}_${Math.random().toString(36).slice(2)}.png`);
	try {
		fs.writeFileSync(file, bytes);
		const reading = await app.zia().extractOpticalCharacters(fs.createReadStream(file));
		return sendJson(res, 200, {
			text: String((reading && reading.text) || ''),
			confidence: (reading && reading.confidence) || null
		});
	} catch (error) {
		console.error('Zia OCR failed:', error);
		return sendJson(res, 502, { error: 'Zia OCR is unavailable.' });
	} finally {
		fs.promises.unlink(file).catch(() => null);
	}
}

// ------------------------------------------------------------------- routes

/**
 * Picks between candidates the dictionary already vouched for.
 *
 * The model cannot introduce a word of its own: anything outside the supplied
 * list is thrown away here, and the caller falls back to the dictionary's own
 * ranking.
 */
async function selectAnswer(body, res) {
	const scrambled = letters(body.scrambled);
	const candidates = (Array.isArray(body.candidates) ? body.candidates : [])
		.map(letters)
		.filter((word) => word && sameLetters(word, scrambled));

	if (candidates.length === 0) {
		return sendJson(res, 400, { error: 'No valid candidates supplied.' });
	}
	if (candidates.length === 1) {
		return sendJson(res, 200, { answer: candidates[0], confidence: 1, source: 'dictionary' });
	}
	if (!configured()) return sendJson(res, 503, { error: 'AI is not configured.' });

	const context = [
		`Scrambled letters: ${scrambled}`,
		`Candidates: ${candidates.join(', ')}`,
		body.clue ? `Cartoon clue for the whole puzzle: ${body.clue}` : null,
		Array.isArray(body.solvedWords) && body.solvedWords.length
			? `Other answers already solved on this sheet: ${body.solvedWords.join(', ')}`
			: null
	].filter(Boolean).join('\n');

	const reply = await askForJson(
		'You solve classic newspaper Jumble puzzles.',
		`${context}\n\nChoose the single most likely answer from ONLY the candidates ` +
		`listed. Jumble answers are everyday words. Do not invent a word that is not ` +
		`in the list.`,
		{
			type: 'object',
			properties: {
				answer: { type: 'string', enum: candidates },
				confidence: { type: 'number' }
			},
			required: ['answer', 'confidence'],
			additionalProperties: false
		}
	);

	const answer = letters(reply && reply.answer);
	if (!answer || !candidates.includes(answer)) {
		return sendJson(res, 200, { answer: null, reason: 'unusable' });
	}
	return sendJson(res, 200, {
		answer,
		confidence: Number(reply.confidence) || 0.5,
		source: 'ai'
	});
}

/**
 * Notes, against the player's run of this sheet, the highest hint they have
 * been shown for a word — so the points for it are worked out from the hints
 * this service handed out, not only from what the app says. Best effort: a
 * hint is never held up or refused because it could not be noted.
 */
async function recordHint(app, caller, puzzleId, wordId, level) {
	if (!caller || !caller.id || !puzzleId || !wordId) return;
	try {
		const quote = (v) => String(v).replace(/'/g, "''");
		const rows = await app.zcql().executeZCQLQuery(
			`SELECT ROWID, HintLevels, Status FROM PuzzleScores WHERE UserId = '${quote(caller.id)}' ` +
			`AND PuzzleId = '${quote(puzzleId)}'`
		);
		const row = rows.map((r) => r.PuzzleScores).filter(Boolean)[0];
		if (!row || row.Status === 'completed') return;
		let levels = {};
		try { levels = JSON.parse(row.HintLevels || '{}'); } catch (e) { levels = {}; }
		const key = String(wordId);
		if ((Number(levels[key]) || 0) >= level) return;
		levels[key] = level;
		await app.datastore().table('PuzzleScores')
			.updateRow({ ROWID: row.ROWID, HintLevels: JSON.stringify(levels) });
	} catch (error) {
		console.error('Could not note the hint:', error.message);
	}
}

/** A hint for one scrambled word, at a level the player has worked up to. */
async function wordHint(app, body, res, caller) {
	const answer = letters(body.answer);
	const scrambled = letters(body.scrambled);
	const level = Math.min(Math.max(Number(body.level) || 1, 1), 3);
	if (!answer) return sendJson(res, 400, { error: 'answer is required.' });
	if (!hintsConfigured()) return sendJson(res, 503, { error: 'AI is not configured.' });

	const previous = Array.isArray(body.previousHints) ? body.previousHints : [];
	const key = `hint_${body.puzzleId || 'x'}_${body.wordId || 'x'}_${level}`;
	const noted = recordHint(app, caller, body.puzzleId, body.wordId, level);

	const result = await cached(app, key, async () => {
		const hint = await hintWithRetry(
			`Correct answer: ${answer}\nScrambled letters: ${scrambled}\nHint level: ${level}\n` +
			(previous.length ? `Hints already given: ${previous.join(' | ')}\n` : '') +
			`\nLevel 1 means a gentle clue about what the word means. Level 2 means a ` +
			`stronger clue about its meaning or how it is used. Level 3 means a clue ` +
			`about its letters, such as what it starts and ends with.\n\n` +
			`Rules: never write the answer itself, never repeat an earlier hint, one ` +
			`short sentence, return the hint text only.`,
			answer
		);
		return hint ? { hint } : null;
	});

	await noted;
	if (!result || !result.hint) return sendJson(res, 200, { hint: null, reason: 'unusable' });
	return sendJson(res, 200, { hint: result.hint, cached: Boolean(result.cached) });
}

/** A hint for the cartoon answer, which is usually a pun. */
async function finalHint(app, body, res) {
	const answer = letters(body.answer);
	const level = Math.min(Math.max(Number(body.level) || 1, 1), 3);
	if (!hintsConfigured()) return sendJson(res, 503, { error: 'AI is not configured.' });
	const previous = Array.isArray(body.previousHints) ? body.previousHints : [];
	const key = `final_${body.puzzleId || 'x'}_${level}`;

	const result = await cached(app, key, async () => {
		const hint = await hintWithRetry(
			`This is the final answer of a newspaper Jumble, and it is usually a pun.\n` +
			(body.answer ? `Correct answer: ${body.answer}\n` : '') +
			(body.clue ? `Cartoon clue: ${body.clue}\n` : '') +
			(body.circledLetters ? `Letters available: ${body.circledLetters}\n` : '') +
			`Hint level: ${level}\n` +
			(previous.length ? `Hints already given: ${previous.join(' | ')}\n` : '') +
			`\nLevel 1 means general context from the clue. Level 2 means a stronger ` +
			`pointer to the idea behind the joke. Level 3 means naming the kind of ` +
			`wordplay without saying the phrase.\n\n` +
			`Rules: never write the answer itself, never repeat an earlier hint, one ` +
			`short sentence, return the hint text only.`,
			answer
		);
		return hint ? { hint } : null;
	});

	if (!result || !result.hint) return sendJson(res, 200, { hint: null, reason: 'unusable' });
	return sendJson(res, 200, { hint: result.hint, cached: Boolean(result.cached) });
}

/**
 * Asks once, and again if the first attempt gave the answer away.
 *
 * A hint containing the answer is worse than no hint, so it is rejected rather
 * than shown.
 */
async function hintWithRetry(prompt, answer) {
	for (let attempt = 0; attempt < 2; attempt++) {
		// The agent when it is set up, the model otherwise. An agent that
		// cannot be reached costs this attempt, not the whole hint.
		const hint = agentConfigured()
			? await askAgent(prompt).catch((error) => {
				console.error('Zia agent unavailable:', error.message);
				return null;
			})
			: await askForText(HINT_SYSTEM, prompt);
		if (!hint) continue;
		if (answer && hint.toUpperCase().replace(/[^A-Z]/g, '').includes(answer)) continue;
		return hint;
	}
	return null;
}

/** Works out the cartoon phrase from the circled letters and the clue. */
async function solveFinal(body, res) {
	const available = letters(body.circledLetters);
	if (!available) return sendJson(res, 400, { error: 'circledLetters is required.' });
	if (!configured()) return sendJson(res, 503, { error: 'AI is not configured.' });

	const reply = await askForJson(
		'You solve the cartoon answer of a classic newspaper Jumble. It is a pun or ' +
		'a familiar phrase, spelled with exactly the circled letters.',
		[
			`Circled letters (each used exactly once): ${available}`,
			body.clue ? `Cartoon clue: ${body.clue}` : null,
			Array.isArray(body.solvedWords) && body.solvedWords.length
				? `The solved words: ${body.solvedWords.join(', ')}`
				: null,
			body.groupSizes ? `The answer is printed as word lengths: ${body.groupSizes}` : null,
			'',
			'Give the phrase, and one sentence explaining the joke.'
		].filter((line) => line !== null).join('\n'),
		{
			type: 'object',
			properties: {
				answer: { type: 'string' },
				explanation: { type: 'string' },
				confidence: { type: 'number' }
			},
			required: ['answer', 'explanation', 'confidence'],
			additionalProperties: false
		}
	);

	// The phrase has to be spellable from the circled letters, or it is wrong
	// however plausible it reads.
	if (!reply || !sameLetters(reply.answer, available)) {
		return sendJson(res, 200, { answer: null, reason: 'letters-do-not-match' });
	}
	return sendJson(res, 200, {
		answer: String(reply.answer).toUpperCase(),
		explanation: String(reply.explanation || ''),
		confidence: Number(reply.confidence) || 0.5
	});
}

// ------------------------------------------------------------------ handler

module.exports = async (req, res) => {
	try {
		if (req.method === 'OPTIONS') {
			res.writeHead(204);
			return res.end();
		}
		if (req.method !== 'POST') return sendJson(res, 405, { error: 'Use POST.' });

		// Signed-in players only: an open endpoint would be someone else's
		// model bill.
		const caller = readToken(req);
		if (!caller) return sendJson(res, 401, { error: 'Sign in again.' });

		const path = new URL(req.url, `https://${req.headers.host || 'localhost'}`).pathname;
		const route = path.replace(/\/+$/, '').split('/').slice(-2).join('/');
		const body = await readBody(req);
		const app = catalyst.initialize(req, { scope: 'admin' });

		switch (route) {
			case 'ocr/read': return await ziaReadSheet(app, body, res);
			case 'jumble/select-answer': return await selectAnswer(body, res);
			case 'jumble/hint': return await wordHint(app, body, res, caller);
			case 'final/hint': return await finalHint(app, body, res);
			case 'final/solve': return await solveFinal(body, res);
			case 'sheet/check': return await checkSheet(caller, body, res);
			case 'sheet/detect-layout': return await startLayoutDetection(app, caller, body, res);
			case 'sheet/layout-result': return await layoutResult(app, caller, body, res);
			default: return sendJson(res, 404, { error: `Unknown route: ${route}` });
		}
	} catch (error) {
		console.error('jumble_ai failed:', error);
		return sendJson(res, 502, { error: 'AI is unavailable.' });
	}
};
