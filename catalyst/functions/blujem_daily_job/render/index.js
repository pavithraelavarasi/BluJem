'use strict';

/**
 * Draws the three BluJem images from an extraction and the source image —
 * deterministically, with nothing left to a model:
 *
 *   collage-letters.png   BluJem header, the word rows with the scrambled
 *                         letters in their squares, circles, the cartoon
 *   collage-blank.png     the same, every square empty, circles kept
 *   answer-strip.png      the clue and the empty answer boxes in their groups,
 *                         with the printed punctuation round them
 *   cartoon-original.png  the cartoon as cut from the source, untouched
 *
 * Only the scrambled letters are ever drawn: the extraction holds no answers.
 * The cartoon goes through [colorize] when one is given (a later step);
 * without it, the original is used.
 */

const path = require('path');
const fs = require('fs');
const { PassThrough, Readable } = require('stream');
const P = require('pureimage');
const L = require('./layout');
const { locateCartoon } = require('./cartoon');

const ASSETS = path.join(__dirname, '..', 'assets');
let fontsLoaded = false;
function loadFonts() {
	if (fontsLoaded) return;
	P.registerFont(path.join(ASSETS, 'fonts', 'Arimo-700.ttf'), 'ArimoBold').loadSync();
	P.registerFont(path.join(ASSETS, 'fonts', 'Arimo-400.ttf'), 'Arimo').loadSync();
	P.registerFont(path.join(ASSETS, 'fonts', 'ComicNeue-Bold.ttf'), 'ComicNeue').loadSync();
	fontsLoaded = true;
}

/** Darker than this counts as ink, for the checks. */
const INK = 110;

// ---------------------------------------------------------------- png i/o

async function decode(buffer) {
	const isPng = buffer[0] === 0x89 && buffer[1] === 0x50;
	const stream = Readable.from([buffer]);
	return isPng ? P.decodePNGFromStream(stream) : P.decodeJPEGFromStream(stream);
}

async function encodePng(bitmap) {
	const out = new PassThrough();
	const chunks = [];
	out.on('data', (c) => chunks.push(c));
	await P.encodePNGToStream(bitmap, out);
	return Buffer.concat(chunks);
}

let logoBitmap = null;
async function logo() {
	if (!logoBitmap) logoBitmap = await decode(fs.readFileSync(path.join(ASSETS, 'blujem-logo.png')));
	return logoBitmap;
}

// ---------------------------------------------------------------- drawing

/** A rounded rectangle as a path of short segments (the library's curves are unreliable). */
function roundRect(ctx, x, y, w, h, r) {
	const pts = [];
	const corner = (cx, cy, from) => {
		for (let i = 0; i <= 8; i++) {
			const a = from + (i * Math.PI) / 16;
			pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
		}
	};
	corner(x + w - r, y + r, -Math.PI / 2);
	corner(x + w - r, y + h - r, 0);
	corner(x + r, y + h - r, Math.PI / 2);
	corner(x + r, y + r, Math.PI);
	ctx.beginPath();
	ctx.moveTo(pts[0][0], pts[0][1]);
	for (const p of pts.slice(1)) ctx.lineTo(p[0], p[1]);
	ctx.closePath();
}

function centredText(ctx, text, centreX, baselineY) {
	const width = ctx.measureText(text).width;
	ctx.fillText(text, centreX - width / 2, baselineY);
}

