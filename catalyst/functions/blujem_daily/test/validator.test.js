'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { PuzzleExtractionValidator } = require('../lib/puzzle-extraction-validator');
const { goodReply, sundayReply } = require('./fixtures');

const validator = new PuzzleExtractionValidator();
const codes = (result) => result.errors.map((e) => e.code);
const warningCodes = (result) => result.warnings.map((w) => w.code);

test('a correct reading for the expected day is EXTRACTED', () => {
	const result = validator.validate(goodReply(), '2026-10-22');
	assert.equal(result.status, 'EXTRACTED');
	assert.equal(result.needsReview, false);
	assert.deepEqual(result.errors, []);
	assert.equal(result.extraction.words[2].scrambled, 'ILEKFC');
});

test('a puzzle dated another day is STALE_SOURCE, never today', () => {
	const result = validator.validate(goodReply({ puzzleDate: '2026-10-21' }), '2026-10-22');
	assert.equal(result.status, 'STALE_SOURCE');
	assert.equal(result.needsReview, true);
	assert.equal(result.sourceDate, '2026-10-21');
	assert.equal(result.expectedDate, '2026-10-22');
});

test('on a Sunday an older puzzle is still stale, with a note rather than a fault', () => {
	// 2026-10-25 is a Sunday.
	const result = validator.validate(goodReply({ puzzleDate: '2026-10-24' }), '2026-10-25');
	assert.equal(result.status, 'STALE_SOURCE');
	assert.ok(warningCodes(result).includes('SUNDAY_NO_NEW_PUZZLE'));
	assert.deepEqual(result.errors, []);
});

test('a missing or malformed date needs review', () => {
	assert.ok(codes(validator.validate(goodReply({ puzzleDate: null }), '2026-10-22')).includes('MISSING_DATE'));
	assert.ok(codes(validator.validate(goodReply({ puzzleDate: '22/10/2026' }), '2026-10-22')).includes('BAD_DATE'));
});

test('four words, or six in the Sunday Jumble', () => {
	for (const count of [3, 5, 7]) {
		const reply = count < 4 ? goodReply() : sundayReply();
		reply.words = [...reply.words, ...reply.words].slice(0, count);
		const result = validator.validate(reply, reply.puzzleDate);
		assert.equal(result.status, 'NEEDS_REVIEW', `${count} words`);
		assert.ok(codes(result).includes('WRONG_WORD_COUNT'), `${count} words`);
	}
	const sunday = validator.validate(sundayReply(), '2026-11-01');
	assert.deepEqual(codes(sunday), []);
	assert.equal(sunday.status, 'EXTRACTED');
	assert.equal(sunday.extraction.words.length, 6);
});

test('scrambles are letters only, and fill their boxes', () => {
	const reply = goodReply();
	reply.words[0] = { scrambled: 'NCW0R', circledPositions: [2], boxCount: 5 };
	reply.words[1] = { scrambled: 'RPEGU', circledPositions: [1, 4, 5], boxCount: 6 };
	const result = validator.validate(reply, '2026-10-22');
	assert.ok(codes(result).includes('BAD_SCRAMBLE'));
	assert.ok(codes(result).includes('BOX_COUNT_MISMATCH'));
});

test('lower case and spaces in a scramble are tidied, not rejected', () => {
	const reply = goodReply();
	reply.words[0] = { scrambled: 'n c w o r', circledPositions: [2, 3, 5], boxCount: 5 };
	const result = validator.validate(reply, '2026-10-22');
	assert.equal(result.status, 'EXTRACTED');
	assert.equal(result.extraction.words[0].scrambled, 'NCWOR');
});

test('circle positions are 1-based, in range and listed once', () => {
	for (const bad of [[0, 2], [2, 6], [2, 2, 3], [1.5]]) {
		const reply = goodReply();
		reply.words[0] = { ...reply.words[0], circledPositions: bad };
		assert.ok(codes(validator.validate(reply, '2026-10-22')).includes('BAD_CIRCLE_POSITIONS'), JSON.stringify(bad));
	}
	const none = goodReply();
	none.words[0] = { ...none.words[0], circledPositions: [] };
	assert.ok(codes(validator.validate(none, '2026-10-22')).includes('NO_CIRCLES'));
});

test('the circled squares must fill the answer boxes exactly', () => {
	const reply = goodReply({ finalAnswer: { ...goodReply().finalAnswer, groups: [5, 5], betweenGroups: [' '] } });
	const result = validator.validate(reply, '2026-10-22');
	assert.ok(codes(result).includes('CIRCLES_DO_NOT_FILL_ANSWER'));
});

test('the final clue and positive answer groups are required', () => {
	assert.ok(codes(validator.validate(goodReply({ finalClue: '  ' }), '2026-10-22')).includes('MISSING_FINAL_CLUE'));
	const zero = goodReply({ finalAnswer: { ...goodReply().finalAnswer, groups: [5, 0, 8] } });
	assert.ok(codes(validator.validate(zero, '2026-10-22')).includes('INVALID_ANSWER_GROUPS'));
});

