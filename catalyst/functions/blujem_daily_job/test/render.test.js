'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { renderAssets } = require('../render');
const L = require('../render/layout');

const fixture = (name) => path.join(__dirname, 'fixtures', name);
const reading = JSON.parse(fs.readFileSync(fixture('agent-result-2026-10-23.json'), 'utf8')).extraction;

test('today’s newspaper puzzle draws with every check passing', async () => {
	const out = await renderAssets({ extraction: reading, sources: [fs.readFileSync(fixture('ht-2026-10-23.jpg'))] });
	for (const c of out.checks) assert.ok(c.ok, `${c.code}: ${c.message}`);
	assert.equal(out.ok, true);
	assert.deepEqual(Object.keys(out.files).sort(),
		['answer-strip.png', 'cartoon-original.png', 'collage-blank.png', 'collage-letters.png']);
	for (const bytes of Object.values(out.files)) assert.equal(bytes[0], 0x89, 'a PNG');
	// The cartoon's own frame was found, and it is a tall panel as printed.
	assert.equal(out.cartoonCrop.frameFound, true);
	assert.ok(out.cartoonCrop.h > out.cartoonCrop.w);
	// The app is told where every square is.
	assert.deepEqual(out.layout.words.map((w) => w.length), [5, 5, 6, 6]);
	assert.deepEqual(out.layout.words[0].map((b) => b.circled), [false, true, false, true, false]);
	assert.equal(out.colorized, false);
});

/** The Sunday Jumble of 2026-11-01: six words of six letters, answered "□□□□□-□□□□□□□□□□". */
const sunday = {
	...reading,
	puzzleDate: '2026-11-01',
	words: [
		{ scrambled: 'EOLMPC', circledPositions: [2, 5, 6], boxCount: 6 },
		{ scrambled: 'IKIBNI', circledPositions: [2, 3], boxCount: 6 },
		{ scrambled: 'NCYOTO', circledPositions: [3, 4, 6], boxCount: 6 },
		{ scrambled: 'CCESNI', circledPositions: [2, 6], boxCount: 6 },
		{ scrambled: 'LOLFWO', circledPositions: [4, 6], boxCount: 6 },
		{ scrambled: 'ITREMP', circledPositions: [2, 3, 6], boxCount: 6 }
	],
	finalClue: 'WHEN HE THOUGHT BACK TO HIS DEMOLITION DERBY DAYS, IT WAS A ---',
	finalAnswer: { groups: [5, 10], prefix: '"', betweenGroups: ['-'], suffix: '"', punctuation: ['"', '-', '"'] },
	cartoon: { detected: true, sourceReference: 'right half', boundingBox: { x: 0.51, y: 0.02, w: 0.47, h: 0.96 } }
};

test('the Sunday Jumble draws all six rows under the header', async () => {
	const out = await renderAssets({
		extraction: sunday,
		sources: [fs.readFileSync(fixture('sunday-2026-11-01.jpg')), fs.readFileSync(fixture('sunday-2026-11-01-answer.jpg'))]
	});
	for (const c of out.checks) assert.ok(c.ok, `${c.code}: ${c.message}`);
	assert.deepEqual(out.layout.words.map((w) => w.length), [6, 6, 6, 6, 6, 6]);
	assert.deepEqual(out.layout.words[0].map((b) => b.circled), [false, true, false, false, true, true]);
	if (process.env.SAVE_RENDER) fs.writeFileSync(process.env.SAVE_RENDER, out.files['collage-letters.png']);

	const layout = L.collageLayout(sunday.words);
	assert.match(layout.instructions[1], /six ordinary words/);
	const tops = layout.rows.map((r) => r.tiles[0].y);
	for (let i = 1; i < tops.length; i++) assert.ok(tops[i] - tops[i - 1] >= layout.tileSize + 10, 'rows do not touch');
	assert.ok(tops[5] + layout.tileSize <= L.COLLAGE.rows.bottom, 'the last row ends on the sheet');
	assert.equal(new Set(layout.rows.map((r) => r.fill)).size, 6, 'six row colours');
});