async function drawCollage(layout, cartoon, fit, withLetters) {
	const C = L.COLLAGE;
	const img = P.make(C.width, C.height);
	const ctx = img.getContext('2d');
	ctx.fillStyle = '#FFFFFF';
	ctx.fillRect(0, 0, C.width, C.height);

	// Header: cream box, logo, byline, instructions.
	const H = C.header;
	roundRect(ctx, H.x, H.y, H.w, H.h, H.radius);
	ctx.fillStyle = H.fill;
	ctx.fill();
	const mark = await logo();
	const logoW = Math.round(mark.width * (C.logo.height / mark.height));
	ctx.drawImage(mark, 0, 0, mark.width, mark.height, C.logo.centreX - logoW / 2, C.logo.top, logoW, C.logo.height);
	ctx.fillStyle = C.textColor;
	ctx.font = `${C.byline.size}pt ArimoBold`;
	centredText(ctx, C.byline.text, C.leftCentre, C.byline.y);
	ctx.font = `${C.instructions.size}pt Arimo`;
	layout.instructions.forEach((line, i) => {
		centredText(ctx, line, C.leftCentre, C.instructions.firstY + i * C.instructions.lineHeight);
	});

	// Word rows.
	const T = C.tile;
	for (const row of layout.rows) {
		for (const tile of row.tiles) {
			const scale = tile.size / T.size;
			roundRect(ctx, tile.x, tile.y, tile.size, tile.size, T.radius * scale);
			ctx.fillStyle = row.fill;
			ctx.fill();
			ctx.lineWidth = T.border * scale;
			ctx.strokeStyle = C.letter.color;
			ctx.stroke();
			const cx = tile.x + tile.size / 2;
			const cy = tile.y + tile.size / 2;
			if (tile.circled) {
				ctx.beginPath();
				ctx.arc(cx, cy, tile.size / 2 - T.circleInset * scale, 0, Math.PI * 2);
				ctx.lineWidth = T.circleWidth * scale;
				ctx.stroke();
			}
			if (withLetters) {
				ctx.fillStyle = C.letter.color;
				ctx.font = `${Math.round(tile.size * C.letter.sizeRatio)}pt ArimoBold`;
				const m = ctx.measureText(tile.letter);
				// Cap height is about 0.72 of the font size: centre the capital.
				ctx.fillText(tile.letter, cx - m.width / 2, cy + tile.size * C.letter.sizeRatio * 0.36);
			}
		}
	}

	// Divider and cartoon.
	ctx.fillStyle = C.divider.color;
	ctx.fillRect(C.divider.x, 0, C.divider.width, C.height);
	ctx.drawImage(cartoon, 0, 0, cartoon.width, cartoon.height, fit.x, fit.y, fit.w, fit.h);
	return img;
}

