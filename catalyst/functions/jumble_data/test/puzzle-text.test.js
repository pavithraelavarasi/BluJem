'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { parsePuzzleText, ungarbleBoxes } = require('../lib/puzzle-text');

// □ pasted into the iPhone simulator from a Mac arrives as ‚ñ° (its UTF-8
// bytes read as Mac Roman); from some Windows apps as â–¡.
const MAC = '‚ñ°';
const WIN = 'â–¡';

test('garbled boxes from a Mac or Windows paste turn back into boxes', () => {
	assert.equal(ungarbleBoxes(`${MAC}${MAC} ${WIN}`), '□□ □');
	assert.equal(ungarbleBoxes('aDRra'), 'aDRra');
});

test('a puzzle pasted with garbled boxes reads the same as with real ones', () => {
	const words = 'FiWE\nDUgYa\n\nWORsRo\nEMoonse\n';
	const garbled = parsePuzzleText(`${words}${MAC.repeat(3)} ${MAC.repeat(3)}, ${MAC.repeat(2)}\n${MAC.repeat(4)}`, 4);
	const clean = parsePuzzleText(`${words}□□□ □□□, □□\n□□□□`, 4);
	assert.deepEqual(garbled.pattern, clean.pattern);
	assert.equal(garbled.pattern.boxes, 12);
});
