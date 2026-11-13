'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { openingTime, publishAt, isTimedOpening } = require('../lib/slots');
const { announceOnPublish, dueAtTimer, messageFor, serviceAccount } = require('../lib/notify');

// India time on Tuesday 1 December 2026, as epoch ms.
const ist = (hhmm) => Date.parse(`2026-12-01T${hhmm}:00+05:30`);
const words = JSON.stringify([{ scrambled: 'YTSUM', answer: 'MUSTY' }]);
const puzzle = (fields) => ({ PuzzleId: 'p', PublishDate: '2026-12-01', Published: 'true', Words: words, FinalAnswer: 'MY', ...fields });

// ------------------------------------------------------------------ opening times

test('a morning puzzle published after 9:00 opens at once', () => {
	const now = ist('09:12') + 345;
	assert.equal(openingTime('2026-12-01', 'morning', now), now);
	assert.equal(isTimedOpening(openingTime('2026-12-01', 'morning', now)), false);
});

test('one published before 9:00, or for a later day, waits for 9:00 (Sunday 6:00)', () => {
	assert.equal(openingTime('2026-12-01', 'morning', ist('07:10')), ist('09:00'));
	assert.equal(openingTime('2026-12-02', 'morning', ist('20:00')), Date.parse('2026-12-02T09:00:00+05:30'));
	assert.equal(openingTime('2026-12-06', 'sunday', ist('20:00')), Date.parse('2026-12-06T06:00:00+05:30'));
});

test('the afternoon puzzle always opens at 15:00, the night one at 21:00', () => {
	assert.equal(openingTime('2026-12-01', 'evening', ist('09:00')), ist('15:00'));
	assert.equal(openingTime('2026-12-01', 'evening', ist('17:30')), ist('15:00'));
	assert.equal(openingTime('2026-12-01', 'night', ist('10:00')), ist('21:00'));
	assert.equal(openingTime('2026-12-01', 'night', ist('22:00')), ist('21:00'));
});

test('a publish that lands exactly on a minute is nudged off it', () => {
	assert.equal(openingTime('2026-12-01', 'morning', ist('10:00')), ist('10:00') + 1);
});

test('fixing a puzzle that is already out keeps the time it went out', () => {
	const out = puzzle({ Slot: 'morning', PublishAt: ist('08:30') + 7 });
	assert.equal(openingTime('2026-12-01', 'morning', ist('11:00'), out), ist('08:30') + 7);
	// An unpublished draft is not "out": publishing it opens it now.
	const draft = { ...out, Published: 'false' };
	assert.equal(openingTime('2026-12-01', 'morning', ist('11:00') + 5, draft), ist('11:00') + 5);
});

// ------------------------------------------------------------------ when to announce

test('publishing a morning puzzle that opens now announces it', () => {
	const now = ist('09:12') + 3;
	const row = puzzle({ Slot: 'morning', PublishAt: now });
	assert.equal(announceOnPublish(row, null, now), true);
});

test('publishing one that is not out yet leaves it to the timer', () => {
	const now = ist('11:00') + 3;
	assert.equal(announceOnPublish(puzzle({ Slot: 'evening', PublishAt: ist('16:00') }), null, now), false);
	assert.equal(announceOnPublish(puzzle({ Slot: 'morning', PublishDate: '2026-12-02', PublishAt: Date.parse('2026-12-02T06:00:00+05:30') }), null, now), false);
});

test('an evening puzzle published after 16:00 is announced on publishing', () => {
	const now = ist('16:20') + 3;
	assert.equal(announceOnPublish(puzzle({ Slot: 'evening', PublishAt: ist('16:00') }), null, now), true);
});

test('fixing or replacing a puzzle players already have is not announced again', () => {
	const now = ist('10:00') + 3;
	const out = puzzle({ Slot: 'morning', PublishAt: ist('08:30') + 7 });
	assert.equal(announceOnPublish({ ...out }, out, now), false);
	assert.equal(announceOnPublish(puzzle({ PuzzleId: 'q', Slot: 'morning', PublishAt: now }), out, now), false);
});

test('a puzzle without its answers is never announced', () => {
	const now = ist('09:00') + 3;
	assert.equal(announceOnPublish(puzzle({ Slot: 'morning', PublishAt: now, FinalAnswer: '' }), null, now), false);
	assert.equal(announceOnPublish(puzzle({ Slot: 'morning', PublishAt: now, Published: 'false' }), null, now), false);
});

test('the timer announces what opened on the hour, and nothing published by hand', () => {
	const evening = puzzle({ PuzzleId: 'e', Slot: 'evening', PublishAt: ist('16:00') });
	const morning = puzzle({ PuzzleId: 'm', Slot: 'morning', PublishAt: ist('09:12') + 3 });
	const early = puzzle({ PuzzleId: 'x', Slot: 'morning', PublishAt: ist('06:00') });
	assert.deepEqual(dueAtTimer([evening, morning], ist('16:00') + 900).map((r) => r.PuzzleId), ['e']);
	assert.deepEqual(dueAtTimer([early, evening], ist('06:01')).map((r) => r.PuzzleId), ['x']);
	// Before its time, or long after, the timer leaves it alone.
	assert.deepEqual(dueAtTimer([evening], ist('15:59')), []);
	assert.deepEqual(dueAtTimer([evening], ist('17:00')), []);
});

test('the messages name the slot', () => {
	assert.equal(messageFor(puzzle({ Slot: 'morning' })).title, "This morning's BluJem is out");
	assert.equal(messageFor(puzzle({ Slot: 'evening' })).title, "This afternoon's BluJem is out");
	assert.equal(messageFor(puzzle({ Slot: 'night' })).title, "Tonight's BluJem is out");
	assert.equal(messageFor(puzzle({ Slot: 'sunday', PublishDate: '2026-12-06' })).title, "Sunday's Mega Jumble is out");
});

test('the service account is read as JSON or base64, and refused when incomplete', () => {
	const { privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 1024 });
	const key = { project_id: 'blujem', client_email: 'push@blujem.iam.gserviceaccount.com', private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }) };
	assert.equal(serviceAccount({ FCM_SERVICE_ACCOUNT: JSON.stringify(key) }).project_id, 'blujem');
	assert.equal(serviceAccount({ FCM_SERVICE_ACCOUNT: Buffer.from(JSON.stringify(key)).toString('base64') }).project_id, 'blujem');
	assert.equal(serviceAccount({}), null);
	assert.equal(serviceAccount({ FCM_SERVICE_ACCOUNT: '{"project_id":"x"}' }), null);
});

test('publishAt stays the earliest opening for every slot', () => {
	assert.equal(publishAt('2026-12-01', 'morning'), ist('09:00'));
	assert.equal(publishAt('2026-12-01', 'evening'), ist('15:00'));
	assert.equal(publishAt('2026-12-01', 'night'), ist('21:00'));
	assert.equal(publishAt('2026-12-06', 'sunday'), Date.parse('2026-12-06T06:00:00+05:30'));
});