test('one separator per gap between groups', () => {
	const reply = goodReply({ finalAnswer: { ...goodReply().finalAnswer, betweenGroups: [' '] } });
	assert.ok(codes(validator.validate(reply, '2026-10-22')).includes('BAD_GROUP_SEPARATORS'));
});

test('punctuation stays outside the boxes and is listed in order', () => {
	const quoted = goodReply({
		finalAnswer: { groups: [5, 2, 6], prefix: '“', betweenGroups: ['-', ' '], suffix: '”', punctuation: ['“', '-', '”'] }
	});
	assert.equal(validator.validate(quoted, '2026-10-22').status, 'EXTRACTED');

	const unlisted = goodReply({
		finalAnswer: { groups: [5, 2, 6], prefix: '“', betweenGroups: [' ', ' '], suffix: '”', punctuation: [] }
	});
	const result = validator.validate(unlisted, '2026-10-22');
	assert.equal(result.status, 'NEEDS_REVIEW');
	assert.ok(warningCodes(result).includes('PUNCTUATION_INCONSISTENT'));

	const letters = goodReply({ finalAnswer: { ...goodReply().finalAnswer, suffix: 'S' } });
	assert.ok(codes(validator.validate(letters, '2026-10-22')).includes('BAD_PUNCTUATION'));
});

test('a missing cartoon or a box off the image needs review', () => {
	assert.ok(codes(validator.validate(goodReply({ cartoon: { detected: false } }), '2026-10-22')).includes('MISSING_CARTOON'));
	const off = goodReply({ cartoon: { detected: true, boundingBox: { x: 0.6, y: 0, w: 0.6, h: 1 } } });
	assert.ok(codes(validator.validate(off, '2026-10-22')).includes('BAD_CARTOON_BOX'));
});

test('low confidence or the agent asking for review sends it to a person', () => {
	const low = validator.validate(goodReply({ confidence: 0.6 }), '2026-10-22');
	assert.equal(low.status, 'NEEDS_REVIEW');
	assert.ok(warningCodes(low).includes('LOW_CONFIDENCE'));

	const flagged = validator.validate(goodReply({ needsReview: true }), '2026-10-22');
	assert.equal(flagged.status, 'NEEDS_REVIEW');

	const disagrees = validator.validate(goodReply({ status: 'NEEDS_REVIEW' }), '2026-10-22');
	assert.equal(disagrees.status, 'NEEDS_REVIEW');
	assert.ok(warningCodes(disagrees).includes('AGENT_STATUS_DISAGREES'));
});

test('a solved word anywhere in the reply is caught', () => {
	const inNotes = validator.validate(goodReply({ notes: ['row 1 looks like CROWN'] }), '2026-10-22');
	assert.equal(inNotes.status, 'NEEDS_REVIEW');
	assert.ok(codes(inNotes).includes('ANSWER_LEAKED'));

	const answerKey = goodReply();
	answerKey.words[1] = { ...answerKey.words[1], answer: 'PURGE' };
	assert.ok(codes(validator.validate(answerKey, '2026-10-22')).includes('ANSWER_LEAKED'));

	const solution = validator.validate(goodReply({ solution: 'RANGE OF TOPICS' }), '2026-10-22');
	assert.ok(codes(solution).includes('ANSWER_LEAKED'));
});

test('a reply that is not an object needs review', () => {
	assert.ok(codes(validator.validate('nope', '2026-10-22')).includes('INVALID_RESPONSE_SHAPE'));
	assert.ok(codes(validator.validate([], '2026-10-22')).includes('INVALID_RESPONSE_SHAPE'));
});

test('the real agent reply for 23 October 2026 is EXTRACTED', () => {
	// Saved verbatim from the BluJem Daily Puzzle Processor in Agent Studio.
	const reply = require('./agent-replies/2026-10-23.json');
	const result = validator.validate(reply, '2026-10-23');
	assert.equal(result.status, 'EXTRACTED');
	assert.deepEqual(result.errors, []);
	assert.deepEqual(result.warnings, []);
	assert.deepEqual(result.extraction.words.map((w) => w.scrambled), ['NHWSO', 'TYRPC', 'ETCPAC', 'ISRCSI']);
	assert.deepEqual(result.extraction.finalAnswer.betweenGroups, [' ', '” ']);
});

test('a sentence-case clue must be the printed clue in other capitals', () => {
	const ok = validator.validate(goodReply({
		finalClueSentenceCase: 'To learn as much as possible about the Andes, students need to study a ---'
	}), '2026-10-22');
	assert.equal(ok.status, 'EXTRACTED');
	assert.equal(ok.extraction.finalClueSentenceCase.startsWith('To learn'), true);

	const reworded = validator.validate(goodReply({ finalClueSentenceCase: 'Students study the Andes ---' }), '2026-10-22');
	assert.ok(reworded.warnings.map((w) => w.code).includes('SENTENCE_CASE_DIFFERS'));
});
