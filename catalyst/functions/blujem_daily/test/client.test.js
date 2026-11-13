'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { ZiaDailyPuzzleClient, jsonIn } = require('../lib/zia-daily-puzzle-client');
const { processDaily } = require('../lib/process-daily');
const { goodReply } = require('./fixtures');

const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);
const settings = {
	triggerUrl: 'https://agents.example/trigger',
	agentBase: 'https://ziaagents.example',
	accounts: 'https://accounts.example',
	orgId: 'ORG1',
	clientId: 'cid', clientSecret: 'csecret', refreshToken: 'rtoken'
};
const json = (status, body) => ({ ok: status < 400, status, json: async () => body });

/** A fake fetch that answers the three calls in order and records them. */
function fakeZia({ agentText, triggerStatus = 200, uploadStatus = 200 }) {
	const calls = [];
	const fetchImpl = async (url, init) => {
		calls.push({ url: String(url), init });
		if (String(url).startsWith('https://accounts.example/oauth/v2/token')) {
			return json(200, { access_token: 'tok', expires_in: 3600 });
		}
		if (String(url) === 'https://ziaagents.example/ziaagents/api/v1/files') {
			return json(uploadStatus, uploadStatus === 200 ? { data: { fileId: 'F42' } } : {});
		}
		if (String(url) === 'https://agents.example/trigger') {
			return json(triggerStatus, triggerStatus === 200 ? { data: { response: agentText } } : { error: 'x' });
		}
		throw new Error(`unexpected ${url}`);
	};
	return { calls, fetchImpl };
}

test('extract follows jumble_ai’s contract: token, upload, trigger with the file attached', async () => {
	const zia = fakeZia({ agentText: '```json\n' + JSON.stringify(goodReply()) + '\n```' });
	const client = new ZiaDailyPuzzleClient({ ...settings, fetchImpl: zia.fetchImpl });
	const { json: reply } = await client.extract({ images: [{ data: PNG }], expectedDate: '2026-10-22' });

	assert.equal(reply.words[0].scrambled, 'NCWOR');
	assert.equal(zia.calls.length, 3);

	const upload = zia.calls[1].init;
	assert.equal(upload.headers.Authorization, 'Zoho-oauthtoken tok');
	assert.equal(upload.headers['X-ZIAAGENTS-ORG'], 'ORG1');
	assert.ok(upload.body instanceof FormData);
	assert.equal(upload.body.get('file').type, 'image/png');

	const trigger = zia.calls[2].init;
	assert.equal(trigger.headers.Authorization, 'Zoho-oauthtoken tok');
	const sent = JSON.parse(trigger.body);
	assert.deepEqual(sent.attachments, ['F42']);
	assert.match(sent.query, /Expected date \(Asia\/Kolkata\): 2026-10-22/);
});

test('missing settings fail clearly, naming them, before any call', async () => {
	const zia = fakeZia({ agentText: '{}' });
	const client = new ZiaDailyPuzzleClient({ fetchImpl: zia.fetchImpl });
	const result = await processDaily({ image: PNG, expectedDate: '2026-10-22', client });
	assert.equal(result.status, 'FAILED');
	assert.equal(result.error.code, 'ZIA_NOT_CONFIGURED');
	assert.deepEqual(result.error.details.missing, [
		'ZIA_DAILY_AGENT_URL', 'ZIA_AGENT_CLIENT_ID', 'ZIA_AGENT_CLIENT_SECRET', 'ZIA_AGENT_REFRESH_TOKEN'
	]);
	assert.equal(zia.calls.length, 0);
});

test('an agent that refuses the call is ZIA_UNAUTHORIZED', async () => {
	const zia = fakeZia({ agentText: '{}', triggerStatus: 401 });
	const client = new ZiaDailyPuzzleClient({ ...settings, fetchImpl: zia.fetchImpl });
	const result = await processDaily({ image: PNG, expectedDate: '2026-10-22', client });
	assert.equal(result.error.code, 'ZIA_UNAUTHORIZED');
});

test('a failed upload is ZIA_UPLOAD_FAILED', async () => {
	const zia = fakeZia({ agentText: '{}', uploadStatus: 500 });
	const client = new ZiaDailyPuzzleClient({ ...settings, fetchImpl: zia.fetchImpl });
	const result = await processDaily({ image: PNG, expectedDate: '2026-10-22', client });
	assert.equal(result.error.code, 'ZIA_UPLOAD_FAILED');
});

test('an agent that answers in prose is INVALID_JSON', async () => {
	const zia = fakeZia({ agentText: 'The words are NCWOR, RPEGU…' });
	const client = new ZiaDailyPuzzleClient({ ...settings, fetchImpl: zia.fetchImpl });
	const result = await processDaily({ image: PNG, expectedDate: '2026-10-22', client });
	assert.equal(result.error.code, 'INVALID_JSON');
});

