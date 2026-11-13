'use strict';

/**
 * Finds the cartoon's own frame on the source image.
 *
 * The agent says roughly where the cartoon is; cropping to that alone can cut
 * off the frame, a speech bubble or the caption, which must all be kept. So
 * the search looks around the agent's box (and a margin beyond it) for the
 * frame itself: the long dark lines along its top, bottom and sides. With no
 * frame found, the agent's box is used and the result is marked for review.
 */

/** Darker than this counts as ink. */
const INK = 110;
/** How far beyond the agent's box to look, as a fraction of the image. */
const MARGIN = 0.08;

/**
 * @param {{width: number, height: number, data: Uint8Array}} bitmap  RGBA
 * @param {{x: number, y: number, w: number, h: number}|undefined} box  fractions of the image
 * @returns {{x: number, y: number, w: number, h: number, frameFound: boolean}}  pixels
 */
function locateCartoon(bitmap, box) {
	const W = bitmap.width;
	const H = bitmap.height;
	const guess = box && box.w > 0 && box.h > 0 ? box : { x: 0.5, y: 0, w: 0.5, h: 1 };
	const x0 = clamp(Math.floor((guess.x - MARGIN) * W), 0, W - 1);
	const y0 = clamp(Math.floor((guess.y - MARGIN) * H), 0, H - 1);
	const x1 = clamp(Math.ceil((guess.x + guess.w + MARGIN) * W), x0 + 1, W);
	const y1 = clamp(Math.ceil((guess.y + guess.h + MARGIN) * H), y0 + 1, H);
	const w = x1 - x0;
	const h = y1 - y0;

	const dark = (x, y) => {
		const i = (y * W + x) * 4;
		const d = bitmap.data;
		return (d[i] * 299 + d[i + 1] * 587 + d[i + 2] * 114) / 1000 < INK;
	};

	// A frame edge is a line of ink running most of the way across the frame.
	// The search box is at most a margin wider than the frame, so half its
	// size is a safe bar that text and drawing never reach.
	const longestRun = (fixed, from, to, horizontal) => {
		let run = 0;
		let best = 0;
		let gap = 0;
		for (let t = from; t < to; t++) {
			if (horizontal ? dark(t, fixed) : dark(fixed, t)) {
				run += gap + 1;
				gap = 0;
				if (run > best) best = run;
			} else if (run > 0 && ++gap > 3) {
				run = 0;
				gap = 0;
			}
		}
		return best;
	};

	const rows = [];
	for (let y = y0; y < y1; y++) if (longestRun(y, x0, x1, true) >= w * 0.5) rows.push(y);
	const cols = [];
	for (let x = x0; x < x1; x++) if (longestRun(x, y0, y1, false) >= h * 0.5) cols.push(x);

	if (rows.length >= 2 && cols.length >= 2) {
		const top = rows[0];
		const bottom = rows[rows.length - 1];
		const left = cols[0];
		const right = cols[cols.length - 1];
		// Plausible: a real panel, not two stray strokes close together.
		if (bottom - top > h * 0.4 && right - left > w * 0.4) {
			const pad = Math.round(Math.max(W, H) * 0.004);
			const fx = clamp(left - pad, 0, W - 1);
			const fy = clamp(top - pad, 0, H - 1);
			return {
				x: fx,
				y: fy,
				w: clamp(right + pad + 1, fx + 1, W) - fx,
				h: clamp(bottom + pad + 1, fy + 1, H) - fy,
				frameFound: true
			};
		}
	}
	// No frame to be found: the agent's own box, exactly.
	const gx = clamp(Math.round(guess.x * W), 0, W - 1);
	const gy = clamp(Math.round(guess.y * H), 0, H - 1);
	return {
		x: gx,
		y: gy,
		w: clamp(Math.round((guess.x + guess.w) * W), gx + 1, W) - gx,
		h: clamp(Math.round((guess.y + guess.h) * H), gy + 1, H) - gy,
		frameFound: false
	};
}

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

module.exports = { locateCartoon };
