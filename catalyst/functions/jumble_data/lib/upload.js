'use strict';

const { parsePuzzleText, checkAnswers, fillPattern, lettersOf, PuzzleTextError } = require('./puzzle-text');
const { SLOTS, slotProblem, publishAt } = require('./slots');

/**
 * One upload from the admin — date, slot, the puzzle text, and the answers if
 * they have them yet — checked and turned into the Puzzles row to write. Pure:
 * the cartoon and the database are index.js's business.
 *
 * Without answers the row is stored unpublished (nobody can solve it); the
 * same date and slot uploaded again with them publishes it. Either way it
 * stays hidden from players until its slot's time.
 */
function prepareUpload(body) {
	const date = String(body.date || '').trim();
	const slot = String(body.slot || '').trim().toLowerCase();
	const where = slotProblem(date, slot);
	if (where) return { problems: [where] };

	let parsed;
	try {
		parsed = parsePuzzleText(body.text, SLOTS[slot].words);
	} catch (error) {
		if (error instanceof PuzzleTextError) return { problems: [error.message] };
		throw error;
	}

	const given = body.answers || {};
	const hasAnswers = (given.words || []).some((w) => lettersOf(w)) || lettersOf(given.final);
	const problems = hasAnswers ? checkAnswers(parsed, given) : [];
	if (problems.length) return { problems, parsed };

	const answers = hasAnswers ? given.words.map(lettersOf) : parsed.words.map(() => '');
	const finalLetters = hasAnswers ? lettersOf(given.final) : '';
	// The final answer printed with the pattern's own punctuation, on one line.
	const finalAnswer = finalLetters
		? fillPattern(parsed.pattern.text, finalLetters).replace(/-\n/g, '-').replace(/\n/g, ' ')
		: '';

	const values = {
		PublishDate: date,
		Slot: slot,
		PublishAt: publishAt(date, slot),
		PuzzleText: String(body.text),
		FinalPattern: parsed.pattern.text,
		SheetDate: '',
		Difficulty: slot === 'sunday' ? 'Mega' : 'Easy',
		TimeLimitSeconds: slot === 'sunday' ? 480 : 300,
		AspectRatio: 1,
		Published: hasAnswers ? 'true' : 'false',
		FinalAnswer: finalAnswer,
		FinalClue: String(body.clue || parsed.clue || ''),
		FinalExplanation: String(body.explanation || ''),
		// Only the circles matter: the app lays the page out from the letters.
		FinalBoxes: JSON.stringify(Array.from({ length: parsed.pattern.boxes }, () => ({ x: 0, y: 0, w: 0, h: 0, c: true }))),
		FinalGroupSizes: JSON.stringify(parsed.pattern.groups),
		Words: JSON.stringify(parsed.words.map((w, i) => ({
			scrambled: w.letters,
			answer: answers[i],
			boxes: [...w.letters].map((_, j) => ({ x: 0, y: 0, w: 0, h: 0, ...(w.circled.includes(j) ? { c: true } : {}) }))
		})))
	};
	const warnings = hasAnswers ? [] : ['No answers yet: stored but not published. Upload again with the answers to publish it.'];
	return { problems: [], parsed, values, warnings };
}

/** The Stratus key of a slot's cartoon. */
function cartoonKey(date, slot) {
	return `puzzles/${date}/${slot}/cartoon.png`;
}

/** What the picture is, from its first bytes; null when not PNG or JPEG. */
function imageType(bytes) {
	if (bytes.length > 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return 'image/png';
	if (bytes.length > 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
	return null;
}

module.exports = { prepareUpload, cartoonKey, imageType };
