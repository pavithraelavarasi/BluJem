'use strict';

const crypto = require('crypto');
const { ZiaDailyPuzzleClient } = require('./lib/zia-daily-puzzle-client');
const { checkInput, failure, failureFrom } = require('./lib/process-daily');
const daily = require('./lib/daily-requests');
const storage = require('./lib/daily-storage');
const store = require('./lib/store-daily-puzzle');
const release = require('./lib/app-release');
const { sitePage } = require('./lib/site-pages');

/**
 * The BluJem daily puzzle pipeline — first stage only: extraction.
 *
 * The agent takes a minute or two to read a puzzle, and an Advanced I/O
 * function is stopped at 30 seconds, so the work is split the way the layout
 * agent's is: this function takes the images, uploads them to Zia and starts
 * the blujem_daily_job job; the job asks the agent, validates its reply and
 * leaves the result in the cache, where the result route finds it.
 *
 * POST …/server/blujem_daily/process-daily-test
 *   (or /api/blujem/process-daily-test once an API Gateway route maps it here)
 *   headers: x-jumble-token — an admin's sign-in token from jumble_auth
 *   body: {
 *     images:       the puzzle as 1-3 images — one picture of the whole puzzle,
 *                   or the pieces the source page shows (word rows, cartoon,
 *                   answer boxes): [{ base64, fileName? }], PNG or JPEG
 *     imageBase64?: a single image instead, the older form
 *     fileName?:    for imageBase64, the name for the upload to Zia
 *     expectedDate?: yyyy-MM-dd; defaults to today in Asia/Kolkata
 *     sourceUrl?:   where the image came from, passed to the agent as context
 *   }
 *   → 202 { status: PENDING, requestId, expectedDate }
 *
 * POST …/server/blujem_daily/process-daily-result   body: { requestId }
 *   → { status: PENDING } until the job is done, then the day's record:
 *     { status: RENDERED | NEEDS_REVIEW | STALE_SOURCE | FAILED, extraction,
 *       checks, assets: { "collage-letters.png": key, … }, layout, … }
 *
 * POST …/server/blujem_daily/daily-list               body: {}
 *   → { puzzles: [record, …] } newest first — for the admin's review screen
 *
 * POST …/server/blujem_daily/daily-asset              body: { key }
 *   → { key, contentType, base64 } — one stored image, for previews and drafts
 *
 * POST …/server/blujem_daily/store-daily-puzzle
 *   (or /api/blujem/store-daily-puzzle once an API Gateway route maps it here)
 *   headers: x-jumble-token (an admin's) or x-blujem-ingest-key (BLUJEM_INGEST_KEY)
 *   body: { puzzleDate: yyyy-MM-dd, sourceUrl?, imageUrl | imageBase64, metadata? }
 *   → { status: success, imageKey: yyyy/MM/dd/source.png, metadataKey: yyyy/MM/dd/puzzle.json }
 *   Stores the image as it came — in the blujem-sources bucket — and nothing else.
 *
 * The Android app's own updates (lib/app-release.js), in the blujem bucket under releases/android/:
 * POST …/server/blujem_daily/app-latest       no sign-in needed
 *   → { versionCode, versionName, notes, sha256, size, apkUrl } — apkUrl a signed link for an hour;
 *     { versionCode: 0 } when nothing is published
 * POST …/server/blujem_daily/app-upload-url   admins: { versionCode, versionName } → { key, uploadUrl }
 * POST …/server/blujem_daily/app-publish      admins: { versionCode, versionName, sha256, size, notes? }
 *
 * GET …/server/blujem_daily/home and …/privacy — public HTML pages (lib/site-pages.js),
 * linked from Google's OAuth consent screen.
 *
 * The job draws the BluJem images and stores everything under
 * blujem-daily/yyyy/MM/dd/ in Stratus. Nothing is published: the admin turns a
 * day into a draft in the app and publishes it from there. Zia credentials
 * live only in the functions' environment variables.
 */

const TOKEN_HEADER = 'x-jumble-token';
/** Tokens issued by the old DailyJumble project carry its user ids, so only BluJem's are accepted. */
const TOKEN_PROJECT = 'blujem';
/** For a server-side caller (a fetcher or scheduler) that has no admin sign-in. */
const INGEST_KEY_HEADER = 'x-blujem-ingest-key';

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

