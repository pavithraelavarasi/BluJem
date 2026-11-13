'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { PassThrough, Readable } = require('stream');
const PImage = require('pureimage');
const { createHandler } = require('../index');
const { isPrivateAddress } = require('../lib/store-daily-puzzle');
const { fakeCatalyst } = require('./fakes');

const SECRET = 'test-secret';
const INGEST_KEY = 'k'.repeat(40);
const b64url = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

function tokenFor(role) {
	const payload = b64url(JSON.stringify({ sub: '7', role, project: 'blujem', exp: Date.now() + 60000 }));
	return `${payload}.${b64url(crypto.createHmac('sha256', SECRET).update(payload).digest())}`;
}

async function encoded(kind) {
	const bitmap = PImage.make(4, 3);
	const out = new PassThrough();
	const chunks = [];
	out.on('data', (c) => chunks.push(c));
	await (kind === 'png' ? PImage.encodePNGToStream(bitmap, out) : PImage.encodeJPEGToStream(bitmap, out, 90));
	return Buffer.concat(chunks);
}

/** A fetch that serves [routes]: url → { status, body, headers } or an Error. */
function fakeFetch(routes) {
	const calls = [];
	const fn = async (url) => {
		calls.push(String(url));
		const route = routes[String(url)];
		if (!route) return { ok: false, status: 404, headers: new Headers(), body: Readable.from([]) };
		if (route instanceof Error) throw route;
		const status = route.status || 200;
		return { ok: status < 300, status, headers: new Headers(route.headers || {}), body: Readable.from(route.body ? [route.body] : []) };
	};
	fn.calls = calls;
	return fn;
}

function setup({ routes = {}, failPut = false } = {}) {
	const catalyst = fakeCatalyst();
	if (failPut) {
		const bucket = catalyst.app.stratus().bucket();
		catalyst.app.stratus = () => ({ bucket: () => ({ ...bucket, putObject: async () => { throw new Error('denied'); } }) });
	}
	const fetch = fakeFetch(routes);
	const lookup = async (host) => [{ address: host === 'internal.example' ? '10.0.0.5' : '93.184.216.34' }];
	const handler = createHandler({ catalyst: () => catalyst.app, client: () => null, store: { fetch, lookup } });
	return { catalyst, fetch, handler };
}

function call(handler, body, headers = { 'x-jumble-token': tokenFor('admin') }) {
	const req = Readable.from([JSON.stringify(body)]);
	req.method = 'POST';
	req.url = '/server/blujem_daily/store-daily-puzzle';
	req.headers = { host: 'localhost', ...headers };
	return new Promise((resolve) => {
		handler(req, {
			writeHead(status) { this.status = status; },
			end(data) { resolve({ status: this.status, body: data ? JSON.parse(data) : null }); }
		});
	});
}

test.beforeEach(() => {
	process.env.JUMBLE_TOKEN_SECRET = SECRET;
	process.env.BLUJEM_INGEST_KEY = INGEST_KEY;
});

test('no credentials is 401, a player is 403, a wrong ingest key is 401', async () => {
	const { handler, catalyst } = setup();
	const body = { puzzleDate: '2026-10-26', imageBase64: (await encoded('png')).toString('base64') };
	assert.equal((await call(handler, body, {})).status, 401);
	assert.equal((await call(handler, body, { 'x-jumble-token': tokenFor('player') })).status, 403);
	assert.equal((await call(handler, body, { 'x-blujem-ingest-key': 'k'.repeat(39) })).status, 401);
	assert.equal(catalyst.objects.size, 0);
});

test('a short BLUJEM_INGEST_KEY accepts nobody', async () => {
	process.env.BLUJEM_INGEST_KEY = 'short';
	const { handler } = setup();
	const res = await call(handler, { puzzleDate: '2026-10-26' }, { 'x-blujem-ingest-key': 'short' });
	assert.equal(res.status, 401);
});

test('uploaded bytes are stored at yyyy/MM/dd/source.png with puzzle.json beside them', async () => {
	const { handler, catalyst } = setup();
	const png = await encoded('png');
	const res = await call(handler, {
		puzzleDate: '2026-10-26',
		sourceUrl: 'https://example.com/jumble/2026-10-26',
		imageBase64: png.toString('base64'),
		metadata: { source: 'test', page: 12 }
	}, { 'x-blujem-ingest-key': INGEST_KEY });
	assert.equal(res.status, 200);
	assert.deepEqual(res.body, { status: 'success', imageKey: '2026/10/26/source.png', metadataKey: '2026/10/26/puzzle.json' });
	assert.deepEqual(catalyst.objects.get('2026/10/26/source.png'), png);
	const record = JSON.parse(catalyst.objects.get('2026/10/26/puzzle.json').toString('utf8'));
	assert.equal(record.puzzleDate, '2026-10-26');
	assert.equal(record.sourceUrl, 'https://example.com/jumble/2026-10-26');
	assert.deepEqual(record.metadata, { source: 'test', page: 12 });
	assert.equal(record.image.width, 4);
	assert.equal(record.image.originalFormat, 'png');
	assert.equal(record.storedBy, 'ingest-key');
});