test('an agent that takes too long is ZIA_TIMEOUT', async () => {
	const fetchImpl = (url, init) => new Promise((resolve, reject) => {
		init.signal.addEventListener('abort', () => {
			const error = new Error('aborted');
			error.name = 'AbortError';
			reject(error);
		});
	});
	const client = new ZiaDailyPuzzleClient({ ...settings, timeoutMs: 30, fetchImpl });
	const result = await processDaily({ image: PNG, expectedDate: '2026-10-22', client });
	assert.equal(result.error.code, 'ZIA_TIMEOUT');
});

test('no image is SOURCE_UNAVAILABLE; a bad date is refused', async () => {
	const client = new ZiaDailyPuzzleClient(settings);
	assert.equal((await processDaily({ image: Buffer.alloc(0), expectedDate: '2026-10-22', client })).error.code, 'SOURCE_UNAVAILABLE');
	assert.equal((await processDaily({ image: PNG, expectedDate: '22-10-2026', client })).error.code, 'BAD_EXPECTED_DATE');
});

test('a good reply runs end to end to EXTRACTED; the expected day defaults to India’s', async () => {
	const zia = fakeZia({ agentText: JSON.stringify(goodReply()) });
	const client = new ZiaDailyPuzzleClient({ ...settings, fetchImpl: zia.fetchImpl });
	// 21:00 UTC on the 21st is already the 22nd in India.
	const result = await processDaily({ image: PNG, client, now: new Date('2026-10-21T21:00:00Z') });
	assert.equal(result.expectedDate, '2026-10-22');
	assert.equal(result.status, 'EXTRACTED');
	assert.equal(result.extraction.finalAnswer.groups.join('+'), '5+2+6');
});

test('the three pieces of a puzzle go to the agent in one call', async () => {
	const zia = fakeZia({ agentText: JSON.stringify(goodReply()) });
	let uploads = 0;
	const fetchImpl = async (url, init) => {
		if (String(url).endsWith('/ziaagents/api/v1/files')) {
			uploads++;
			zia.calls.push({ url: String(url), init });
			return json(200, { data: { fileId: `F${uploads}` } });
		}
		return zia.fetchImpl(url, init);
	};
	const client = new ZiaDailyPuzzleClient({ ...settings, fetchImpl });
	const result = await processDaily({
		images: [{ data: PNG, fileName: 'words.png' }, { data: PNG, fileName: 'cartoon.png' }, { data: PNG, fileName: 'answer.png' }],
		expectedDate: '2026-10-22',
		client
	});
	assert.equal(result.status, 'EXTRACTED');
	const trigger = JSON.parse(zia.calls.find((c) => c.url === 'https://agents.example/trigger').init.body);
	assert.deepEqual(trigger.attachments, ['F1', 'F2', 'F3']);
	assert.match(trigger.query, /3 attached images/);
});

test('more than three images is TOO_MANY_IMAGES', async () => {
	const client = new ZiaDailyPuzzleClient(settings);
	const four = [1, 2, 3, 4].map(() => ({ data: PNG }));
	const result = await processDaily({ images: four, expectedDate: '2026-10-22', client });
	assert.equal(result.error.code, 'TOO_MANY_IMAGES');
});

test('settings pasted with stray spaces are trimmed', () => {
	const client = ZiaDailyPuzzleClient.fromEnv({
		ZIA_DAILY_AGENT_URL: ' https://agents.example/trigger ',
		ZIA_AGENT_CLIENT_ID: 'cid\n',
		ZIA_AGENT_CLIENT_SECRET: ' s ',
		ZIA_AGENT_REFRESH_TOKEN: 'r'
	});
	assert.equal(client.triggerUrl, 'https://agents.example/trigger');
	assert.equal(client.clientId, 'cid');
	assert.equal(client.clientSecret, 's');
});

test('jsonIn mends a bare quotation mark written as a whole string', () => {
	// What the agent sent for the 23 October puzzle.
	const reply = '{ "finalAnswer": { "groups": [4, 1, 4], "prefix": """, "betweenGroups": [" ", " "], ' +
		'"suffix": "", "punctuation": [""", """] } }';
	const parsed = jsonIn(reply);
	assert.equal(parsed.finalAnswer.prefix, '"');
	assert.deepEqual(parsed.finalAnswer.punctuation, ['"', '"']);
	// Valid JSON is never changed.
	assert.deepEqual(jsonIn('{"a":"x\\"y"}'), { a: 'x"y' });
});

test('jsonIn reads JSON inside code fences and refuses prose', () => {
	assert.deepEqual(jsonIn('Here:\n```json\n{"a":1}\n```'), { a: 1 });
	assert.equal(jsonIn('no json here'), null);
});