/** The caller, from the token jumble_auth issued, or null — as jumble_ai checks it. */
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

/** True when the request carries the ingest key set in BLUJEM_INGEST_KEY. */
function hasIngestKey(req) {
	const secret = String(process.env.BLUJEM_INGEST_KEY || '');
	// A short key is as good as none: refuse them all rather than accept a guessable one.
	if (secret.length < 32) return false;
	const given = crypto.createHash('sha256').update(String(req.headers[INGEST_KEY_HEADER] || '')).digest();
	return crypto.timingSafeEqual(given, crypto.createHash('sha256').update(secret).digest());
}

/** Stores the day's source image and its metadata in the blujem-sources bucket. */
async function storeDailyPuzzle(deps, req, body, res, storedBy) {
	try {
		const result = await store.storeDailyPuzzle(deps.store, deps.catalyst(req), body, storedBy);
		console.log('store-daily-puzzle:', JSON.stringify({ imageKey: result.imageKey, storedBy }));
		return sendJson(res, 200, result);
	} catch (error) {
		if (!(error instanceof store.StoreError)) throw error;
		return sendJson(res, error.http, { status: 'error', error: { code: error.code, message: error.message } });
	}
}

/** Sends the browser to the latest APK, or back to the download page when there is none. */
async function downloadApk(deps, req, res) {
	const latest = await release.latest(deps.catalyst(req));
	res.writeHead(302, { Location: latest.apkUrl || 'download', 'Cache-Control': 'no-store' });
	return res.end();
}

/** Runs one app-release step, giving its ReleaseError as JSON. */
async function appRelease(res, step) {
	try {
		return sendJson(res, 200, await step());
	} catch (error) {
		if (!(error instanceof release.ReleaseError)) throw error;
		return sendJson(res, error.http, { status: 'error', error: { code: error.code, message: error.message } });
	}
}

/**
 * Takes the images, uploads them to Zia and starts the job that reads them.
 * Answers within seconds; the result comes from [processDailyResult].
 */
async function processDailyTest(deps, req, body, res) {
	const images = Array.isArray(body.images)
		? body.images.map((piece) => ({
			data: Buffer.from(String((piece && piece.base64) || ''), 'base64'),
			fileName: piece && piece.fileName
		}))
		: [{ data: Buffer.from(String(body.imageBase64 || ''), 'base64'), fileName: body.fileName }];

	const input = checkInput({ images, expectedDate: body.expectedDate });
	if (input.failed) return sendResult(res, input.failed);

	const started = Date.now();
	let fileIds;
	try {
		fileIds = await deps.client().uploadAll(input.pieces, input.expected);
	} catch (error) {
		return sendResult(res, failureFrom(error, input.expected, started));
	}

	const requestId = daily.newRequestId();
	try {
		const app = deps.catalyst(req);
		// Kept for the job, which draws the collage from the source image.
		const sourceKeys = await storage.saveSources(app, input.expected, input.pieces);
		await daily.start(app, {
			requestId,
			fileIds,
			sourceKeys,
			expectedDate: input.expected,
			sourceUrl: body.sourceUrl
		});
	} catch (error) {
		console.error('process-daily-test: the job could not start:', error && error.message);
		return sendResult(res, failure(input.expected, 'JOB_NOT_STARTED', 'The processor could not start.', undefined, started));
	}
	console.log('process-daily-test started:', JSON.stringify({ requestId, images: fileIds.length, expectedDate: input.expected }));
	return sendJson(res, 202, { status: 'PENDING', requestId, expectedDate: input.expected });
}

/** What the job found, or PENDING while it is still reading. */
async function processDailyResult(deps, req, body, res) {
	const requestId = String(body.requestId || '').replace(/[^A-Za-z0-9_]/g, '');
	if (!requestId) return sendJson(res, 400, { error: 'requestId is required.' });
	const result = await daily.read(deps.catalyst(req), requestId);
	return sendJson(res, 200, result);
}

/** The stored days, newest first, for the admin's review screen. */
async function dailyList(deps, req, body, res) {
	const puzzles = await storage.listPuzzles(deps.catalyst(req), Math.min(Number(body.limit) || 30, 60));
	return sendJson(res, 200, { puzzles });
}

