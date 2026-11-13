'use strict';

const crypto = require('crypto');
const { patternOf, lettersOf } = require('./puzzle-text');
const { defaultSlot, releaseTime, isIsoDate } = require('./slots');

/**
 * What a Puzzles row looks like to the app. An admin gets everything; a
 * player gets no answers at all — each word and the final answer arrive only
 * as a hash the phone checks its letters against, so solving still works
 * offline but the answers cannot be read out of the reply. The answers come
 * with puzzles/answers once the player has started the puzzle and needs them
 * (a hint, a reveal), or has finished it.
 */

const asBool = (value) => value === true || value === 'true';

function parseList(text) {
	try {
		const value = JSON.parse(text || '[]');
		return Array.isArray(value) ? value : [];
	} catch (e) {
		return [];
	}
}

/** sha256 of the puzzle's id and the letters, hex — the app's answerHash(). */
function answerHash(puzzleId, letters, which = '') {
	return crypto.createHash('sha256').update(`${puzzleId}:${which}${lettersOf(letters)}`).digest('hex');
}

function puzzleFromRow(row) {
	const publishDate = String(row.PublishDate || '');
	return {
		id: row.PuzzleId,
		publishDate,
		slot: row.Slot || (isIsoDate(publishDate) ? defaultSlot(publishDate) : 'morning'),
		publishAt: Number.isFinite(releaseTime(row)) ? releaseTime(row) : 0,
		sheetDate: row.SheetDate || '',
		difficulty: row.Difficulty || 'Easy',
		timeLimitSeconds: Number(row.TimeLimitSeconds || 300),
		sheetKey: row.SheetKey || '',
		aspectRatio: Number(row.AspectRatio || 1),
		published: asBool(row.Published),
		finalAnswer: row.FinalAnswer || '',
		finalPattern: row.FinalPattern || patternOf(row.FinalAnswer),
		finalClue: row.FinalClue || '',
		finalExplanation: row.FinalExplanation || '',
		finalBoxes: row.FinalBoxes || '[]',
		finalGroupSizes: row.FinalGroupSizes || '[]',
		words: row.Words || '[]',
		puzzleText: row.PuzzleText || ''
	};
}

/** Every answer is in: a player could finish it. */
function isComplete(row) {
	const words = parseList(row.Words);
	return words.length > 0 && words.every((w) => lettersOf(w.answer)) && lettersOf(row.FinalAnswer) !== '';
}

/** [row] with its answers swapped for hashes, its explanation held back. */
function playerView(row) {
	const full = puzzleFromRow(row);
	const id = full.id;
	return {
		...full,
		words: JSON.stringify(parseList(row.Words).map((w) => ({
			scrambled: w.scrambled || '',
			answerHash: answerHash(id, w.answer),
			boxes: w.boxes || []
		}))),
		finalAnswer: '',
		finalHash: answerHash(id, row.FinalAnswer, 'final:'),
		finalExplanation: '',
		puzzleText: ''
	};
}

/** The answers alone, for a player who has earned them. */
function answersOf(row) {
	return {
		puzzleId: row.PuzzleId,
		words: parseList(row.Words).map((w) => lettersOf(w.answer)),
		finalAnswer: row.FinalAnswer || '',
		finalExplanation: row.FinalExplanation || ''
	};
}

module.exports = { asBool, parseList, answerHash, puzzleFromRow, isComplete, playerView, answersOf };