function drawAnswerStrip(strip) {
	const S = L.STRIP;
	const img = P.make(strip.width, strip.height);
	const ctx = img.getContext('2d');
	ctx.fillStyle = '#FFFFFF';
	ctx.fillRect(0, 0, strip.width, strip.height);
	ctx.fillStyle = S.color;
	ctx.font = `${S.clue.size}pt ComicNeue`;
	strip.clueLines.forEach((line, i) => {
		centredText(ctx, line, strip.width / 2, S.clue.top + S.clue.size + i * S.clue.lineHeight);
	});
	for (const b of strip.boxes) {
		roundRect(ctx, b.x, b.y, b.size, b.size, S.box.radius);
		ctx.lineWidth = S.box.border;
		ctx.strokeStyle = S.color;
		ctx.stroke();
	}
	ctx.font = `${S.punctuation.size}pt ComicNeue`;
	for (const m of strip.marks) {
		// Quotation marks sit high, like printed ones; other marks mid-box.
		const high = /[“”"'‘’]/.test(m.text);
		ctx.fillText(m.text, m.x, m.y + (high ? S.punctuation.size * 0.85 : S.box.size * 0.7));
	}
	return img;
}

// ----------------------------------------------------------------- checks

function inkIn(bitmap, x0, y0, x1, y1) {
	let ink = 0;
	for (let y = Math.max(0, Math.floor(y0)); y < Math.min(bitmap.height, Math.ceil(y1)); y++) {
		for (let x = Math.max(0, Math.floor(x0)); x < Math.min(bitmap.width, Math.ceil(x1)); x++) {
			const i = (y * bitmap.width + x) * 4;
			const d = bitmap.data;
			if ((d[i] * 299 + d[i + 1] * 587 + d[i + 2] * 114) / 1000 < INK) ink++;
		}
	}
	return ink;
}

/** The quality checks on the drawn images. */
function check(layout, lettersImg, blankImg, crop, fit, strip) {
	const checks = [];
	const add = (code, ok, message) => checks.push({ code, ok, message });

	let blankLetters = 0;
	let missingLetters = 0;
	let circleErrors = 0;
	let clipped = 0;
	for (const row of layout.rows) {
		for (const t of row.tiles) {
			// The middle of a square: where a letter is, and never the circle.
			const a = t.size * 0.3;
			const b = t.size * 0.7;
			if (inkIn(blankImg, t.x + a, t.y + a, t.x + b, t.y + b) > 0) blankLetters++;
			if (inkIn(lettersImg, t.x + a, t.y + a, t.x + b, t.y + b) === 0) missingLetters++;
			// On the circle, at 45 degrees from the centre: ink only where circled.
			const r = t.size / 2 - L.COLLAGE.tile.circleInset * (t.size / L.COLLAGE.tile.size);
			const px = t.x + t.size / 2 + r * Math.SQRT1_2;
			const py = t.y + t.size / 2 + r * Math.SQRT1_2;
			const ringInk = inkIn(blankImg, px - 2, py - 2, px + 3, py + 3) > 0;
			if (ringInk !== t.circled) circleErrors++;
			if (t.x < 0 || t.y < 0 || t.x + t.size > L.COLLAGE.width || t.y + t.size > L.COLLAGE.height) clipped++;
		}
	}
	add('BLANK_HAS_NO_LETTERS', blankLetters === 0, `${blankLetters} blank square(s) have ink in the middle.`);
	add('LETTERS_PRESENT', missingLetters === 0, `${missingLetters} square(s) are missing their letter.`);
	add('CIRCLES_MATCH', circleErrors === 0, `${circleErrors} square(s) have a circle where there should be none, or none where there should be one.`);
	add('NOTHING_CLIPPED', clipped === 0 && !strip.tooWide, clipped
		? `${clipped} square(s) run off the collage.`
		: strip.tooWide ? 'The answer boxes do not fit the strip.' : 'Everything fits.');
	const sourceAspect = crop.w / crop.h;
	const drawnAspect = fit.w / fit.h;
	add('CARTOON_PROPORTIONS', Math.abs(drawnAspect / sourceAspect - 1) < 0.01,
		`Cartoon drawn at ${drawnAspect.toFixed(3)} for a source of ${sourceAspect.toFixed(3)}.`);
	add('CARTOON_FRAME_FOUND', crop.frameFound, crop.frameFound
		? 'The cartoon frame was found and kept whole.'
		: 'No cartoon frame found; the agent\'s box was used — check nothing is cut off.');
	add('CARTOON_READABLE', crop.h >= 400 && crop.w >= 300,
		`Cartoon cut at ${crop.w} × ${crop.h} px from the source.`);
	return checks;
}

// ------------------------------------------------------------------ entry

/**
 * @param {{
 *   extraction: object,           the validated extraction (toJSON form)
 *   sources: Buffer[],            the images the puzzle came in, in order
 *   colorize?: (png: Buffer) => Promise<Buffer|null>
 * }} input
 */
async function renderAssets({ extraction, sources, colorize }) {
	loadFonts();
	const cartoonInfo = extraction.cartoon || {};
	const index = Number.isInteger(cartoonInfo.imageIndex) && sources[cartoonInfo.imageIndex] ? cartoonInfo.imageIndex : 0;
	const source = await decode(sources[index]);

	const crop = locateCartoon(source, cartoonInfo.boundingBox);
	const original = P.make(crop.w, crop.h);
	original.getContext('2d').drawImage(source, crop.x, crop.y, crop.w, crop.h, 0, 0, crop.w, crop.h);
	const originalPng = await encodePng(original);

	let cartoon = original;
	let colorized = false;
	let colorizedPng = null;
	if (colorize) {
		colorizedPng = await colorize(originalPng);
		if (colorizedPng) {
			cartoon = await decode(colorizedPng);
			colorized = true;
		}
	}

	const layout = L.collageLayout(extraction.words);
	const fit = L.fitCartoon(cartoon.width, cartoon.height);
	const lettersImg = await drawCollage(layout, cartoon, fit, true);
	const blankImg = await drawCollage(layout, cartoon, fit, false);

	// The strip's clue, wrapped in its own font.
	const measureCtx = P.make(10, 10).getContext('2d');
	const measure = (text, size) => {
		measureCtx.font = `${size}pt ComicNeue`;
		return measureCtx.measureText(text).width;
	};
	const clue = L.stripClue(extraction.finalClue, extraction.finalClueSentenceCase);
	const clueLines = L.wrapText(clue, L.STRIP.clue.maxWidth, (t) => measure(t, L.STRIP.clue.size));
	const strip = L.answerStripLayout(extraction.finalAnswer, clueLines, measure);
	const stripImg = drawAnswerStrip(strip);

	const checks = check(layout, lettersImg, blankImg, crop, fit, strip);
	const files = {
		'cartoon-original.png': originalPng,
		'collage-letters.png': await encodePng(lettersImg),
		'collage-blank.png': await encodePng(blankImg),
		'answer-strip.png': await encodePng(stripImg)
	};
	if (colorizedPng) files['cartoon-colorized.png'] = colorizedPng;
	return {
		files,
		checks,
		ok: checks.every((c) => c.ok),
		colorized,
		clue,
		layout: {
			width: layout.width,
			height: layout.height,
			words: layout.normalized,
			cartoon: { x: fit.x / layout.width, y: fit.y / layout.height, w: fit.w / layout.width, h: fit.h / layout.height }
		},
		cartoonCrop: { sourceIndex: index, ...crop }
	};
}

module.exports = { renderAssets };
