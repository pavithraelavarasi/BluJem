'use strict';

/**
 * The Android app's own updates, without an app store: the release APK and a
 * latest.json describing it sit in the project's Stratus bucket, the app asks
 * on start whether there is a newer one, and downloads it from a short-lived
 * signed link.
 *
 *   dailyjumble (bucket)
 *     releases/android/BluJem-1.15.apk
 *     releases/android/latest.json   { versionCode, versionName, notes, sha256, size, key, publishedAt }
 *
 * An admin publishes a release in two steps (tools/publish_update.sh does both):
 * ask for an upload link, PUT the APK to it, then publish its details. Only a
 * published release is ever offered, so a half-finished upload is never seen.
 */

const DEFAULT_BUCKET = 'blujem';
const PREFIX = 'releases/android';
const LATEST = `${PREFIX}/latest.json`;
/** Long enough to download 40 MB on a slow line; short enough not to be passed around. */
const DOWNLOAD_LINK_SECONDS = 3600;
const UPLOAD_LINK_SECONDS = 900;

const bucket = (app) => app.stratus().bucket((process.env.RELEASE_BUCKET || DEFAULT_BUCKET).trim());

class ReleaseError extends Error {
	constructor(code, message, http) {
		super(message);
		this.code = code;
		this.http = http;
	}
}

/** "1.15" style: digits and dots only, so it is safe in an object key. */
function checkVersion(body) {
	const versionCode = Number(body.versionCode);
	const versionName = String(body.versionName || '').trim();
	if (!Number.isInteger(versionCode) || versionCode < 1) {
		throw new ReleaseError('BAD_VERSION', 'versionCode must be a whole number above 0.', 400);
	}
	if (!/^\d+(\.\d+){0,3}$/.test(versionName)) {
		throw new ReleaseError('BAD_VERSION', 'versionName must look like 1.15.', 400);
	}
	return { versionCode, versionName, key: `${PREFIX}/BluJem-${versionName}.apk` };
}

/** A signed link's URL, whatever the SDK names the field. */
const linkOf = (res) => (res && (res.signature || res.url || res.signed_url)) || null;

async function readLatest(app) {
	try {
		const chunks = [];
		for await (const chunk of await bucket(app).getObject(LATEST)) chunks.push(Buffer.from(chunk));
		return JSON.parse(Buffer.concat(chunks).toString('utf8'));
	} catch (e) {
		return null;
	}
}

/** The newest published release, with a link to download it; versionCode 0 when there is none. */
async function latest(app) {
	const release = await readLatest(app);
	if (!release) return { versionCode: 0 };
	const link = await bucket(app).generatePreSignedUrl(release.key, 'GET', { expiryIn: String(DOWNLOAD_LINK_SECONDS) });
	const apkUrl = linkOf(link);
	if (!apkUrl) throw new ReleaseError('NO_LINK', 'No download link could be made.', 502);
	return {
		versionCode: release.versionCode,
		versionName: release.versionName,
		notes: release.notes || '',
		sha256: release.sha256,
		size: release.size,
		publishedAt: release.publishedAt,
		apkUrl
	};
}

/** A link to PUT the APK for a new version to. */
async function uploadUrl(app, body) {
	const { versionCode, versionName, key } = checkVersion(body);
	const current = await readLatest(app);
	if (current && versionCode <= current.versionCode) {
		throw new ReleaseError('NOT_NEWER', `versionCode must be above the published ${current.versionCode}.`, 409);
	}
	const link = await bucket(app).generatePreSignedUrl(key, 'PUT', { expiryIn: String(UPLOAD_LINK_SECONDS) });
	const uploadUrl = linkOf(link);
	if (!uploadUrl) throw new ReleaseError('NO_LINK', 'No upload link could be made.', 502);
	return { key, uploadUrl, expiresInSeconds: UPLOAD_LINK_SECONDS };
}

/** Offers the uploaded APK to every app: writes latest.json. */
async function publish(app, body, publishedBy) {
	const { versionCode, versionName, key } = checkVersion(body);
	const sha256 = String(body.sha256 || '').toLowerCase();
	const size = Number(body.size);
	if (!/^[0-9a-f]{64}$/.test(sha256)) throw new ReleaseError('BAD_CHECKSUM', 'sha256 must be 64 hex digits.', 400);
	if (!Number.isInteger(size) || size < 1) throw new ReleaseError('BAD_SIZE', 'size must be the APK size in bytes.', 400);

	const current = await readLatest(app);
	if (current && versionCode <= current.versionCode) {
		throw new ReleaseError('NOT_NEWER', `versionCode must be above the published ${current.versionCode}.`, 409);
	}
	// The APK must really be there, at the size given, before anyone is sent to it.
	let stored = null;
	try {
		const page = await bucket(app).listPagedObjects({ prefix: key, maxKeys: '10' });
		stored = (page.contents || []).map((o) => (o.toJSON ? o.toJSON() : o)).find((o) => o.key === key) || null;
	} catch (e) {
		stored = null;
	}
	if (!stored) throw new ReleaseError('APK_MISSING', `Upload ${key} first.`, 409);
	if (stored.size !== undefined && Number(stored.size) !== size) {
		throw new ReleaseError('APK_MISMATCH', `The stored APK is ${stored.size} bytes, not ${size}.`, 409);
	}

	const release = {
		versionCode,
		versionName,
		notes: String(body.notes || '').slice(0, 1000),
		sha256,
		size,
		key,
		publishedAt: new Date().toISOString(),
		publishedBy
	};
	const { Readable } = require('stream');
	await bucket(app).putObject(LATEST, Readable.from([Buffer.from(JSON.stringify(release, null, 2))]), {
		overwrite: true,
		contentType: 'application/json'
	});
	return { status: 'success', ...release };
}

module.exports = { latest, uploadUrl, publish, checkVersion, ReleaseError, LATEST, PREFIX };
