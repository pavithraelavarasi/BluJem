'use strict';

const { BluJemPuzzleExtraction } = require('./puzzle-extraction');
const { isIsoDate, isSunday } = require('./india-date');

/**
 * Checks what the BluJem Daily Puzzle Processor agent returned before anything
 * is done with it.
 *
 * The agent's own `status` and `needsReview` are taken as advice, never as the
 * verdict: every rule is checked again here, and anything that fails sends the
 * puzzle to a person (NEEDS_REVIEW) instead of on towards publishing.
 *
 * Result statuses, matching the pipeline's:
 *   EXTRACTED     — every check passed
 *   STALE_SOURCE  — the date printed on the puzzle is not the expected day
 *   NEEDS_REVIEW  — something failed or was uncertain; a person must look
 */

/** Below this, a reading goes to a person even when every check passes. */
const MIN_CONFIDENCE = 0.85;

/** How many word rows a Jumble prints: four on weekdays, six in the Sunday Jumble. */
const WORD_COUNTS = [4, 6];

/** Keys that only appear in a response that has started solving the puzzle. */
const SOLVING_KEYS = /^(answers?|solutions?|solved|solvedwords?|unscrambled|hints?|explanation|joke|meaning)$/i;

const sortedLetters = (text) => text.split('').sort().join('');

class PuzzleExtractionValidator {
	/**
	 * @param {{minConfidence?: number}} [options]
	 */
	constructor(options = {}) {
		this.minConfidence = options.minConfidence ?? MIN_CONFIDENCE;
	}

	/**
	 * Validates the agent's parsed JSON for the day [expectedDate] (yyyy-MM-dd,
	 * India time).
	 *
	 * @returns {{
	 *   status: 'EXTRACTED'|'STALE_SOURCE'|'NEEDS_REVIEW',
	 *   needsReview: boolean,
	 *   expectedDate: string,
	 *   sourceDate: string|null,
	 *   errors: {code: string, message: string, path?: string}[],
	 *   warnings: {code: string, message: string, path?: string}[],
	 *   extraction: BluJemPuzzleExtraction
	 * }}
	 */
	validate(raw, expectedDate) {
		const errors = [];
		const warnings = [];
		const error = (code, message, path) => errors.push(path ? { code, message, path } : { code, message });
		const warn = (code, message, path) => warnings.push(path ? { code, message, path } : { code, message });

		if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
			error('INVALID_RESPONSE_SHAPE', 'The agent did not return a JSON object.');
			return this.result('NEEDS_REVIEW', expectedDate, null, errors, warnings, BluJemPuzzleExtraction.fromAgentJson({}));
		}

		const extraction = BluJemPuzzleExtraction.fromAgentJson(raw);

		// ------------------------------------------------------------ the date
		const sourceDate = extraction.puzzleDate;
		let stale = false;
		if (sourceDate === null || sourceDate === undefined || sourceDate === '') {
			error('MISSING_DATE', 'No date could be read off the puzzle.', 'puzzleDate');
		} else if (!isIsoDate(sourceDate)) {
			error('BAD_DATE', `"${sourceDate}" is not a yyyy-MM-dd date.`, 'puzzleDate');
		} else if (sourceDate !== expectedDate) {
			stale = true;
			if (isSunday(expectedDate)) {
				// No new Daily Jumble is printed on Sundays: an older one is
				// expected that day, and is not a fault — but it is still not
				// today's puzzle.
				warn('SUNDAY_NO_NEW_PUZZLE', `${expectedDate} is a Sunday; there is usually no new Daily Jumble.`);
			}
		}

