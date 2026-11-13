'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const { parsePuzzleText, checkAnswers, fillPattern, patternOf } = require('../lib/puzzle-text');
const { slotProblem, publishAt, slotsFor, releaseTime, isReleased, indiaDate } = require('../lib/slots');
const { playerView, answerHash, isComplete, answersOf } = require('../lib/puzzle-views');
const { prepareUpload, imageType } = require('../lib/upload');

// The same cases the app's parser is tested with.
const cases = require(path.join(__dirname, '../../../../test/fixtures/puzzle_text_cases.json'));

// ------------------------------------------------------------------ parser

for (const c of cases.valid) {
	test(`reads: ${c.name}`, () => {
		const p = parsePuzzleText(c.text, c.words);
		assert.deepEqual(p.words.map((w) => w.letters), c.scrambles);
		assert.deepEqual(p.words.map((w) => w.circled), c.circled);
		assert.equal(p.pattern.text, c.pattern);
		assert.equal(p.pattern.boxes, c.boxes);
		assert.deepEqual(p.pattern.groups, c.groups);
		assert.deepEqual(p.pattern.lines, c.lines);
	});
}

for (const c of cases.invalid) {
	test(`refuses: ${c.name}`, () => {
		assert.throws(() => parsePuzzleText(c.text, c.words), (e) => e.message.includes(c.error));
	});
}

test('a caption line is kept as the clue', () => {
	const p = parsePuzzleText('aDRra\ntuYpT\nhcNRcu\ncRaoCD\nWhat the farmer said —\n□□□-□□□-\n□□□', 4);
	assert.equal(p.clue, 'What the farmer said —');
});

const nov6 = parsePuzzleText(cases.valid[1].text, 4);

test('answers that fit are accepted', () => {
	assert.deepEqual(checkAnswers(nov6, { words: ['musty', 'nifty', 'swayed', 'decent'], final: 'ADMIT-TENTS FEE' }), []);
});

test('a word not made of its jumble is refused', () => {
	const problems = checkAnswers(nov6, { words: ['MUSTY', 'NIFTY', 'SWAYED', 'DECANT'], final: 'ADMIT-TENTS FEE' });
	assert.match(problems[0], /Word 4/);
});

test('a final answer with other letters, or other word lengths, is refused', () => {
	const words = ['MUSTY', 'NIFTY', 'SWAYED', 'DECENT'];
	assert.match(checkAnswers(nov6, { words, final: 'ADMIT-TENTS FEX' })[0], /circled letters/);
	assert.match(checkAnswers(nov6, { words, final: 'ADMITTENTS FEE' })[0], /do not match the boxes/);
});

test('the pattern is filled in order and punctuation stays', () => {
	assert.equal(fillPattern(nov6.pattern.text, 'ADMITTENTSFEE'), '"ADMIT-\nTENTS" FEE');
	assert.equal(patternOf('"CREW\'S" SHIP'), '"□□□□\'□" □□□□');
});

// ------------------------------------------------------------------ slots (IST)

test('the morning opens no earlier than 9:00, the afternoon at 15:00, the night at 21:00, India time', () => {
	assert.equal(new Date(publishAt('2026-12-01', 'morning')).toISOString(), '2026-12-01T03:30:00.000Z');
	assert.equal(new Date(publishAt('2026-12-01', 'evening')).toISOString(), '2026-12-01T09:30:00.000Z');
	assert.equal(new Date(publishAt('2026-12-01', 'night')).toISOString(), '2026-12-01T15:30:00.000Z');
});

test('Sunday has one slot, opening no earlier than 6:00, and no other', () => {
	assert.deepEqual(slotsFor('2026-12-06'), ['sunday']);
	assert.deepEqual(slotsFor('2026-12-05'), ['morning', 'evening', 'night']);
	assert.equal(new Date(publishAt('2026-12-06', 'sunday')).toISOString(), '2026-12-06T00:30:00.000Z');
	assert.match(slotProblem('2026-12-06', 'morning'), /Sunday/);
	assert.match(slotProblem('2026-12-05', 'sunday'), /not a Sunday/);
	assert.equal(slotProblem('2026-12-05', 'evening'), null);
	assert.match(slotProblem('2026-02-30', 'morning'), /real date/);
});

test('India\'s date turns at its own midnight, not UTC\'s', () => {
	assert.equal(indiaDate(Date.parse('2026-12-01T18:29:00Z')), '2026-12-01');
	assert.equal(indiaDate(Date.parse('2026-12-01T18:30:00Z')), '2026-12-02');
});

test('a puzzle is hidden until its time, to the second', () => {
	const row = { PublishDate: '2026-12-01', Slot: 'evening', PublishAt: publishAt('2026-12-01', 'evening') };
	assert.equal(isReleased(row, Date.parse('2026-12-01T09:29:59Z')), false);
	assert.equal(isReleased(row, Date.parse('2026-12-01T09:30:00Z')), true);
});

