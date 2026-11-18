'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const { keyMatches, allowedImageUrl, cartoonSource, prepareDraft, draftPlace } = require('../lib/gpt-upload');

// The same cases the app's parser is tested with.
const cases = require(path.join(__dirname, '../../../../test/fixtures/puzzle_text_cases.json'));

test('the key must match exactly, and nothing is let in while it is unset', () => {
	assert.equal(keyMatches('secret-key', 'secret-key'), true);
	assert.equal(keyMatches('secret-kex', 'secret-key'), false);
	assert.equal(keyMatches('secret', 'secret-key'), false);
	assert.equal(keyMatches('', ''), false);
	assert.equal(keyMatches(undefined, undefined), false);
});

test('the cartoon is only fetched from ChatGPT file links over https', () => {
	assert.equal(allowedImageUrl('https://files.oaiusercontent.com/file-abc?se=1'), true);
	assert.equal(allowedImageUrl('https://sdmntprwestus.oaiusercontent.com/files/x'), true);
	assert.equal(allowedImageUrl('http://files.oaiusercontent.com/file-abc'), false);
	assert.equal(allowedImageUrl('https://evil.example.com/oaiusercontent.com'), false);
	assert.equal(allowedImageUrl('https://oaiusercontent.com.evil.example/x'), false);
	assert.equal(allowedImageUrl('not a url'), false);
});

test('the cartoon comes from the attached file, else base64', () => {
	assert.deepEqual(cartoonSource({ openaiFileIdRefs: [{ download_link: 'https://files.oaiusercontent.com/f' }] }), { url: 'https://files.oaiusercontent.com/f' });
	assert.deepEqual(cartoonSource({ cartoonBase64: 'iVBOR' }), { base64: 'iVBOR' });
	assert.ok(cartoonSource({ openaiFileIdRefs: [{ download_link: 'https://example.com/f.png' }] }).problem);
	assert.ok(cartoonSource({}).problem);
});

test('a draft needs its answers, and is never published', () => {
	const draft = {
		date: '2026-12-01',
		slot: 'evening',
		text: cases.valid[1].text,
		answers: { words: ['musty', 'nifty', 'swayed', 'decent'], final: 'admit tents fee' }
	};
	const ok = prepareDraft(draft);
	assert.deepEqual(ok.problems, []);
	assert.equal(ok.values.Published, 'false');
	assert.equal(ok.values.FinalAnswer, '"ADMIT-TENTS" FEE');
	assert.match(prepareDraft({ ...draft, answers: null }).problems[0], /answers/);
	assert.match(prepareDraft({ ...draft, answers: { ...draft.answers, final: 'admit tents fex' } }).problems[0], /circled letters/);
});

test('a draft never goes over a published puzzle, and replaces an earlier draft', () => {
	const date = '2030-01-07';
	assert.ok(draftPlace([{ Slot: 'evening', Published: 'true' }], date, 'evening').conflict);
	assert.deepEqual(draftPlace([{ Slot: 'morning', Published: 'true' }], date, 'evening'), { replace: null });
	const earlier = { Slot: 'evening', Published: false, ROWID: '1' };
	assert.equal(draftPlace([earlier], date, 'evening').replace, earlier);
});