		// ------------------------------------------------------------ the words
		const words = extraction.words;
		if (!WORD_COUNTS.includes(words.length)) {
			error('WRONG_WORD_COUNT', `Expected ${WORD_COUNTS.join(' or ')} word rows, got ${words.length}.`, 'words');
		}
		let circleTotal = 0;
		words.forEach((word, i) => {
			const at = `words[${i}]`;
			const scrambled = word.scrambled;
			const scrambleOk = typeof scrambled === 'string' && /^[A-Z]+$/.test(scrambled);
			if (!scrambleOk) {
				error('BAD_SCRAMBLE', `Word ${i + 1}: "${scrambled ?? ''}" is not letters A-Z only.`, `${at}.scrambled`);
			}
			const boxCount = word.boxCount;
			if (!Number.isInteger(boxCount) || boxCount < 1) {
				error('BAD_BOX_COUNT', `Word ${i + 1}: box count ${boxCount} is not a positive whole number.`, `${at}.boxCount`);
			} else if (scrambleOk && boxCount !== scrambled.length) {
				error('BOX_COUNT_MISMATCH', `Word ${i + 1}: ${scrambled.length} letters but ${boxCount} boxes.`, `${at}.boxCount`);
			}

			const circles = word.circledPositions;
			if (!Array.isArray(circles)) {
				error('BAD_CIRCLE_POSITIONS', `Word ${i + 1}: circled positions are missing.`, `${at}.circledPositions`);
				return;
			}
			if (circles.length === 0) {
				error('NO_CIRCLES', `Word ${i + 1}: no circled squares; every Jumble word has at least one.`, `${at}.circledPositions`);
			}
			const size = Number.isInteger(boxCount) ? boxCount : (scrambleOk ? scrambled.length : 0);
			const bad = circles.filter((p) => !Number.isInteger(p) || p < 1 || p > size);
			if (bad.length) {
				error('BAD_CIRCLE_POSITIONS', `Word ${i + 1}: positions ${JSON.stringify(bad)} are not between 1 and ${size}.`, `${at}.circledPositions`);
			}
			if (new Set(circles).size !== circles.length) {
				error('BAD_CIRCLE_POSITIONS', `Word ${i + 1}: a position is listed twice.`, `${at}.circledPositions`);
			}
			circleTotal += circles.length;
		});

		// ---------------------------------------------------------- the clue
		if (!extraction.finalClue) {
			error('MISSING_FINAL_CLUE', 'The final clue is missing.', 'finalClue');
		} else if (extraction.finalClueSentenceCase !== undefined &&
			extraction.finalClueSentenceCase.toUpperCase() !== extraction.finalClue.toUpperCase()) {
			// Only the capitals may differ; a reworded clue would print wrong.
			warn('SENTENCE_CASE_DIFFERS', 'The sentence-case clue is not the printed clue in other capitals; the printed one is used.', 'finalClueSentenceCase');
		}

		// ------------------------------------------------------- the answer
		const answer = extraction.finalAnswer;
		const groups = answer.groups;
		if (!Array.isArray(groups) || groups.length === 0) {
			error('INVALID_ANSWER_GROUPS', 'The final answer groups are missing.', 'finalAnswer.groups');
		} else if (groups.some((g) => !Number.isInteger(g) || g < 1)) {
			error('INVALID_ANSWER_GROUPS', `Groups ${JSON.stringify(groups)} must all be positive whole numbers.`, 'finalAnswer.groups');
		} else {
			const boxes = groups.reduce((sum, g) => sum + g, 0);
			// The final answer is made of exactly the circled letters, so the
			// two counts must agree; when they do not, one of them was misread.
			if (WORD_COUNTS.includes(words.length) && circleTotal !== boxes) {
				error(
					'CIRCLES_DO_NOT_FILL_ANSWER',
					`${circleTotal} circled squares but ${boxes} answer boxes; one of them was misread.`,
					'finalAnswer.groups'
				);
			}
			const between = answer.betweenGroups;
			if (!Array.isArray(between) || between.length !== groups.length - 1) {
				error(
					'BAD_GROUP_SEPARATORS',
					`Expected ${groups.length - 1} separator(s) between groups, got ${Array.isArray(between) ? between.length : 'none'}.`,
					'finalAnswer.betweenGroups'
				);
			}
		}
		const printed = [answer.prefix, answer.suffix, ...(Array.isArray(answer.betweenGroups) ? answer.betweenGroups : [])];
		if (printed.some((p) => typeof p !== 'string')) {
			error('BAD_PUNCTUATION', 'Prefix, suffix and separators must be text.', 'finalAnswer');
		} else if (printed.some((p) => /[A-Za-z0-9]/.test(p))) {
			error('BAD_PUNCTUATION', 'Letters or digits found outside the answer boxes.', 'finalAnswer');
		} else {
			// Every mark printed round the boxes should be listed, in order.
			const marks = [answer.prefix, ...(answer.betweenGroups || []), answer.suffix]
				.join('').replace(/\s+/g, '');
			const listed = (answer.punctuation || []).join('').replace(/\s+/g, '');
			if (marks !== listed) {
				warn(
					'PUNCTUATION_INCONSISTENT',
					`Punctuation list ${JSON.stringify(answer.punctuation)} does not match what is printed round the boxes ("${marks}").`,
					'finalAnswer.punctuation'
				);
			}
		}

