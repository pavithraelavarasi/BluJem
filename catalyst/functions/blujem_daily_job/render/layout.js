'use strict';

/**
 * Where everything goes on the BluJem images — plain numbers, no drawing, so
 * it can be tested and so the app can be told exactly where every square is.
 *
 * The collage copies the BluJem sheets the admin already uploads (measured off
 * them): 1800 × 1361, a cream header with the logo, byline and instructions on
 * the left, four rows of pastel squares under it (six on a Sunday, closer
 * together), a grey divider down the middle and the cartoon on the right.
 */

const NUMBER_WORDS = { 4: 'four', 5: 'five', 6: 'six' };

const COLLAGE = {
	width: 1800,
	height: 1361,
	/** The left half: header and word rows are centred on this. */
	leftCentre: 450,
	leftWidth: 840,
	divider: { x: 899, width: 2, color: '#9B9B9B' },
	header: { x: 32, y: 35, w: 836, h: 336, radius: 26, fill: '#FFF9E9' },
	logo: { centreX: 450, top: 46, height: 118 },
	byline: { text: 'By David L Hoyt and Jeff Knurek', y: 190, size: 30 },
	instructions: {
		/** The printed instructions, which say how many words there are. */
		lines: (count) => [
			'Unscramble these jumbles, one letter to each square,',
			`to form ${NUMBER_WORDS[count] || count} ordinary words.`,
			'Then arrange the circled letters to form the surprise',
			'answer, as suggested by the above cartoon.'
		],
		firstY: 246,
		lineHeight: 34,
		size: 26
	},
	textColor: '#3C454C',
	/** Rows start under the header and end by [bottom]; four keep their full pitch. */
	rows: { firstTop: 420, pitch: 196, bottom: 1326, minGap: 14 },
	tile: { size: 130, gap: 12, border: 4, radius: 8, circleInset: 8, circleWidth: 2.5 },
	letter: { color: '#171717', sizeRatio: 0.62 },
	rowFills: ['#FEC7C8', '#D0FCD0', '#C2E4FD', '#FEFBA6', '#E6D6FB', '#FFDDBC'],
	cartoonBox: { x: 930, y: 36, w: 840, h: 1290 }
};

/**
 * Every square of every word row, in pixels on the collage, plus the same as
 * fractions of the image for the app. Long words get smaller squares so the
 * row still fits the left half, and more rows sit closer so they all fit
 * under the header.
 *
 * @param {{scrambled: string, circledPositions: number[]}[]} words
 */
function collageLayout(words) {
	const { tile, rows, leftCentre, leftWidth } = COLLAGE;
	const longest = Math.max(...words.map((w) => w.scrambled.length));
	const natural = longest * tile.size + (longest - 1) * tile.gap;
	const scale = natural > leftWidth ? leftWidth / natural : 1;
	const pitch = Math.min(rows.pitch, Math.floor((rows.bottom - rows.firstTop) / words.length));
	const size = Math.min(Math.floor(tile.size * scale), pitch - rows.minGap);
	const gap = Math.floor(tile.gap * (size / tile.size));

	const rowsOut = words.map((word, i) => {
		const n = word.scrambled.length;
		const width = n * size + (n - 1) * gap;
		const left = Math.round(leftCentre - width / 2);
		const top = rows.firstTop + i * pitch;
		const circled = new Set(word.circledPositions);
		return {
			fill: COLLAGE.rowFills[i % COLLAGE.rowFills.length],
			tiles: [...word.scrambled].map((letter, j) => ({
				letter,
				circled: circled.has(j + 1),
				x: left + j * (size + gap),
				y: top,
				size
			}))
		};
	});

	return {
		width: COLLAGE.width,
		height: COLLAGE.height,
		tileSize: size,
		instructions: COLLAGE.instructions.lines(words.length),
		rows: rowsOut,
		/** For the app: each square as fractions of the image, the way it stores boxes. */
		normalized: rowsOut.map((row) => row.tiles.map((t) => ({
			x: round(t.x / COLLAGE.width),
			y: round(t.y / COLLAGE.height),
			w: round(t.size / COLLAGE.width),
			h: round(t.size / COLLAGE.height),
			circled: t.circled
		})))
	};
}

/** The cartoon fitted inside its box, centred, proportions kept. */
function fitCartoon(cartoonWidth, cartoonHeight) {
	const box = COLLAGE.cartoonBox;
	const scale = Math.min(box.w / cartoonWidth, box.h / cartoonHeight);
	const w = Math.round(cartoonWidth * scale);
	const h = Math.round(cartoonHeight * scale);
	return { x: box.x + Math.round((box.w - w) / 2), y: box.y + Math.round((box.h - h) / 2), w, h, scale };
}

// ------------------------------------------------------------ answer strip

/**
 * The answer strip, as the admin's own answer images lay it out: the clue in
 * a playful font, then the empty answer boxes in their groups with the
 * printed punctuation round them — wrapped onto two lines at a group boundary
 * when one line would be too wide.
 */
const STRIP = {
	width: 1100,
	/** A long word (the Sunday Jumble's ten letters) widens the strip up to this. */
	maxWidth: 1600,
	margin: 30,
	clue: { size: 36, lineHeight: 44, top: 26, maxWidth: 1000 },
	box: { size: 96, gap: 14, radius: 12, border: 4 },
	/** Space between groups when only a space is printed there. */
	groupGap: 42,
	lineGap: 24,
	punctuation: { size: 64 },
	color: '#1A1A1A'
};

/**
 * @param {{groups: number[], prefix: string, betweenGroups: string[], suffix: string}} answer
 * @param {string[]} clueLines  the clue already wrapped
 * @param {(text: string, size: number) => number} measure  width of text in the strip's font
 */