test('an imageUrl is downloaded server-side, following a redirect; a JPEG becomes PNG', async () => {
	const jpeg = await encoded('jpeg');
	const { handler, catalyst, fetch } = setup({
		routes: {
			'https://cdn.example.com/a.jpg': { status: 302, headers: { location: '/b.jpg' } },
			'https://cdn.example.com/b.jpg': { body: jpeg }
		}
	});
	const res = await call(handler, { puzzleDate: '2026-10-25', imageUrl: 'https://cdn.example.com/a.jpg' });
	assert.equal(res.status, 200);
	assert.deepEqual(fetch.calls, ['https://cdn.example.com/a.jpg', 'https://cdn.example.com/b.jpg']);
	const stored = catalyst.objects.get('2026/10/25/source.png');
	assert.equal(stored[0], 0x89);
	const record = JSON.parse(catalyst.objects.get('2026/10/25/puzzle.json'));
	assert.equal(record.image.originalFormat, 'jpeg');
	assert.equal(record.storedBy, 'admin:7');
});

test('bad requests are refused before anything is fetched or stored', async () => {
	const { handler, catalyst, fetch } = setup();
	const png = (await encoded('png')).toString('base64');
	const cases = [
		[{ puzzleDate: '2026-02-30', imageBase64: png }, 400, 'BAD_PUZZLE_DATE'],
		[{ puzzleDate: '26-10-2026', imageBase64: png }, 400, 'BAD_PUZZLE_DATE'],
		[{ puzzleDate: '2099-01-01', imageBase64: png }, 400, 'BAD_PUZZLE_DATE'],
		[{ puzzleDate: '2026-10-26' }, 400, 'MISSING_IMAGE'],
		[{ puzzleDate: '2026-10-26', imageBase64: png, imageUrl: 'https://a.example/x.png' }, 400, 'MISSING_IMAGE'],
		[{ puzzleDate: '2026-10-26', imageUrl: 'ftp://a.example/x.png' }, 400, 'INVALID_URL'],
		[{ puzzleDate: '2026-10-26', imageUrl: 'not a url' }, 400, 'INVALID_URL'],
		[{ puzzleDate: '2026-10-26', imageUrl: 'http://127.0.0.1/x.png' }, 400, 'INVALID_URL'],
		[{ puzzleDate: '2026-10-26', imageUrl: 'http://internal.example/x.png' }, 400, 'INVALID_URL'],
		[{ puzzleDate: '2026-10-26', imageBase64: png, sourceUrl: 'javascript:alert(1)' }, 400, 'INVALID_URL'],
		[{ puzzleDate: '2026-10-26', imageBase64: png, metadata: [1] }, 400, 'BAD_METADATA'],
		[{ puzzleDate: '2026-10-26', imageBase64: Buffer.from('GIF89a....').toString('base64') }, 400, 'NOT_AN_IMAGE']
	];
	for (const [body, status, code] of cases) {
		const res = await call(handler, body);
		assert.equal(res.status, status, JSON.stringify(body).slice(0, 80));
		assert.equal(res.body.status, 'error');
		assert.equal(res.body.error.code, code, JSON.stringify(body).slice(0, 80));
	}
	assert.equal(fetch.calls.length, 0);
	assert.equal(catalyst.objects.size, 0);
});

test('a failed download is 502 DOWNLOAD_FAILED', async () => {
	const { handler, catalyst } = setup({
		routes: { 'https://cdn.example.com/gone.png': { status: 404 }, 'https://cdn.example.com/err.png': new Error('reset') }
	});
	for (const url of ['https://cdn.example.com/gone.png', 'https://cdn.example.com/err.png']) {
		const res = await call(handler, { puzzleDate: '2026-10-26', imageUrl: url });
		assert.equal(res.status, 502);
		assert.equal(res.body.error.code, 'DOWNLOAD_FAILED');
	}
	assert.equal(catalyst.objects.size, 0);
});

test('a redirect to a private address is refused', async () => {
	const { handler } = setup({
		routes: { 'https://cdn.example.com/a.png': { status: 301, headers: { location: 'http://169.254.169.254/latest' } } }
	});
	const res = await call(handler, { puzzleDate: '2026-10-26', imageUrl: 'https://cdn.example.com/a.png' });
	assert.equal(res.body.error.code, 'INVALID_URL');
});

test('a Stratus failure is 502 STRATUS_UPLOAD_FAILED', async () => {
	const { handler } = setup({ failPut: true });
	const res = await call(handler, { puzzleDate: '2026-10-26', imageBase64: (await encoded('png')).toString('base64') });
	assert.equal(res.status, 502);
	assert.equal(res.body.error.code, 'STRATUS_UPLOAD_FAILED');
});

test('private and public addresses', () => {
	for (const a of ['127.0.0.1', '10.1.2.3', '172.20.0.1', '192.168.1.1', '169.254.169.254', '::1', 'fd00::1', '::ffff:10.0.0.1']) {
		assert.equal(isPrivateAddress(a), true, a);
	}
	for (const a of ['93.184.216.34', '8.8.8.8', '2606:4700::1111']) assert.equal(isPrivateAddress(a), false, a);
});
