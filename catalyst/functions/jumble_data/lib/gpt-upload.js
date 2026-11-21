'use strict';

const crypto = require('crypto');
const { prepareUpload } = require('./upload');
const { defaultSlot } = require('./slots');
const { asBool } = require('./puzzle-views');

/**
 * Puzzles sent by the BluJem Custom GPT (a ChatGPT Action). It holds no
 * player or admin sign-in, only GPT_UPLOAD_KEY, so everything it sends is
 * stored as a draft: unpublished, never announced, never over a puzzle that
 * is already published. An admin checks it on the upload page and publishes
 * it from there.
 */

/** Whether [given] is the upload key; never true while the key is unset. */
function keyMatches(given, key) {
	const a = Buffer.from(String(given || ''));
	const b = Buffer.from(String(key || ''));
	return b.length > 0 && a.length === b.length && crypto.timingSafeEqual(a, b);
}

/**
 * Where ChatGPT hands over files: links on its own file hosts, valid for a
 * few minutes. Nothing else is fetched, so the key cannot be used to make the
 * server download from anywhere.
 */
const OPENAI_FILE_HOSTS = /(^|\.)(oaiusercontent\.com|openai\.com|oaistatic\.com)$/i;

function allowedImageUrl(link) {
	let url;
	try {
		url = new URL(String(link || ''));
	} catch (e) {
		return false;
	}
	return url.protocol === 'https:' && OPENAI_FILE_HOSTS.test(url.hostname);
}

/**
 * Where the cartoon comes from: the first file ChatGPT attached
 * (openaiFileIdRefs), else cartoonBase64. { problem } when neither is usable.
 */
function cartoonSource(body) {
	const refs = Array.isArray(body.openaiFileIdRefs) ? body.openaiFileIdRefs : [];
	const ref = refs.find((r) => r && (typeof r === 'string' || r.download_link));
	if (ref) {
		const link = typeof ref === 'string' ? ref : ref.download_link;
		if (!allowedImageUrl(link)) return { problem: 'The cartoon link must come from ChatGPT.' };
		return { url: link };
	}
	const base64 = String(body.cartoonBase64 || '');
	if (base64) return { base64 };
	return { problem: 'Attach the cartoon picture.' };
}

/**
 * The wordless cartoon (no bubbles or caption), for the share card: the
 * second file ChatGPT attached, else wordlessBase64. {} when none was sent.
 */
function wordlessSource(body) {
	const refs = Array.isArray(body.openaiFileIdRefs) ? body.openaiFileIdRefs.filter((r) => r && (typeof r === 'string' || r.download_link)) : [];
	const ref = refs[1];
	if (ref) {
		const link = typeof ref === 'string' ? ref : ref.download_link;
		if (!allowedImageUrl(link)) return { problem: 'The wordless cartoon link must come from ChatGPT.' };
		return { url: link };
	}
	const base64 = String(body.wordlessBase64 || '');
	return base64 ? { base64 } : {};
}

/**
 * The draft row to write, checked like an admin's upload — but the answers
 * are required, since the admin publishes it as it is.
 */
function prepareDraft(body) {
	const answers = body.answers || {};
	if (!Array.isArray(answers.words) || !String(answers.final || '').trim()) {
		return { problems: ['Send the answers too: every word and the final answer.'] };
	}
	const prepared = prepareUpload(body);
	if (prepared.problems.length) return prepared;
	return { ...prepared, values: { ...prepared.values, Published: 'false' }, warnings: [] };
}

/**
 * What a draft for [slot] does with the rows already on its date: refused
 * when the slot has a published puzzle, else replaces the slot's earlier
 * draft if there is one.
 */
function draftPlace(rows, date, slot) {
	const inSlot = rows.filter((r) => (r.Slot || defaultSlot(date)) === slot);
	if (inSlot.some((r) => asBool(r.Published))) {
		return { conflict: 'This slot already has a published puzzle. An admin can replace it on the upload page.' };
	}
	return { replace: inSlot[0] || null };
}

module.exports = { keyMatches, allowedImageUrl, cartoonSource, wordlessSource, prepareDraft, draftPlace };