		// ---------------------------------------------------------- the cartoon
		if (!extraction.cartoon.detected) {
			error('MISSING_CARTOON', 'No cartoon panel was found.', 'cartoon.detected');
		}
		const box = extraction.cartoon.boundingBox;
		if (box !== undefined) {
			const ok = ['x', 'y', 'w', 'h'].every((k) => typeof box[k] === 'number') &&
				box.x >= 0 && box.y >= 0 && box.w > 0 && box.h > 0 &&
				box.x + box.w <= 1.001 && box.y + box.h <= 1.001;
			if (!ok) error('BAD_CARTOON_BOX', 'The cartoon box is not inside the image.', 'cartoon.boundingBox');
		}

		// ------------------------------------------------------ confidence
		const confidence = extraction.confidence;
		if (typeof confidence !== 'number' || confidence < 0 || confidence > 1) {
			error('BAD_CONFIDENCE', 'Confidence must be a number from 0 to 1.', 'confidence');
		} else if (confidence < this.minConfidence) {
			warn('LOW_CONFIDENCE', `Confidence ${confidence} is below ${this.minConfidence}.`, 'confidence');
		}
		if (extraction.needsReview) {
			warn('AGENT_FLAGGED_REVIEW', 'The agent asked for a person to check this.', 'needsReview');
		}

		// ------------------------------------------------------ no answers
		this.checkNothingSolved(raw, words, error);

		// ----------------------------------------------------------- verdict
		const status = stale ? 'STALE_SOURCE'
			: (errors.length || warnings.some((w) => REVIEW_WARNINGS.has(w.code))) ? 'NEEDS_REVIEW'
				: 'EXTRACTED';
		if (status === 'EXTRACTED' && extraction.status && extraction.status !== 'OK') {
			// The agent thought otherwise and every check still passed: worth a look.
			warn('AGENT_STATUS_DISAGREES', `The agent said ${extraction.status}.`, 'status');
			return this.result('NEEDS_REVIEW', expectedDate, sourceDate ?? null, errors, warnings, extraction);
		}
		return this.result(status, expectedDate, sourceDate ?? null, errors, warnings, extraction);
	}

	/**
	 * Fails the extraction when it has started solving: a key only a solver
	 * would write, or any rearrangement of a scramble written anywhere other
	 * than the scramble itself (CROWN appearing in a note, for NCWOR).
	 */
	checkNothingSolved(raw, words, error) {
		const scrambles = words
			.map((w) => w.scrambled)
			.filter((s) => typeof s === 'string' && /^[A-Z]{3,}$/.test(s));
		const keys = new Map(scrambles.map((s) => [sortedLetters(s), s]));

		const visit = (value, path, isScramble) => {
			if (Array.isArray(value)) {
				value.forEach((item, i) => visit(item, `${path}[${i}]`, false));
			} else if (value && typeof value === 'object') {
				for (const [key, inner] of Object.entries(value)) {
					const at = path ? `${path}.${key}` : key;
					if (SOLVING_KEYS.test(key)) {
						error('ANSWER_LEAKED', `The response has a "${key}" field; the agent must not solve.`, at);
					}
					visit(inner, at, key === 'scrambled');
				}
			} else if (typeof value === 'string' && !isScramble) {
				for (const token of value.toUpperCase().match(/[A-Z]{3,}/g) || []) {
					const scramble = keys.get(sortedLetters(token));
					if (scramble && token !== scramble) {
						error('ANSWER_LEAKED', `"${token}" rearranges the scramble ${scramble}; a solved word was written.`, path);
					}
				}
			}
		};
		visit(raw, '', false);
	}

	result(status, expectedDate, sourceDate, errors, warnings, extraction) {
		return {
			status,
			needsReview: status !== 'EXTRACTED',
			expectedDate,
			sourceDate,
			errors,
			warnings,
			extraction
		};
	}
}

/** Warnings serious enough that a person must check before publishing. */
const REVIEW_WARNINGS = new Set(['LOW_CONFIDENCE', 'AGENT_FLAGGED_REVIEW', 'PUNCTUATION_INCONSISTENT']);

module.exports = { PuzzleExtractionValidator, MIN_CONFIDENCE };
