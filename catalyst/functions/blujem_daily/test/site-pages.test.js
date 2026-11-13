'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createHandler } = require('../index');

function get(route, method = 'GET') {
	const handler = createHandler({ catalyst: () => null, client: () => null });
	const req = { method, url: `/server/blujem_daily/${route}`, headers: { host: 'localhost' }, body: {} };
	return new Promise((resolve) => {
		handler(req, {
			writeHead(status, headers) { this.status = status; this.headers = headers || {}; },
			end(data) { resolve({ status: this.status, headers: this.headers, body: data || '' }); }
		});
	});
}

test('the home page and privacy policy are public HTML', async () => {
	for (const route of ['home', 'privacy', 'download']) {
		const res = await get(route);
		assert.equal(res.status, 200);
		assert.match(res.headers['Content-Type'], /^text\/html/);
		assert.match(res.body, /<title>[^<]*BluJem/);
	}
	assert.match((await get('privacy')).body, /delete your account/);
});

test('other GETs are still refused', async () => {
	assert.equal((await get('app-latest')).status, 405);
	assert.equal((await get('constructor')).status, 405);
});

test('the download page leads to a fresh link to the latest APK', async () => {
	assert.match((await get('download')).body, /href="download-apk"/);
});
