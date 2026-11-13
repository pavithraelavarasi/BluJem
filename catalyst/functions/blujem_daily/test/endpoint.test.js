'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { Readable } = require('stream');
const { createHandler } = require('../index');
const { createJob } = require('../../blujem_daily_job/index');
const { ZiaClientError } = require('../lib/zia-daily-puzzle-client');
const { goodReply } = require('./fixtures');
const { fakeCatalyst, fakeClient, fakeRender } = require('./fakes');
const storage = require('../lib/daily-storage');

const SECRET = 'test-secret';
const b64url = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
const PIECE = Buffer.from([0x89, 0x50, 1, 2]).toString('base64');

/** A token signed the way jumble_auth signs one. */
function tokenFor(role) {
	const payload = b64url(JSON.stringify({ sub: '1', role, project: 'blujem', exp: Date.now() + 60000 }));
	return `${payload}.${b64url(crypto.createHmac('sha256', SECRET).update(payload).digest())}`;
}

function call(handler, { token, body, route = 'process-daily-test', path }) {
	const req = Readable.from([JSON.stringify(body || {})]);
	req.method = 'POST';
	req.url = path || `/server/blujem_daily/${route}`;
	req.headers = { host: 'localhost', ...(token ? { 'x-jumble-token': token } : {}) };
	return new Promise((resolve) => {
		const res = {
			writeHead(status) { this.status = status; },
			end(data) { resolve({ status: this.status, body: data ? JSON.parse(data) : null }); }
		};
		handler(req, res);
	});
}

/** The endpoint and the job wired to the same fake cache and fake agent. */
function setup(reply = goodReply(), renderOk = true) {
	const catalyst = fakeCatalyst();
	const client = fakeClient(reply);
	const deps = { client: () => client, catalyst: () => catalyst.app };
	const jobDeps = { ...deps, storage, render: fakeRender({ ok: renderOk }), colorize: null };
	return { catalyst, client, handler: createHandler(deps), job: createJob(jobDeps) };
}

/** Runs the job exactly as Catalyst would, with the params the endpoint submitted. */
async function runSubmittedJob({ catalyst, job }) {
	const submitted = catalyst.jobs.at(-1);
	let closed = null;
	await job(
		{ getJobParam: (name) => submitted.params[name] },
		{ closeWithSuccess: () => { closed = 'success'; }, closeWithFailure: () => { closed = 'failure'; } }
	);
	return closed;
}

test.beforeEach(() => { process.env.JUMBLE_TOKEN_SECRET = SECRET; });

test('no token is 401, a player is 403', async () => {
	const { handler } = setup();
	assert.equal((await call(handler, { body: {} })).status, 401);
	assert.equal((await call(handler, { token: tokenFor('player'), body: {} })).status, 403);
});

test('a token from the old DailyJumble project is 401, even for an admin', async () => {
	const { handler } = setup();
	const payload = b64url(JSON.stringify({ sub: '1', role: 'admin', exp: Date.now() + 60000 }));
	const old = `${payload}.${b64url(crypto.createHmac('sha256', SECRET).update(payload).digest())}`;
	assert.equal((await call(handler, { token: old, body: {} })).status, 401);
});

test('start answers at once with a request id; the job finishes it; the result route returns it', async () => {
	const s = setup();
	const started = await call(s.handler, {
		token: tokenFor('admin'),
		body: { images: [{ base64: PIECE, fileName: 'ht.png' }], expectedDate: '2026-10-22' }
	});
	assert.equal(started.status, 202);
	assert.equal(started.body.status, 'PENDING');
	const { requestId } = started.body;
	assert.match(requestId, /^[A-Za-z0-9_]+$/);

	// The job was submitted to the layout pool, for the job function, with the uploaded files.
	const submitted = s.catalyst.jobs[0];
	assert.equal(submitted.target_name, 'blujem_daily_job');
	assert.equal(submitted.jobpool_name, 'LayoutPool');
	assert.deepEqual(submitted.params, {
		requestId, fileIds: 'F1', sourceKeys: 'blujem-daily/2026/10/22/source-1.png', expectedDate: '2026-10-22'
	});

	// Until the job is done, the result is pending.
	const waiting = await call(s.handler, { token: tokenFor('admin'), route: 'process-daily-result', body: { requestId } });
	assert.equal(waiting.body.status, 'PENDING');

	assert.equal(await runSubmittedJob(s), 'success');
	assert.deepEqual(s.client.calls.runs[0].fileIds, ['F1']);

	const done = await call(s.handler, { token: tokenFor('admin'), route: 'process-daily-result', body: { requestId } });
	assert.equal(done.status, 200);
	assert.equal(done.body.status, 'RENDERED');
	assert.equal(done.body.extractionStatus, 'EXTRACTED');
	assert.equal(done.body.requestId, requestId);
	assert.deepEqual(done.body.extraction.words.map((w) => w.scrambled), ['NCWOR', 'RPEGU', 'ILEKFC', 'OPTRAS']);

	// Everything was stored in the day's folder, source included.
	assert.deepEqual(Object.keys(done.body.assets).sort(),
		['answer-strip.png', 'cartoon-original.png', 'collage-blank.png', 'collage-letters.png']);
	assert.equal(done.body.assets['collage-letters.png'], 'blujem-daily/2026/10/22/collage-letters.png');
	assert.deepEqual(done.body.sources, ['blujem-daily/2026/10/22/source-1.png']);
	assert.ok(s.catalyst.objects.has('blujem-daily/2026/10/22/puzzle.json'));

	// The admin's list finds it, and each image can be fetched.
	const list = await call(s.handler, { token: tokenFor('admin'), route: 'daily-list', body: {} });
	assert.equal(list.body.puzzles.length, 1);
	assert.equal(list.body.puzzles[0].status, 'RENDERED');
	const asset = await call(s.handler, {
		token: tokenFor('admin'), route: 'daily-asset', body: { key: done.body.assets['collage-letters.png'] }
	});
	assert.equal(Buffer.from(asset.body.base64, 'base64').toString(), 'letters');
});

