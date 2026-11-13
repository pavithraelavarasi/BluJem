'use strict';

/**
 * One Daily Jumble as the BluJem Daily Puzzle Processor agent read it: the
 * printed structure only — scrambles, circle positions, the clue and the
 * answer's shape. Never a solved word, never the final answer.
 *
 * Built from the agent's raw JSON by [BluJemPuzzleExtraction.fromAgentJson],
 * which tidies what is safe to tidy (case, stray whitespace) and leaves
 * everything else exactly as the agent sent it, so the validator still sees
 * any mistake: a digit in a scramble stays a digit.
 *
 * The shape matches schema/zia-daily-puzzle-schema.json.
 */
class BluJemPuzzleExtraction {
	constructor(fields) {
		/** 'OK' | 'STALE_SOURCE' | 'NEEDS_REVIEW', as the agent judged it. */
		this.status = fields.status;
		/** yyyy-MM-dd printed on the puzzle, or null. */
		this.puzzleDate = fields.puzzleDate;
		this.source = fields.source;
		/** @type {{scrambled: string, circledPositions: number[], boxCount: number}[]} */
		this.words = fields.words;
		this.finalClue = fields.finalClue;
		/** The clue in sentence case, names capitalised — for the answer strip. Optional. */
		this.finalClueSentenceCase = fields.finalClueSentenceCase;
		/** @type {{groups: number[], prefix: string, betweenGroups: string[], suffix: string, punctuation: string[]}} */
		this.finalAnswer = fields.finalAnswer;
		/** @type {{detected: boolean, imageIndex?: number, sourceReference?: string, boundingBox?: {x: number, y: number, w: number, h: number}}} */
		this.cartoon = fields.cartoon;
		this.confidence = fields.confidence;
		this.needsReview = fields.needsReview;
		this.notes = fields.notes;
	}

	/**
	 * The extraction from the agent's parsed JSON. Missing parts come through
	 * as undefined or empty, never invented, so the validator reports them.
	 */
	static fromAgentJson(raw) {
		const json = raw && typeof raw === 'object' ? raw : {};
		const answer = json.finalAnswer && typeof json.finalAnswer === 'object' ? json.finalAnswer : {};
		const cartoon = json.cartoon && typeof json.cartoon === 'object' ? json.cartoon : {};
		return new BluJemPuzzleExtraction({
			status: typeof json.status === 'string' ? json.status.trim().toUpperCase() : undefined,
			puzzleDate: typeof json.puzzleDate === 'string' ? json.puzzleDate.trim() : json.puzzleDate ?? null,
			source: typeof json.source === 'string' ? json.source.trim() : undefined,
			words: Array.isArray(json.words)
				? json.words.map((word) => ({
					// Upper-cased and spaces dropped; anything else is left for
					// the validator to catch, not quietly cleaned away.
					scrambled: typeof (word && word.scrambled) === 'string'
						? word.scrambled.replace(/\s+/g, '').toUpperCase()
						: undefined,
					circledPositions: Array.isArray(word && word.circledPositions) ? word.circledPositions : undefined,
					boxCount: word ? word.boxCount : undefined
				}))
				: [],
			finalClue: typeof json.finalClue === 'string' ? json.finalClue.trim() : undefined,
			finalClueSentenceCase: typeof json.finalClueSentenceCase === 'string' ? json.finalClueSentenceCase.trim() : undefined,
			finalAnswer: {
				groups: Array.isArray(answer.groups) ? answer.groups : undefined,
				prefix: answer.prefix ?? '',
				betweenGroups: Array.isArray(answer.betweenGroups) ? answer.betweenGroups : undefined,
				suffix: answer.suffix ?? '',
				punctuation: Array.isArray(answer.punctuation) ? answer.punctuation : []
			},
			cartoon: {
				detected: cartoon.detected === true,
				imageIndex: Number.isInteger(cartoon.imageIndex) ? cartoon.imageIndex : undefined,
				sourceReference: typeof cartoon.sourceReference === 'string' ? cartoon.sourceReference : undefined,
				boundingBox: cartoon.boundingBox && typeof cartoon.boundingBox === 'object' ? cartoon.boundingBox : undefined
			},
			confidence: typeof json.confidence === 'number' ? json.confidence : undefined,
			needsReview: json.needsReview === true,
			notes: Array.isArray(json.notes) ? json.notes.filter((n) => typeof n === 'string') : []
		});
	}

	/** Plain JSON, for the response and for puzzle.json. */
	toJSON() {
		return {
			status: this.status,
			puzzleDate: this.puzzleDate,
			source: this.source,
			words: this.words,
			finalClue: this.finalClue,
			finalClueSentenceCase: this.finalClueSentenceCase,
			finalAnswer: this.finalAnswer,
			cartoon: this.cartoon,
			confidence: this.confidence,
			needsReview: this.needsReview,
			notes: this.notes
		};
	}
}

module.exports = { BluJemPuzzleExtraction };