test('four rows keep their weekday spacing', () => {
	const layout = L.collageLayout(reading.words);
	assert.equal(layout.rows[1].tiles[0].y - layout.rows[0].tiles[0].y, L.COLLAGE.rows.pitch);
	assert.equal(layout.tileSize, L.COLLAGE.tile.size);
	assert.match(layout.instructions[1], /four ordinary words/);
});

test('a colouring step, when given, replaces the cartoon and is recorded', async () => {
	let given = null;
	const out = await renderAssets({
		extraction: reading,
		sources: [fs.readFileSync(fixture('ht-2026-10-23.jpg'))],
		colorize: async (png) => { given = png; return png; }
	});
	assert.ok(given && given[0] === 0x89);
	assert.equal(out.colorized, true);
	assert.ok(out.files['cartoon-colorized.png']);
});

test('squares stay in the left half, centred, and shrink for a long word', () => {
	const layout = L.collageLayout([
		{ scrambled: 'ABCDE', circledPositions: [1] },
		{ scrambled: 'ABCDEFGH', circledPositions: [2] }
	]);
	for (const row of layout.rows) {
		const first = row.tiles[0];
		const last = row.tiles[row.tiles.length - 1];
		assert.ok(first.x >= L.COLLAGE.leftCentre - L.COLLAGE.leftWidth / 2 - 1);
		assert.ok(last.x + last.size <= L.COLLAGE.leftCentre + L.COLLAGE.leftWidth / 2 + 1);
		assert.ok(Math.abs((first.x + last.x + last.size) / 2 - L.COLLAGE.leftCentre) <= 1);
	}
	assert.ok(layout.tileSize < L.COLLAGE.tile.size);
});

const measure = (text, size) => text.length * size * 0.55;

test('a quoted phrase is kept together when the answer wraps', () => {
	// “□□□□ □” □□□□ — the quoted part stays on the first line.
	const strip = L.answerStripLayout(
		{ groups: [4, 1, 4], prefix: '“', betweenGroups: [' ', '” '], suffix: '' }, ['x'], measure);
	assert.equal(strip.lines, 2);
	const firstLineTop = strip.boxes[0].y;
	assert.deepEqual(strip.boxes.filter((b) => b.y === firstLineTop).map((b) => b.group), [0, 0, 0, 0, 1]);
	assert.deepEqual(strip.marks.map((m) => m.text), ['“', '”']);
});

test('without quotes, the answer wraps at the most even group boundary', () => {
	const strip = L.answerStripLayout(
		{ groups: [5, 2, 6], prefix: '', betweenGroups: [' ', ' '], suffix: '' }, ['x'], measure);
	assert.equal(strip.lines, 2);
	const firstLineTop = strip.boxes[0].y;
	// 5 + 2 over 6, as the admin's own answer image lays out RANGE OF TOPICS.
	assert.equal(strip.boxes.filter((b) => b.y === firstLineTop).length, 7);
	assert.equal(strip.tooWide, false);
});

test('a short answer stays on one line', () => {
	const strip = L.answerStripLayout({ groups: [4, 5], prefix: '', betweenGroups: [' '], suffix: '' }, ['x'], measure);
	assert.equal(strip.lines, 1);
});

test('the strip’s clue: the agent’s sentence case when it matches, plain sentence case otherwise', () => {
	assert.equal(
		L.stripClue('TO LEARN ABOUT THE ANDES, STUDY A ---', 'To learn about the Andes, study a ---'),
		'To learn about the Andes, study a —'
	);
	assert.equal(L.stripClue('AFTER ALL THE PASSENGERS LEFT, I SAW THE ---'), 'After all the passengers left, I saw the —');
	// A reworded sentence-case clue is ignored for the printed one.
	assert.equal(L.stripClue('THE SHIP WAS ---', 'The boat was ---'), 'The ship was —');
});