test('an older row without a slot counts as its day\'s first slot', () => {
	assert.equal(releaseTime({ PublishDate: '2026-11-06' }), publishAt('2026-11-06', 'morning'));
	assert.equal(releaseTime({ PublishDate: '2026-11-08' }), publishAt('2026-11-08', 'sunday'));
	assert.equal(releaseTime({ PublishDate: 'soon' }), Infinity);
});

// ------------------------------------------------------------------ what players get

const row = {
	PuzzleId: 'p1',
	PublishDate: '2026-11-06',
	Published: 'true',
	FinalAnswer: '"ADMIT-TENTS" FEE',
	FinalExplanation: 'A pun.',
	Words: JSON.stringify([
		{ scrambled: 'YMSTU', answer: 'MUSTY', boxes: [{ x: 0, y: 0, w: 0, h: 0, c: true }] },
		{ scrambled: 'YFNTI', answer: 'NIFTY', boxes: [] }
	])
};

test('players get hashes, never the answers or the explanation', () => {
	const view = playerView(row);
	const text = JSON.stringify(view);
	for (const secret of ['MUSTY', 'NIFTY', 'ADMIT', 'TENTS', 'A pun']) assert.ok(!text.includes(secret), secret);
	const words = JSON.parse(view.words);
	assert.equal(words[0].answerHash, answerHash('p1', 'MUSTY'));
	assert.deepEqual(words[0].boxes, [{ x: 0, y: 0, w: 0, h: 0, c: true }]);
	assert.equal(view.finalHash, answerHash('p1', 'ADMITTENTSFEE', 'final:'));
	assert.equal(view.finalPattern, '"□□□□□-□□□□□" □□□');
});

test('the hash is of the letters alone, so the app can match it', () => {
	assert.equal(answerHash('p1', 'musty'), answerHash('p1', 'MUSTY'));
	assert.equal(answerHash('p1', 'MUSTY').length, 64);
});

test('a puzzle missing any answer is not offered', () => {
	assert.equal(isComplete(row), true);
	assert.equal(isComplete({ ...row, FinalAnswer: '' }), false);
	assert.equal(isComplete({ ...row, Words: JSON.stringify([{ scrambled: 'AB', answer: '' }]) }), false);
	assert.deepEqual(answersOf(row).words, ['MUSTY', 'NIFTY']);
});

// ------------------------------------------------------------------ upload

const upload = {
	date: '2026-12-01',
	slot: 'evening',
	text: cases.valid[1].text,
	answers: { words: ['musty', 'nifty', 'swayed', 'decent'], final: 'admit tents fee' }
};

test('an upload becomes one row for its date and slot, live at the slot\'s time', () => {
	const { problems, values } = prepareUpload(upload);
	assert.deepEqual(problems, []);
	assert.equal(values.Slot, 'evening');
	assert.equal(values.PublishAt, publishAt('2026-12-01', 'evening'));
	assert.equal(values.Published, 'true');
	// The answer is printed with the boxes' punctuation, whatever was typed.
	assert.equal(values.FinalAnswer, '"ADMIT-TENTS" FEE');
	assert.equal(values.FinalPattern, '"□□□□□-\n□□□□□" □□□');
	const words = JSON.parse(values.Words);
	assert.equal(words[0].answer, 'MUSTY');
	assert.deepEqual(words[0].boxes.map((b) => Boolean(b.c)), [true, false, true, true, false]);
	assert.equal(JSON.parse(values.FinalBoxes).length, 13);
});

test('without answers it is stored but not published', () => {
	const { problems, values, warnings } = prepareUpload({ ...upload, answers: null });
	assert.deepEqual(problems, []);
	assert.equal(values.Published, 'false');
	assert.match(warnings[0], /not published/);
});

test('a Sunday upload needs six words and the sunday slot', () => {
	assert.match(prepareUpload({ ...upload, date: '2026-12-06' }).problems[0], /Sunday/);
	assert.match(prepareUpload({ ...upload, date: '2026-12-06', slot: 'sunday' }).problems[0], /6 words/);
	const sunday = prepareUpload({ date: '2026-12-06', slot: 'sunday', text: cases.valid[2].text });
	assert.deepEqual(sunday.problems, []);
	assert.equal(sunday.values.Difficulty, 'Mega');
});

test('bad answers are reported, nothing is prepared', () => {
	const result = prepareUpload({ ...upload, answers: { ...upload.answers, final: 'ADMIT TENTS FEX' } });
	assert.equal(result.values, undefined);
	assert.match(result.problems[0], /circled letters/);
});

test('only PNG and JPEG cartoons are taken', () => {
	assert.equal(imageType(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0])), 'image/png');
	assert.equal(imageType(Buffer.from([0xff, 0xd8, 0xff, 0xe0])), 'image/jpeg');
	assert.equal(imageType(Buffer.from('GIF89a')), null);
});
