'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { createJob } = require('../index');

/** blujem_daily/lib is the original; this job carries a copy that must match. */
test('lib/ is an exact copy of blujem_daily/lib (run npm run sync-job-lib there)', () => {
	const original = path.join(__dirname, '..', '..', 'blujem_daily', 'lib');
	const copy = path.join(__dirname, '..', 'lib');
	const names = fs.readdirSync(original).filter((n) => n.endsWith('.js')).sort();
	assert.deepEqual(fs.readdirSync(copy).filter((n) => n.endsWith('.js')).sort(), names);
	for (const name of names) {
		assert.equal(
			fs.readFileSync(path.join(copy, name), 'utf8'),
			fs.readFileSync(path.join(original, name), 'utf8'),
			`lib/${name} differs from blujem_daily/lib/${name}`
		);
	}
});

test('a job started without its images saves BAD_JOB_PARAMS and still closes', async () => {
	const saved = new Map();
	const app = { cache: () => ({ segment: () => ({ put: async (k, v) => saved.set(k, JSON.parse(v)) }) }) };
	const stored = [];
	const storage = { savePuzzle: async (_, date, record) => stored.push([date, record.status]) };
	const job = createJob({ client: () => { throw new Error('not called'); }, catalyst: () => app, storage });
	let closed;
	await job(
		{ getJobParam: (name) => ({ requestId: 'r1', fileIds: '', expectedDate: '2026-10-22' })[name] },
		{ closeWithSuccess: () => { closed = 'success'; }, closeWithFailure: () => { closed = 'failure'; } }
	);
	assert.equal(closed, 'success');
	assert.equal(saved.get('daily_r1').error.code, 'BAD_JOB_PARAMS');
	// The failure is kept as the day's record too.
	assert.deepEqual(stored, [['2026-10-22', 'FAILED']]);
});

test('a cache that cannot be written closes the job as failed', async () => {
	const app = { cache: () => ({ segment: () => ({ put: async () => { throw new Error('cache down'); } }) }) };
	const client = { run: async () => ({ json: {}, text: '{}' }) };
	const storage = { savePuzzle: async () => {} };
	const job = createJob({ client: () => client, catalyst: () => app, storage, render: async () => { throw new Error('x'); } });
	let closed;
	await job(
		{ getJobParam: (name) => ({ requestId: 'r2', fileIds: 'F1', expectedDate: '2026-10-22' })[name] },
		{ closeWithSuccess: () => { closed = 'success'; }, closeWithFailure: () => { closed = 'failure'; } }
	);
	assert.equal(closed, 'failure');
});
