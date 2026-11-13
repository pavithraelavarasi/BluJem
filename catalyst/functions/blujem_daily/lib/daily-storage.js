'use strict';

const { Readable } = require('stream');

/**
 * Where each day's daily-puzzle files live: the project's existing Stratus
 * bucket (jumble_data keeps sheets in it under sheets/), under
 *
 *   blujem-daily/yyyy/MM/dd/
 *     source-1.png …          the image(s) the puzzle came in
 *     cartoon-original.png    the cartoon as cut from the source
 *     collage-letters.png     the BluJem collage, letters in the squares
 *     collage-blank.png       the same, squares empty
 *     answer-strip.png        the clue and empty answer boxes
 *     puzzle.json             the record: status, extraction, checks, file keys
 *
 * A day processed again replaces that day's files: the latest run is the one
 * the admin reviews.
 */

const DEFAULT_BUCKET = 'blujem';
const PREFIX = 'blujem-daily';

const bucketName = () => (process.env.DAILY_BUCKET || DEFAULT_BUCKET).trim();
const bucket = (app) => app.stratus().bucket(bucketName());

/** blujem-daily/yyyy/MM/dd for a yyyy-MM-dd date. */
function dayFolder(date) {
	const [y, m, d] = String(date).split('-');
	return `${PREFIX}/${y}/${m}/${d}`;
}

/** Only keys under the daily folder may be read back through the API. */
function isDailyKey(key) {
	return typeof key === 'string' && key.startsWith(`${PREFIX}/`) && !key.includes('..');
}

const contentTypeOf = (key) => (key.endsWith('.json') ? 'application/json'
	: key.endsWith('.jpg') || key.endsWith('.jpeg') ? 'image/jpeg' : 'image/png');

async function put(app, key, bytes) {
	await bucket(app).putObject(key, Readable.from([Buffer.from(bytes)]), {
		overwrite: true,
		contentType: contentTypeOf(key)
	});
	return key;
}

/** An object's bytes. */
async function read(app, key) {
	const stream = await bucket(app).getObject(key);
	const chunks = [];
	for await (const chunk of stream) chunks.push(Buffer.from(chunk));
	return Buffer.concat(chunks);
}

/** Saves the source image(s) for [date] and gives their keys, in order. */
async function saveSources(app, date, images) {
	const keys = [];
	for (const [i, image] of images.entries()) {
		const ext = image.data[0] === 0x89 && image.data[1] === 0x50 ? 'png' : 'jpg';
		keys.push(await put(app, `${dayFolder(date)}/source-${i + 1}.${ext}`, image.data));
	}
	return keys;
}

/** Saves the drawn files for [date]; gives { fileName: key }. */
async function saveAssets(app, date, files) {
	const keys = {};
	for (const [name, bytes] of Object.entries(files)) {
		keys[name] = await put(app, `${dayFolder(date)}/${name}`, bytes);
	}
	return keys;
}

/** Saves [record] as the day's puzzle.json. */
async function savePuzzle(app, date, record) {
	return put(app, `${dayFolder(date)}/puzzle.json`, JSON.stringify(record, null, 2));
}

/** The stored days' records, newest first. */
async function listPuzzles(app, limit = 30) {
	const keys = [];
	let token;
	do {
		const page = await bucket(app).listPagedObjects({
			prefix: `${PREFIX}/`,
			maxKeys: '1000',
			...(token ? { continuationToken: token } : {})
		});
		for (const item of page.contents || []) {
			const key = item.key || (item.toJSON && item.toJSON().key);
			if (key && key.endsWith('/puzzle.json')) keys.push(key);
		}
		token = page.truncated === 'true' || page.truncated === true ? page.next_continuation_token : undefined;
	} while (token);

	keys.sort().reverse();
	const records = [];
	for (const key of keys.slice(0, limit)) {
		try {
			records.push(JSON.parse((await read(app, key)).toString('utf8')));
		} catch (error) {
			console.error('daily list: unreadable', key, error && error.message);
		}
	}
	return records;
}

module.exports = { dayFolder, isDailyKey, read, saveSources, saveAssets, savePuzzle, listPuzzles, PREFIX, DEFAULT_BUCKET };
