'use strict';

const crypto = require('crypto');
const dns = require('dns');
const net = require('net');
const { PassThrough, Readable } = require('stream');
const { isIsoDate, indiaDate } = require('./india-date');

/**
 * Stores one day's puzzle image, as it came from its source, with the caller's
 * metadata — nothing is read, drawn or published here. In its own bucket:
 *
 *   blujem-daily (bucket)
 *     yyyy/MM/dd/source.png    the image, always PNG (a JPEG is converted)
 *     yyyy/MM/dd/puzzle.json   puzzleDate, sourceUrl, the image's facts, metadata
 *
 * Storing a day again replaces both files.
 */

const DEFAULT_BUCKET = 'blujem-sources';
/** Large enough for a full newspaper page scan, small enough to stay in a request. */
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const MAX_METADATA_BYTES = 64 * 1024;
const DOWNLOAD_TIMEOUT_MS = 15 * 1000;
const MAX_REDIRECTS = 3;

const bucketName = () => (process.env.BLUJEM_DAILY_BUCKET || DEFAULT_BUCKET).trim();

class StoreError extends Error {
	constructor(code, message, http) {
		super(message);
		this.code = code;
		this.http = http;
	}
}

const isPng = (b) => b.length > 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47;
const isJpeg = (b) => b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff;

/** yyyy/MM/dd for a yyyy-MM-dd date. */
const dayPath = (date) => date.replace(/-/g, '/');

/** An http(s) URL, or a StoreError INVALID_URL naming [field]. */
function parseUrl(value, field) {
	let url;
	try { url = new URL(String(value)); } catch (e) { url = null; }
	if (!url || !['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
		throw new StoreError('INVALID_URL', `${field} must be an http(s) URL.`, 400);
	}
	return url;
}

/** Addresses the function must never fetch: loopback, private, link-local, metadata. */
function isPrivateAddress(address) {
	if (net.isIPv4(address)) {
		const [a, b] = address.split('.').map(Number);
		return a === 0 || a === 10 || a === 127 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31)
			|| (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224;
	}
	const v6 = address.toLowerCase();
	if (v6.startsWith('::ffff:')) return isPrivateAddress(v6.slice(7));
	return v6 === '::' || v6 === '::1' || v6.startsWith('fc') || v6.startsWith('fd') || v6.startsWith('fe80');
}

async function checkHost(deps, url) {
	const host = url.hostname.replace(/^\[|\]$/g, '');
	let addresses;
	try {
		addresses = net.isIP(host) ? [{ address: host }] : await deps.lookup(host, { all: true });
	} catch (e) {
		throw new StoreError('DOWNLOAD_FAILED', `Could not resolve ${host}.`, 502);
	}
	if (!addresses.length || addresses.some((a) => isPrivateAddress(a.address))) {
		throw new StoreError('INVALID_URL', 'imageUrl must point to a public host.', 400);
	}
}

/** The image at [imageUrl], following at most a few redirects, each to a public host. */
async function download(deps, imageUrl) {
	let url = parseUrl(imageUrl, 'imageUrl');
	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), DOWNLOAD_TIMEOUT_MS);
	try {
		for (let hop = 0; ; hop++) {
			await checkHost(deps, url);
			let res;
			try {
				res = await deps.fetch(url, { redirect: 'manual', signal: controller.signal, headers: { accept: 'image/png,image/jpeg' } });
			} catch (e) {
				throw new StoreError('DOWNLOAD_FAILED', controller.signal.aborted ? 'The image download timed out.' : 'The image could not be downloaded.', 502);
			}
			if (res.status >= 300 && res.status < 400 && res.headers.get('location')) {
				if (hop >= MAX_REDIRECTS) throw new StoreError('DOWNLOAD_FAILED', 'Too many redirects.', 502);
				url = parseUrl(new URL(res.headers.get('location'), url).href, 'imageUrl redirect');
				continue;
			}
			if (!res.ok) throw new StoreError('DOWNLOAD_FAILED', `The image URL answered HTTP ${res.status}.`, 502);
			if (Number(res.headers.get('content-length')) > MAX_IMAGE_BYTES) throw tooLarge();

			const chunks = [];
			let size = 0;
			try {
				for await (const chunk of res.body) {
					size += chunk.length;
					if (size > MAX_IMAGE_BYTES) {
						controller.abort();
						throw tooLarge();
					}
					chunks.push(Buffer.from(chunk));
				}
			} catch (e) {
				if (e instanceof StoreError) throw e;
				throw new StoreError('DOWNLOAD_FAILED', 'The image download was cut off.', 502);
			}
			return Buffer.concat(chunks);
		}
	} finally {
		clearTimeout(timer);
	}
}

const tooLarge = () => new StoreError('IMAGE_TOO_LARGE', `The image is over ${MAX_IMAGE_BYTES / 1024 / 1024} MB.`, 413);

