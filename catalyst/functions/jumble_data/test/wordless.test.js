'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { wordlessKey, isWordlessKey, cartoonKeysFor } = require('../lib/wordless');
const { wordlessSource } = require('../lib/gpt-upload');

test('the wordless picture sits beside its cartoon', () => {
	assert.equal(wordlessKey('puzzles/2026-11-22/morning/cartoon.png'), 'puzzles/2026-11-22/morning/cartoon-wordless.png');
	assert.equal(wordlessKey('sheets/abc-cartoon.jpg'), 'sheets/abc-cartoon-wordless.png');
	assert.equal(wordlessKey('drafts/2026-11-22/night/cartoon.jpg'), 'drafts/2026-11-22/night/cartoon-wordless.png');
	assert.equal(wordlessKey(''), '');
});

test('a wordless key leads back to the cartoons it can belong to', () => {
	const key = 'sheets/abc-cartoon-wordless.png';
	assert.ok(isWordlessKey(key));
	assert.ok(!isWordlessKey('sheets/abc-cartoon.jpg'));
	assert.ok(cartoonKeysFor(key).includes('sheets/abc-cartoon.jpg'));
	assert.ok(cartoonKeysFor('puzzles/d/s/cartoon-wordless.png').includes('puzzles/d/s/cartoon.png'));
});

test("ChatGPT's second picture is the wordless one", () => {
	const link = (n) => ({ download_link: `https://files.oaiusercontent.com/${n}` });
	assert.deepEqual(wordlessSource({ openaiFileIdRefs: [link('a')] }), {});
	assert.deepEqual(wordlessSource({ openaiFileIdRefs: [link('a'), link('b')] }), { url: 'https://files.oaiusercontent.com/b' });
	assert.match(wordlessSource({ openaiFileIdRefs: [link('a'), { download_link: 'https://evil.example/b' }] }).problem, /ChatGPT/);
	assert.deepEqual(wordlessSource({ wordlessBase64: 'AAAA' }), { base64: 'AAAA' });
});
