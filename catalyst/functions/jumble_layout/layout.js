'use strict';

// What the layout agent says, checked before anything trusts it. A reply that
// fails any check is rejected whole, and the admin keeps the phone's own
// detection. Everything is a fraction of the original image, 0 to 1 — never a
// pixel or a screen position — so it lands right on every phone that draws it.

const letters = (text) => String(text || '').toUpperCase().replace(/[^A-Z]/g, '');

const isFraction = (n) => typeof n === 'number' && Number.isFinite(n) && n >= 0 && n <= 1;

/** A box as the app stores it, or null when it is not a usable region of the image. */
function box(raw) {
	if (!raw || typeof raw !== 'object') return null;
	const { x, y, w, h } = raw;
	if (![x, y, w, h].every(isFraction)) return null;
	if (w <= 0 || h <= 0) return null;
	// A small rounding slop past the edge is allowed; more is a box off the image.
	if (x + w > 1.001 || y + h > 1.001) return null;
	return { x, y, w, h };
}

/**
 * The agent's reply as a layout the app can store, or the reasons it cannot.
 *
 * Shape the agent returns (inside a code fence in data.response):
 *   { words: [{ scrambled, boxes: [{x,y,w,h}], circledPositions: [1-based] }],
 *     finalAnswerGroups: [n, ...], finalBoxes: [{x,y,w,h}], confidence }
 */
function validateLayout(reply) {
	const problems = [];
	const warnings = [];
	if (!reply || typeof reply !== 'object') {
		return { layout: null, problems: ['no JSON in the reply'], warnings };
	}

	const rawWords = Array.isArray(reply.words) ? reply.words : [];
	if (rawWords.length === 0) problems.push('no words');

	const words = rawWords.map((raw, i) => {
		const scrambled = letters(raw && raw.scrambled);
		const rawBoxes = Array.isArray(raw && raw.boxes) ? raw.boxes : [];
		const boxes = rawBoxes.map(box);
		if (!scrambled) problems.push(`word ${i + 1}: no letters`);
		if (boxes.length === 0) problems.push(`word ${i + 1}: no squares`);
		if (boxes.some((b) => b === null)) problems.push(`word ${i + 1}: a square outside the image`);
		if (scrambled && boxes.length && boxes.length !== scrambled.length) {
			problems.push(`word ${i + 1}: ${boxes.length} squares for ${scrambled.length} letters`);
		}
		// circledPositions count from 1, as the agent writes them.
		const circled = Array.isArray(raw && raw.circledPositions) ? raw.circledPositions : [];
		circled.forEach((p) => {
			if (!Number.isInteger(p) || p < 1 || p > boxes.length) {
				problems.push(`word ${i + 1}: circled position ${p} is not one of its squares`);
			}
		});
		const confidence = isFraction(raw && raw.confidence) ? raw.confidence : null;
		return {
			scrambled,
			boxes: boxes.map((b, j) => b && { ...b, circled: circled.includes(j + 1) }),
			confidence
		};
	});

	const rawFinal = Array.isArray(reply.finalBoxes) ? reply.finalBoxes : [];
	const finalBoxes = rawFinal.map(box);
	if (finalBoxes.some((b) => b === null)) problems.push('an answer square outside the image');
	const groups = Array.isArray(reply.finalAnswerGroups) ? reply.finalAnswerGroups : [];
	if (groups.some((n) => !Number.isInteger(n) || n < 1)) problems.push('answer groups are not counts');
	const groupTotal = groups.reduce((sum, n) => sum + (Number(n) || 0), 0);
	if (finalBoxes.length > 0 && groupTotal !== finalBoxes.length) {
		problems.push(`answer groups add up to ${groupTotal}, but there are ${finalBoxes.length} answer squares`);
	}

	// Not a reason to reject, but worth the admin's eye: on a Jumble every
	// circled square feeds exactly one answer square.
	const circledTotal = words.reduce((sum, w) => sum + w.boxes.filter((b) => b && b.circled).length, 0);
	if (finalBoxes.length > 0 && circledTotal !== finalBoxes.length) {
		warnings.push(`${circledTotal} circled squares for ${finalBoxes.length} answer squares`);
	}

	if (problems.length) return { layout: null, problems, warnings };
	return {
		layout: {
			words,
			finalBoxes: finalBoxes.map((b) => ({ ...b, circled: false })),
			finalGroupSizes: groups,
			confidence: isFraction(reply.confidence) ? reply.confidence : null
		},
		problems,
		warnings
	};
}

module.exports = { validateLayout, letters };