/** [bytes] as PNG: a PNG as it is, a JPEG re-encoded; anything else is refused. */
async function toPng(bytes) {
	if (isPng(bytes)) return { png: bytes, originalFormat: 'png' };
	if (!isJpeg(bytes)) throw new StoreError('NOT_AN_IMAGE', 'The image must be a PNG or a JPEG.', 400);
	try {
		const PImage = require('pureimage');
		const bitmap = await PImage.decodeJPEGFromStream(Readable.from([bytes]));
		const out = new PassThrough();
		const chunks = [];
		out.on('data', (c) => chunks.push(c));
		await PImage.encodePNGToStream(bitmap, out);
		return { png: Buffer.concat(chunks), originalFormat: 'jpeg', width: bitmap.width, height: bitmap.height };
	} catch (e) {
		throw new StoreError('NOT_AN_IMAGE', 'The JPEG could not be read.', 400);
	}
}

/** Width and height from a PNG's header. */
const pngSize = (png) => ({ width: png.readUInt32BE(16), height: png.readUInt32BE(20) });

/** Checks the request, before anything is downloaded or stored. */
function checkRequest(body) {
	const puzzleDate = String(body.puzzleDate || '').trim();
	if (!isIsoDate(puzzleDate)) throw new StoreError('BAD_PUZZLE_DATE', 'puzzleDate must be a real date, yyyy-MM-dd.', 400);
	// A puzzle is never for a day after tomorrow in India.
	const tomorrow = indiaDate(new Date(Date.now() + 24 * 3600 * 1000));
	if (puzzleDate > tomorrow || puzzleDate < '2000-01-01') {
		throw new StoreError('BAD_PUZZLE_DATE', `puzzleDate must be on or before ${tomorrow}.`, 400);
	}

	const sourceUrl = body.sourceUrl ? parseUrl(body.sourceUrl, 'sourceUrl').href : null;

	const hasUrl = typeof body.imageUrl === 'string' && body.imageUrl.trim() !== '';
	const hasBytes = typeof body.imageBase64 === 'string' && body.imageBase64.trim() !== '';
	if (!hasUrl && !hasBytes) throw new StoreError('MISSING_IMAGE', 'Send imageUrl or imageBase64.', 400);
	if (hasUrl && hasBytes) throw new StoreError('MISSING_IMAGE', 'Send imageUrl or imageBase64, not both.', 400);
	if (hasUrl) parseUrl(body.imageUrl.trim(), 'imageUrl');

	const metadata = body.metadata === undefined || body.metadata === null ? {} : body.metadata;
	if (typeof metadata !== 'object' || Array.isArray(metadata)) {
		throw new StoreError('BAD_METADATA', 'metadata must be a JSON object.', 400);
	}
	if (Buffer.byteLength(JSON.stringify(metadata)) > MAX_METADATA_BYTES) {
		throw new StoreError('BAD_METADATA', `metadata is over ${MAX_METADATA_BYTES / 1024} KB.`, 400);
	}
	return {
		puzzleDate,
		sourceUrl,
		imageUrl: hasUrl ? body.imageUrl.trim() : null,
		imageBase64: hasBytes ? body.imageBase64.replace(/^data:image\/[a-z]+;base64,/, '').trim() : null,
		metadata
	};
}

async function put(app, key, bytes, contentType) {
	try {
		await app.stratus().bucket(bucketName()).putObject(key, Readable.from([bytes]), { overwrite: true, contentType });
	} catch (e) {
		console.error('store-daily-puzzle: Stratus refused', key, e && e.message);
		throw new StoreError('STRATUS_UPLOAD_FAILED', `Could not store ${key}.`, 502);
	}
	return key;
}

/**
 * Downloads (or decodes) the image, stores it and its puzzle.json, and gives
 * { status: success, imageKey, metadataKey }. Throws StoreError on a bad request
 * or a failed download or upload.
 */
async function storeDailyPuzzle(deps, app, body, storedBy) {
	const request = checkRequest(body);

	let bytes;
	if (request.imageUrl) {
		bytes = await download(deps, request.imageUrl);
	} else {
		bytes = Buffer.from(request.imageBase64, 'base64');
		if (bytes.length > MAX_IMAGE_BYTES) throw tooLarge();
	}
	if (!bytes.length) throw new StoreError('MISSING_IMAGE', 'The image is empty.', 400);

	const { png, originalFormat } = await toPng(bytes);
	const folder = dayPath(request.puzzleDate);
	const imageKey = await put(app, `${folder}/source.png`, png, 'image/png');

	const record = {
		puzzleDate: request.puzzleDate,
		sourceUrl: request.sourceUrl,
		imageUrl: request.imageUrl,
		image: {
			key: imageKey,
			contentType: 'image/png',
			originalFormat,
			bytes: png.length,
			...pngSize(png),
			sha256: crypto.createHash('sha256').update(png).digest('hex')
		},
		storedAt: new Date().toISOString(),
		storedBy,
		metadata: request.metadata
	};
	const metadataKey = await put(app, `${folder}/puzzle.json`, Buffer.from(JSON.stringify(record, null, 2)), 'application/json');
	return { status: 'success', imageKey, metadataKey };
}

const realDeps = {
	fetch: (...args) => fetch(...args),
	lookup: (host, opts) => dns.promises.lookup(host, opts)
};

module.exports = {
	storeDailyPuzzle, checkRequest, isPrivateAddress, StoreError, realDeps,
	DEFAULT_BUCKET, MAX_IMAGE_BYTES
};