/** One stored file, for a preview or a draft. Only daily files can be read. */
async function dailyAsset(deps, req, body, res) {
	const key = String(body.key || '');
	if (!storage.isDailyKey(key)) return sendJson(res, 400, { error: 'Not a daily puzzle file.' });
	try {
		const bytes = await storage.read(deps.catalyst(req), key);
		const contentType = key.endsWith('.json') ? 'application/json' : 'image/png';
		return sendJson(res, 200, { key, contentType, base64: bytes.toString('base64') });
	} catch (error) {
		return sendJson(res, 404, { error: 'No such file.' });
	}
}

/** A completed run is 200 whatever it found; only a failure to run is an error. */
function sendResult(res, result) {
	const http = result.status !== 'FAILED' ? 200
		: result.error.code === 'ZIA_NOT_CONFIGURED' ? 503
			: result.error.code === 'ZIA_TIMEOUT' ? 504
				: ['SOURCE_UNAVAILABLE', 'SOURCE_TOO_LARGE', 'TOO_MANY_IMAGES', 'BAD_EXPECTED_DATE'].includes(result.error.code) ? 400
					: 502;
	return sendJson(res, http, result);
}

/** The real services; tests pass their own. */
const realDeps = {
	client: () => ZiaDailyPuzzleClient.fromEnv(),
	catalyst: (req) => require('zcatalyst-sdk-node').initialize(req, { scope: 'admin' }),
	store: store.realDeps
};

/** The function, with its services given — so tests can stand them in. */
function createHandler(deps = realDeps) {
	return async (req, res) => {
		try {
			if (req.method === 'OPTIONS') {
				res.writeHead(204);
				return res.end();
			}

			const path = new URL(req.url, `https://${req.headers.host || 'localhost'}`).pathname;
			const route = path.replace(/\/+$/, '').split('/').pop();

			// The public home page and privacy policy, linked from Google's consent screen.
			const html = req.method === 'GET' ? sitePage(route) : null;
			if (html) {
				res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
				return res.end(html);
			}
			// The download page's button: straight to a freshly signed link to the latest APK.
			if (req.method === 'GET' && route === 'download-apk') return await downloadApk(deps, req, res);
			if (req.method !== 'POST') return sendJson(res, 405, { error: 'Use POST.' });

			// Every copy of the app asks this on start, signed in or not.
			if (route === 'app-latest') return await appRelease(res, () => release.latest(deps.catalyst(req)));

			// Storing a source image may also come from a server holding the ingest key.
			if (route === 'store-daily-puzzle' && hasIngestKey(req)) {
				return await storeDailyPuzzle(deps, req, await readBody(req), res, 'ingest-key');
			}

			// Admins only: every run costs a Zia agent call.
			const caller = readToken(req);
			if (!caller) return sendJson(res, 401, { error: 'Sign in again.' });
			if (caller.role !== 'admin') return sendJson(res, 403, { error: 'Only an admin can run the daily puzzle processor.' });

			const body = await readBody(req);

			switch (route) {
				case 'process-daily-test': return await processDailyTest(deps, req, body, res);
				case 'process-daily-result': return await processDailyResult(deps, req, body, res);
				case 'daily-list': return await dailyList(deps, req, body, res);
				case 'daily-asset': return await dailyAsset(deps, req, body, res);
				case 'app-upload-url': return await appRelease(res, () => release.uploadUrl(deps.catalyst(req), body));
				case 'app-publish': return await appRelease(res, () => release.publish(deps.catalyst(req), body, `admin:${caller.sub}`));
				case 'store-daily-puzzle': return await storeDailyPuzzle(deps, req, body, res, `admin:${caller.sub}`);
				default: return sendJson(res, 404, { error: `Unknown route: ${route}` });
			}
		} catch (error) {
			console.error('blujem_daily failed:', error && error.message);
			return sendJson(res, 500, { status: 'FAILED', error: { code: 'INTERNAL', message: 'The processor failed.' } });
		}
	};
}

module.exports = createHandler();
module.exports.createHandler = createHandler;
module.exports.readToken = readToken;
