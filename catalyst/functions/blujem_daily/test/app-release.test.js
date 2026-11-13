'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { Readable } = require('stream');
const { createHandler } = require('../index');
const { fakeCatalyst } = require('./fakes');

const SECRET = 'test-secret';
const b64url = (buf) => Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

function tokenFor(role) {
	const payload = b64url(JSON.stringify({ sub: '7', role, project: 'blujem', exp: Date.now() + 60000 }));
	return `${payload}.${b64url(crypto.createHmac('sha256', SECRET).update(payload).digest())}`;
}

function call(handler, route, body = {}, token) {
	const req = Readable.from([JSON.stringify(body)]);
	req.method = 'POST';
	req.url = `/server/blujem_daily/execute/${route}`;
	req.headers = { host: 'localhost', ...(token ? { 'x-jumble-token': token } : {}) };
	return new Promise((resolve) => {
		handler(req, {
			writeHead(status) { this.status = status; },
			end(data) { resolve({ status: this.status, body: data ? JSON.parse(data) : null }); }
		});
	});
}

function download(handler) {
	const req = { method: 'GET', url: '/server/blujem_daily/execute/download-apk', headers: { host: 'localhost' } };
	return new Promise((resolve) => {
		handler(req, {
			writeHead(status, headers) { this.status = status; this.headers = headers || {}; },
			end() { resolve({ status: this.status, headers: this.headers }); }
		});
	});
}

function setup() {
	const catalyst = fakeCatalyst();
	return { catalyst, handler: createHandler({ catalyst: () => catalyst.app, client: () => null }) };
}

const APK = Buffer.from('PK fake apk bytes');
const SHA = crypto.createHash('sha256').update(APK).digest('hex');

test.beforeEach(() => { process.env.JUMBLE_TOKEN_SECRET = SECRET; });

test('app-latest needs no sign-in and says 0 when nothing is published', async () => {
	const { handler } = setup();
	const res = await call(handler, 'app-latest');
	assert.equal(res.status, 200);
	assert.deepEqual(res.body, { versionCode: 0 });
	// With nothing out, the download button goes back to its page.
	assert.equal((await download(handler)).headers.Location, 'download');
});

test('upload and publish are for admins only', async () => {
	const { handler } = setup();
	const body = { versionCode: 16, versionName: '1.15' };
	assert.equal((await call(handler, 'app-upload-url', body)).status, 401);
	assert.equal((await call(handler, 'app-upload-url', body, tokenFor('player'))).status, 403);
	assert.equal((await call(handler, 'app-publish', body, tokenFor('player'))).status, 403);
});

test('a release is uploaded, published, and then offered with a signed link', async () => {
	const { handler, catalyst } = setup();
	const admin = tokenFor('admin');
	const up = await call(handler, 'app-upload-url', { versionCode: 16, versionName: '1.15' }, admin);
	assert.equal(up.status, 200);
	assert.equal(up.body.key, 'releases/android/BluJem-1.15.apk');
	assert.match(up.body.uploadUrl, /action=PUT/);

	// Publishing before the APK is there is refused.
	const early = await call(handler, 'app-publish', { versionCode: 16, versionName: '1.15', sha256: SHA, size: APK.length }, admin);
	assert.equal(early.status, 409);
	assert.equal(early.body.error.code, 'APK_MISSING');

	catalyst.objects.set(up.body.key, APK); // the PUT to the signed link
	const wrongSize = await call(handler, 'app-publish', { versionCode: 16, versionName: '1.15', sha256: SHA, size: 5 }, admin);
	assert.equal(wrongSize.body.error.code, 'APK_MISMATCH');

	const pub = await call(handler, 'app-publish', { versionCode: 16, versionName: '1.15', sha256: SHA, size: APK.length, notes: 'Centred cartoon' }, admin);
	assert.equal(pub.status, 200);
	assert.equal(pub.body.status, 'success');

	const latest = await call(handler, 'app-latest');
	assert.equal(latest.body.versionCode, 16);
	assert.equal(latest.body.versionName, '1.15');
	assert.equal(latest.body.notes, 'Centred cartoon');
	assert.equal(latest.body.sha256, SHA);
	assert.equal(latest.body.size, APK.length);
	assert.match(latest.body.apkUrl, /BluJem-1\.15\.apk\?action=GET/);

	// The download page's button sends the browser to the same file.
	const sent = await download(handler);
	assert.equal(sent.status, 302);
	assert.match(sent.headers.Location, /BluJem-1\.15\.apk\?action=GET/);

	// The same or an older version cannot replace it.
	const again = await call(handler, 'app-upload-url', { versionCode: 16, versionName: '1.15' }, admin);
	assert.equal(again.status, 409);
	assert.equal(again.body.error.code, 'NOT_NEWER');
});

test('bad versions and checksums are refused', async () => {
	const { handler } = setup();
	const admin = tokenFor('admin');
	for (const body of [{ versionCode: 0, versionName: '1.15' }, { versionCode: 16, versionName: '../x' }, { versionCode: 1.5, versionName: '1.15' }]) {
		const res = await call(handler, 'app-upload-url', body, admin);
		assert.equal(res.status, 400);
		assert.equal(res.body.error.code, 'BAD_VERSION');
	}
	const res = await call(handler, 'app-publish', { versionCode: 16, versionName: '1.15', sha256: 'abc', size: 3 }, admin);
	assert.equal(res.body.error.code, 'BAD_CHECKSUM');
});