function answerStripLayout(answer, clueLines, measure) {
	const { box } = STRIP;
	const groups = answer.groups;
	const between = answer.betweenGroups || [];
	const markWidth = (text) => {
		const t = String(text || '').trim();
		return t ? measure(t, STRIP.punctuation.size) + 12 : 0;
	};
	const groupWidth = (n) => n * box.size + (n - 1) * box.gap;
	/** Width of groups [from, to) on one line, with what is printed round them. */
	const lineWidth = (from, to) => {
		let w = 0;
		for (let g = from; g < to; g++) {
			w += groupWidth(groups[g]);
			if (g < to - 1) w += Math.max(STRIP.groupGap, markWidth(between[g]) + 16);
		}
		if (from === 0) w += markWidth(answer.prefix);
		if (to === groups.length) w += markWidth(answer.suffix);
		// A mark printed in the gap where the line breaks stays on the first line.
		if (to < groups.length) w += markWidth(between[to - 1]);
		return w;
	};

	const maxWidth = STRIP.width - 2 * STRIP.margin;
	let breakAt = groups.length;
	if (lineWidth(0, groups.length) > maxWidth && groups.length > 1) {
		// Two lines, split at a group boundary. A closing quotation mark ends a
		// phrase, and the newspaper never splits one: “□□□□ □” then □□□□.
		// Otherwise, the split that leaves the lines most even.
		const fits = (k) => lineWidth(0, k) <= maxWidth && lineWidth(k, groups.length) <= maxWidth;
		const closesQuote = (k) => /[”"’]/.test(String(between[k - 1] || ''));
		const splits = [];
		for (let k = 1; k < groups.length; k++) splits.push(k);
		const quoted = splits.filter((k) => closesQuote(k) && fits(k));
		const pool = quoted.length ? quoted : splits;
		let best = Infinity;
		for (const k of pool) {
			const widest = Math.max(lineWidth(0, k), lineWidth(k, groups.length));
			if (widest < best) { best = widest; breakAt = k; }
		}
	}
	const lines = breakAt === groups.length ? [[0, groups.length]] : [[0, breakAt], [breakAt, groups.length]];
	// A line still too wide (one long word) widens the strip rather than run off it.
	const widest = Math.max(...lines.map(([a, b]) => lineWidth(a, b)));
	const width = Math.min(STRIP.maxWidth, Math.max(STRIP.width, Math.ceil(widest + 2 * STRIP.margin)));
	const tooWide = widest > width - 2 * STRIP.margin;

	const clueHeight = clueLines.length * STRIP.clue.lineHeight;
	const firstBoxTop = STRIP.clue.top + clueHeight + 26;
	const boxes = [];
	const marks = [];
	lines.forEach(([from, to], li) => {
		const top = firstBoxTop + li * (box.size + STRIP.lineGap);
		let x = Math.round((width - lineWidth(from, to)) / 2);
		if (from === 0 && answer.prefix && answer.prefix.trim()) {
			marks.push({ text: answer.prefix.trim(), x, y: top });
			x += markWidth(answer.prefix);
		}
		for (let g = from; g < to; g++) {
			for (let i = 0; i < groups[g]; i++) {
				boxes.push({ group: g, x, y: top, size: box.size });
				x += box.size + (i < groups[g] - 1 ? box.gap : 0);
			}
			const mark = String(between[g] || '').trim();
			if (g < to - 1) {
				const gap = Math.max(STRIP.groupGap, markWidth(between[g]) + 16);
				if (mark) marks.push({ text: mark, x: x + 8, y: top });
				x += gap;
			} else if (g < groups.length - 1 && mark) {
				// The line breaks here: the mark closes this line.
				marks.push({ text: mark, x: x + 6, y: top });
			}
		}
		if (to === groups.length && answer.suffix && answer.suffix.trim()) {
			marks.push({ text: answer.suffix.trim(), x: x + 6, y: top });
		}
	});

	const height = firstBoxTop + lines.length * box.size + (lines.length - 1) * STRIP.lineGap + 28;
	return { width, height, clueLines, boxes, marks, lines: lines.length, tooWide };
}

/**
 * The clue as the strip prints it: the agent's sentence-case version when it
 * gave one that matches, otherwise the printed clue in plain sentence case;
 * the trailing dashes as one long dash.
 */
function stripClue(finalClue, sentenceCase) {
	const printed = String(finalClue || '').trim();
	const usable = sentenceCase && sentenceCase.toUpperCase() === printed.toUpperCase();
	let text = usable ? sentenceCase.trim() : sentenceCasePlain(printed);
	text = text.replace(/\s*[-‐-―]{2,}\s*$/, ' —');
	return text;
}

/** Lower case with a capital at each sentence start and on "I" — names cannot be known. */
function sentenceCasePlain(text) {
	const lower = text.toLowerCase();
	return lower
		.replace(/(^|[.!?]\s+)([a-z])/g, (m, before, letter) => before + letter.toUpperCase())
		.replace(/\bi\b/g, 'I');
}

/** Words of [text] into lines no wider than [maxWidth]. */
function wrapText(text, maxWidth, measure) {
	const words = text.split(/\s+/).filter(Boolean);
	const lines = [];
	let line = '';
	for (const word of words) {
		const next = line ? `${line} ${word}` : word;
		if (line && measure(next) > maxWidth) {
			lines.push(line);
			line = word;
		} else {
			line = next;
		}
	}
	if (line) lines.push(line);
	return lines;
}

const round = (n) => Math.round(n * 100000) / 100000;

module.exports = { COLLAGE, STRIP, collageLayout, fitCartoon, answerStripLayout, stripClue, sentenceCasePlain, wrapText };