test('only daily files can be fetched', async () => {
	const { handler } = setup();
	const outside = await call(handler, { token: tokenFor('admin'), route: 'daily-asset', body: { key: 'sheets/x.png' } });
	assert.equal(outside.status, 400);
	const climbing = await call(handler, { token: tokenFor('admin'), route: 'daily-asset', body: { key: 'blujem-daily/../sheets/x.png' } });
	assert.equal(climbing.status, 400);
});

test('a failed image check sends the day to review', async () => {
	const s = setup(goodReply(), false);
	const started = await call(s.handler, { token: tokenFor('admin'), body: { images: [{ base64: PIECE }], expectedDate: '2026-10-22' } });
	await runSubmittedJob(s);
	const done = await call(s.handler, { token: tokenFor('admin'), route: 'process-daily-result', body: { requestId: started.body.requestId } });
	assert.equal(done.body.status, 'NEEDS_REVIEW');
});

test('a stale puzzle is recorded but nothing is drawn', async () => {
	const s = setup(goodReply({ puzzleDate: '2026-10-21' }));
	const started = await call(s.handler, { token: tokenFor('admin'), body: { images: [{ base64: PIECE }], expectedDate: '2026-10-22' } });
	await runSubmittedJob(s);
	const done = await call(s.handler, { token: tokenFor('admin'), route: 'process-daily-result', body: { requestId: started.body.requestId } });
	assert.equal(done.body.status, 'STALE_SOURCE');
	assert.equal(done.body.assets, undefined);
	assert.ok(!s.catalyst.objects.has('blujem-daily/2026/10/22/collage-letters.png'));
});

test('three pieces are uploaded and sent to the job together', async () => {
	const s = setup();
	await call(s.handler, {
		token: tokenFor('admin'),
		body: { images: [{ base64: PIECE }, { base64: PIECE }, { base64: PIECE }], expectedDate: '2026-10-22' }
	});
	assert.equal(s.catalyst.jobs[0].params.fileIds, 'F1,F2,F3');
});

test('an agent failure in the job is kept as the result, with its code', async () => {
	const s = setup(new ZiaClientError('ZIA_TIMEOUT', 'No reply from Zia within 240000 ms.', {}));
	const started = await call(s.handler, { token: tokenFor('admin'), body: { images: [{ base64: PIECE }], expectedDate: '2026-10-22' } });
	await runSubmittedJob(s);
	const done = await call(s.handler, { token: tokenFor('admin'), route: 'process-daily-result', body: { requestId: started.body.requestId } });
	assert.equal(done.body.status, 'FAILED');
	assert.equal(done.body.error.code, 'ZIA_TIMEOUT');
});

test('an unknown or expired request is FAILED EXPIRED', async () => {
	const { handler } = setup();
	const reply = await call(handler, { token: tokenFor('admin'), route: 'process-daily-result', body: { requestId: 'nope' } });
	assert.equal(reply.body.status, 'FAILED');
	assert.equal(reply.body.error.code, 'EXPIRED');
	assert.equal((await call(handler, { token: tokenFor('admin'), route: 'process-daily-result', body: {} })).status, 400);
});

test('bad input is refused before anything is uploaded', async () => {
	const s = setup();
	const missing = await call(s.handler, { token: tokenFor('admin'), body: { expectedDate: '2026-10-22' } });
	assert.equal(missing.status, 400);
	assert.equal(missing.body.error.code, 'SOURCE_UNAVAILABLE');
	const four = await call(s.handler, { token: tokenFor('admin'), body: { images: [1, 2, 3, 4].map(() => ({ base64: PIECE })) } });
	assert.equal(four.body.error.code, 'TOO_MANY_IMAGES');
	assert.equal(s.client.calls.uploads.length, 0);
	assert.equal(s.catalyst.jobs.length, 0);
});

test('missing Zia settings are 503 ZIA_NOT_CONFIGURED', async () => {
	const catalyst = fakeCatalyst();
	const unconfigured = {
		uploadAll: async () => { throw new ZiaClientError('ZIA_NOT_CONFIGURED', 'Missing settings: ZIA_DAILY_AGENT_URL', {}); }
	};
	const handler = createHandler({ client: () => unconfigured, catalyst: () => catalyst.app });
	const reply = await call(handler, { token: tokenFor('admin'), body: { images: [{ base64: PIECE }], expectedDate: '2026-10-22' } });
	assert.equal(reply.status, 503);
	assert.equal(reply.body.error.code, 'ZIA_NOT_CONFIGURED');
});

test('the /api/blujem/process-daily-test path starts a request too', async () => {
	const s = setup();
	const reply = await call(s.handler, {
		token: tokenFor('admin'),
		path: '/api/blujem/process-daily-test',
		body: { images: [{ base64: PIECE }], expectedDate: '2026-10-22' }
	});
	assert.equal(reply.status, 202);
});
