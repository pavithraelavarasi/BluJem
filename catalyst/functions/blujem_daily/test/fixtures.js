'use strict';

/** The 22 October 2026 puzzle as a correct agent reply would describe it. */
function goodReply(overrides = {}) {
	return {
		status: 'OK',
		puzzleDate: '2026-10-22',
		expectedDate: '2026-10-22',
		source: 'Hindustan Times Daily Jumble',
		words: [
			{ scrambled: 'NCWOR', circledPositions: [2, 3, 5], boxCount: 5 },
			{ scrambled: 'RPEGU', circledPositions: [1, 4, 5], boxCount: 5 },
			{ scrambled: 'ILEKFC', circledPositions: [1, 2, 3], boxCount: 6 },
			{ scrambled: 'OPTRAS', circledPositions: [2, 3, 4, 5], boxCount: 6 }
		],
		finalClue: 'TO LEARN AS MUCH AS POSSIBLE ABOUT THE ANDES, STUDENTS NEED TO STUDY A ---',
		finalAnswer: { groups: [5, 2, 6], prefix: '', betweenGroups: [' ', ' '], suffix: '', punctuation: [] },
		cartoon: { detected: true, sourceReference: 'right half', boundingBox: { x: 0.52, y: 0.03, w: 0.46, h: 0.95 } },
		confidence: 0.95,
		needsReview: false,
		notes: [],
		...overrides
	};
}

/** The Sunday Jumble of 2026-11-01: six words, a 15-letter answer printed "5-10". */
function sundayReply(overrides = {}) {
	return goodReply({
		puzzleDate: '2026-11-01',
		expectedDate: '2026-11-01',
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
		...overrides
	});
}

module.exports = { goodReply, sundayReply };
