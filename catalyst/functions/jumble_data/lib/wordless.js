'use strict';

/**
 * The wordless cartoon: the same drawing with no speech bubbles or caption,
 * which the app puts on the "share your win" card — it makes friends curious
 * without giving the pun away. It is optional and lives in Stratus beside the
 * cartoon, its key the cartoon's with "-wordless.png" for the extension, so
 * no table needs a new column:
 *
 *   puzzles/2026-11-22/morning/cartoon.png → puzzles/2026-11-22/morning/cartoon-wordless.png
 *   sheets/abc-cartoon.jpg                 → sheets/abc-cartoon-wordless.png
 *
 * The app's twin is wordlessKey in lib/models/puzzle.dart.
 */

const SUFFIX = '-wordless.png';

/** Where the wordless picture of the cartoon at [sheetKey] goes; '' when there is no cartoon. */
function wordlessKey(sheetKey) {
	const key = String(sheetKey || '').trim();
	return key ? key.replace(/\.[^./]+$/, '') + SUFFIX : '';
}

function isWordlessKey(key) {
	return String(key || '').endsWith(SUFFIX);
}

/** The cartoon keys a wordless key can belong to, for checking that its puzzle is out. */
function cartoonKeysFor(key) {
	const base = String(key).slice(0, -SUFFIX.length);
	return ['.png', '.jpg', '.jpeg'].map((ext) => base + ext);
}

module.exports = { wordlessKey, isWordlessKey, cartoonKeysFor };
