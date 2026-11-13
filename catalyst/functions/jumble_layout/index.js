'use strict';

// Asks the Zia layout agent where everything is on an uploaded sheet: each
// scrambled word's answer squares, which of them are circled, and the answer
// row. The agent takes about half a minute — longer than an Advanced I/O
// function may run — so jumble_ai hands the work to this job and the admin's
// phone collects the result from the cache when it is done.
//
// Players never come here. The layout is detected once, at upload, and stored
// with the sheet as fractions of the image; every phone draws it from those.

const catalyst = require('zcatalyst-sdk-node');
const { validateLayout } = require('./layout');

const ACCOUNTS = process.env.ZIA_AGENT_ACCOUNTS || 'https://accounts.zoho.in';
const AGENT_TIMEOUT_MS = 150 * 1000;

/** A Zoho access token from the Self Client refresh token, as jumble_ai makes one. */
async function accessToken() {
	const params = new URLSearchParams({
		refresh_token: process.env.ZIA_AGENT_REFRESH_TOKEN,
		client_id: process.env.ZIA_AGENT_CLIENT_ID,
		client_secret: process.env.ZIA_AGENT_CLIENT_SECRET,
		grant_type: 'refresh_token'
	});
	const reply = await fetch(`${ACCOUNTS}/oauth/v2/token?${params}`, { method: 'POST' });
	const json = await reply.json().catch(() => ({}));
	if (!json.access_token) {
		const error = new Error(`token refused: ${json.error || reply.status}`);
		error.reason = 'unauthorized';
		throw error;
	}
	return json.access_token;
}

/** The first {...} in [text], parsed — the agent wraps its JSON in a code fence. */
function jsonIn(text) {
	const start = String(text || '').indexOf('{');
	const end = String(text || '').lastIndexOf('}');
	if (start === -1 || end <= start) return null;
	try { return JSON.parse(text.slice(start, end + 1)); } catch (e) { return null; }
}

/** The agent's layout for the uploaded file [fileId], checked, or a reason it is not usable. */
async function detect(fileId) {
	const url = process.env.ZIA_LAYOUT_AGENT_URL;
	if (!url) return { status: 'failed', reason: 'not_configured' };

	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), AGENT_TIMEOUT_MS);
	try {
		const reply = await fetch(url, {
			method: 'POST',
			headers: {
				'Authorization': `Zoho-oauthtoken ${await accessToken()}`,
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({
				query: 'Detect the layout of this Jumble sheet.',
				attachments: [fileId]
			}),
			signal: controller.signal
		});
		const json = await reply.json().catch(() => ({}));
		if (reply.status === 401 || reply.status === 403) {
			console.error('Layout agent refused the call:', reply.status, JSON.stringify(json).slice(0, 300));
			return { status: 'failed', reason: 'unauthorized' };
		}
		if (!reply.ok) {
			console.error('Layout agent failed:', reply.status, JSON.stringify(json).slice(0, 300));
			return { status: 'failed', reason: 'unavailable' };
		}
		const text = json && json.data && json.data.response;
		const checked = validateLayout(typeof text === 'string' ? jsonIn(text) : null);
		if (!checked.layout) {
			console.error('Layout agent reply rejected:', checked.problems.join('; '), String(text).slice(0, 300));
			return { status: 'failed', reason: 'invalid', problems: checked.problems };
		}
		return { status: 'done', layout: checked.layout, warnings: checked.warnings };
	} catch (error) {
		if (error.name === 'AbortError') return { status: 'failed', reason: 'timeout' };
		console.error('Layout agent call failed:', error);
		return { status: 'failed', reason: error.reason || 'unavailable' };
	} finally {
		clearTimeout(timer);
	}
}

/**
 * @param {import("./types/job").JobRequest} jobRequest
 * @param {import("./types/job").Context} context
 */
module.exports = async (jobRequest, context) => {
	const requestId = String(jobRequest.getJobParam('requestId') || '');
	const fileId = String(jobRequest.getJobParam('fileId') || '');
	try {
		const app = catalyst.initialize(context, { scope: 'admin' });
		const result = requestId && fileId
			? await detect(fileId)
			: { status: 'failed', reason: 'invalid' };
		if (requestId) {
			await app.cache().segment(process.env.LAYOUT_CACHE_SEGMENT_ID)
				.put(`layout_${requestId}`, JSON.stringify(result), 1);
		}
		context.closeWithSuccess();
	} catch (error) {
		console.error('Layout job failed:', error);
		context.closeWithFailure();
	}
};
