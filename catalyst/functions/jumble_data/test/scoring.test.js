'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { scoreRun, playerRows } = require('../index');
const { cleanAbout, aboutProblem } = require('../lib/profile');

const run = (extra) => scoreRun({
	answers: ['MUSTY', 'NIFTY'],
	finalAnswer: 'MY',
	played: { words: [{ letters: 'MUSTY' }, { letters: 'NIFTY' }], finalLetters: 'MY' },
	serverHints: {},
	seconds: 200,
	...extra
});

test('solved on its day, a puzzle earns full points', () => {
	const score = run();
	assert.equal(score.basePoints, 70);
	assert.equal(score.totalPoints, 70);
	assert.equal(score.latePenalty, 0);
});

test('solved for the first time on a later day, it earns half', () => {
	const score = run({ late: true });
	assert.equal(score.totalPoints, 35);
	assert.equal(score.latePenalty, 35);
	// The speed multiplier still counts, before halving.
	const fast = run({ late: true, seconds: 50 });
	assert.equal(fast.totalPoints, 175);
	assert.equal(fast.wordPoints + fast.finalAnswerPoints + fast.timeBonus - fast.latePenalty, fast.totalPoints);
});

test('an odd total is halved downward', () => {
	const score = run({ late: true, played: { words: [{ letters: 'MUSTY' }, { letters: 'NIFTY', revealed: true }], finalLetters: 'MY' } });
	assert.equal(score.basePoints, 50);
	assert.equal(run({ late: true, answers: ['MUSTY', 'NIFTY'], played: { words: [{ letters: 'MUSTY', hintsUsed: 1 }, { letters: 'NIFTY', revealed: true }], finalLetters: 'X' } }).totalPoints, 7);
});

test('showing the answers earns nothing', () => {
	const score = run({ played: { words: [{ letters: 'MUSTY', revealed: true }, { letters: 'NIFTY', revealed: true }], finalLetters: 'MY' }, late: true });
	assert.equal(score.wordPoints, 0);
	const all = run({ played: { words: [{ letters: 'MUSTY', revealed: true }, { letters: 'NIFTY', revealed: true }], finalLetters: 'MY', finalRevealed: true } });
	assert.equal(all.totalPoints, 0);
});

test('About me is tidied and kept short', () => {
	assert.equal(cleanAbout('  Hi!\r\n\r\n\r\n\r\nI like puzzles.  \n '), 'Hi!\n\nI like puzzles.');
	assert.equal(cleanAbout('a\u0007b'), 'ab');
	assert.equal(aboutProblem('x'.repeat(300)), null);
	assert.match(aboutProblem('x'.repeat(301)), /300 characters/);
});

test('the admin player list joins accounts with their totals, most points first', () => {
	const rows = playerRows(
		[
			{ ROWID: '1', Username: 'otter_7', Name: 'Asha', CREATEDTIME: '2026-11-05 17:19:00:123' },
			{ ROWID: '2', Username: '', Name: 'Ravi', CREATEDTIME: '2026-11-10 09:00:00:000' },
			{ ROWID: '3', Username: 'newbie', CREATEDTIME: '2026-11-20 10:00:00:000' }
		],
		[{ UserId: '2', TotalPoints: '420', PuzzlesCompleted: '6' }, { UserId: '1', TotalPoints: '150', PuzzlesCompleted: '3' }]
	);
	assert.deepEqual(rows, [
		{ name: 'Ravi', since: '2026-11-10', games: 6, points: 420 },
		{ name: 'otter_7', since: '2026-11-05', games: 3, points: 150 },
		{ name: 'newbie', since: '2026-11-20', games: 0, points: 0 }
	]);
});
