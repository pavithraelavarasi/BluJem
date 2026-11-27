'use strict';

/**
 * The admin's puzzle text, read the same way the app reads it
 * (lib/admin/typed_puzzle.dart) — both are tested against
 * test/fixtures/puzzle_text_cases.json at the app's root.
 *
 *     aDRra          one jumbled word per line, capitals circled
 *     tuYpT
 *     hcNRcu
 *     cRaoCD
 *
 *     □□□-□□□-       the answer boxes; punctuation is kept as typed and a
 *     □□□            new line is where the strip may wrap
 *
 * A line of more than one word with no boxes is the cartoon's caption.
 */

/** Squares as pasted (□), or typed on a keyboard as _ or #. */
// A box copied through a Mac (into the iPhone simulator, say) or a Windows
// app can arrive garbled: □ as ‚ñ° or â–¡. Each garbled form goes back to its box.
const GARBLED_BOXES = [['\u201a\u00f1\u00b0', '□'], ['\u00e2\u2013\u00a1', '□'], ['\u00e2\u0096\u00a1', '□'], ['\u201a\u00f1\u00a2', '▢'], ['\u00e2\u2013\u00a2', '▢'], ['\u00e2\u0096\u00a2', '▢'], ['\u201a\u00f2\u00ea', '☐'], ['\u00e2\u0098\u0090', '☐'], ['\u201a\u00f1\u2020', '■'], ['\u00e2\u2013\u00a0', '■'], ['\u00e2\u0096\u00a0', '■'], ['\u201a\u00f3\u00aa', '◻'], ['\u00e2\u2014\u00bb', '◻'], ['\u00e2\u0097\u00bb', '◻'], ['\u201a\u00a8\u00fa', '⬜'], ['\u00e2\u00ac\u0153', '⬜'], ['\u00e2\u00ac\u009c', '⬜']];
function ungarbleBoxes(text) {
	let out = String(text || '');
	for (const [garbled, box] of GARBLED_BOXES) out = out.split(garbled).join(box);
	return out;
}

const BOXES = /[□☐■◻⬜▢_#]/g;
const HAS_BOX = /[□☐■◻⬜▢_#]/;
const WORD = /^[A-Za-z]+$/;
const MAX_LETTERS = 8;

class PuzzleTextError extends Error {}

/**
 * Reads [text] for a puzzle of [wordCount] words (4, or 6 on Sunday), or
 * throws a PuzzleTextError saying what to fix.
 */
function parsePuzzleText(text, wordCount) {
	const words = [];
	const shape = [];
	const clue = [];
	for (const raw of ungarbleBoxes(text).replace(/\r/g, '').split('\n')) {
		const line = raw.trim();
		if (!line) continue;
		if (HAS_BOX.test(line)) {
			shape.push(line.replace(BOXES, '□'));
		} else if (/\s/.test(line)) {
			clue.push(line);
		} else {
			if (shape.length) throw new PuzzleTextError(`"${line}" comes after the answer boxes — type the words first.`);
			if (!WORD.test(line)) throw new PuzzleTextError(`"${line}": a scrambled word can have only letters.`);
			if (line.length > MAX_LETTERS) throw new PuzzleTextError(`"${line}" is too long: a word has at most ${MAX_LETTERS} letters.`);
			words.push({
				letters: line.toUpperCase(),
				circled: [...line].flatMap((c, i) => (c !== c.toLowerCase() ? [i] : []))
			});
		}
	}
	if (words.length !== wordCount) {
		throw new PuzzleTextError(`Found ${words.length} words, but this puzzle needs ${wordCount} words${wordCount === 6 ? ' (Sunday)' : ''}.`);
	}
	const circled = words.reduce((n, w) => n + w.circled.length, 0);
	if (circled === 0) throw new PuzzleTextError('No circled letters: type the circled letters as capitals, like aDRra.');
	if (!shape.length) throw new PuzzleTextError('Type the answer boxes (□□□-□□□) after a blank line under the words.');

	const pattern = answerPattern(shape.join('\n'));
	if (pattern.boxes !== circled) {
		throw new PuzzleTextError(`${circled} circled letters but ${pattern.boxes} answer boxes: they must be the same.`);
	}
	return { words, pattern, clue: clue.join(' ') };
}

/**
 * The answer boxes: how many, in which groups (runs of boxes; anything else
 * between them starts a new group), and which groups share a line.
 */
function answerPattern(text) {
	const lines = text.split('\n');
	const groups = [];
	const groupLines = [];
	lines.forEach((line) => {
		const onLine = [];
		for (const run of line.match(/□+/g) || []) {
			onLine.push(groups.length);
			groups.push(run.length);
		}
		if (onLine.length) groupLines.push(onLine);
	});
	return { text, boxes: groups.reduce((a, b) => a + b, 0), groups, lines: groupLines };
}

const lettersOf = (text) => String(text || '').toUpperCase().replace(/[^A-Z]/g, '');
const sorted = (s) => [...s].sort().join('');

/**
 * Checks the answers against the parsed text: each word must rearrange its
 * jumble, and the final answer must use exactly the circled letters, in
 * the pattern's groups. Returns the problems; empty when all is well.
 */
function checkAnswers(parsed, answers) {
	const problems = [];
	const words = (answers.words || []).map(lettersOf);
	if (words.length !== parsed.words.length) {
		problems.push(`Give ${parsed.words.length} word answers, one per jumble.`);
		return problems;
	}
	words.forEach((answer, i) => {
		const jumble = parsed.words[i].letters;
		if (sorted(answer) !== sorted(jumble)) problems.push(`Word ${i + 1}: ${answer || '(empty)'} is not made of the letters ${jumble}.`);
	});
	const final = String(answers.final || '');
	const circled = words.flatMap((w, i) => parsed.words[i].circled.map((c) => w[c] || '')).join('');
	if (!lettersOf(final)) {
		problems.push('Give the final answer.');
	} else if (problems.length === 0 && sorted(lettersOf(final)) !== sorted(circled)) {
		problems.push(`The final answer must use exactly the circled letters ${circled}.`);
	} else if (JSON.stringify(groupsOf(final)) !== JSON.stringify(parsed.pattern.groups)) {
		problems.push(`The final answer's words (${groupsOf(final).join('-')}) do not match the boxes (${parsed.pattern.groups.join('-')}).`);
	}
	return problems;
}

/** Letters per word of an answer as typed: runs of letters. */
function groupsOf(answer) {
	return (String(answer).toUpperCase().match(/[A-Z]+/g) || []).map((w) => w.length);
}

/** [pattern] with its boxes filled by [letters], left to right. */
function fillPattern(pattern, letters) {
	let i = 0;
	return String(pattern).replace(/□/g, () => letters[i++] || '□');
}

/** [answer] as boxes: its punctuation kept, every letter a □. */
function patternOf(answer) {
	return String(answer || '').toUpperCase().replace(/[A-Z]/g, '□');
}

module.exports = { parsePuzzleText, ungarbleBoxes, answerPattern, checkAnswers, fillPattern, patternOf, lettersOf, PuzzleTextError };
