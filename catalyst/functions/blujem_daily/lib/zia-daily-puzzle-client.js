'use strict';

/**
 * Talks to the BluJem Daily Puzzle Processor agent in Zia Agents.
 *
 * Every detail of the HTTP contract here is the one jumble_ai already uses
 * with the hint, sheet and layout agents, which work in production:
 *
 *   1. An access token from Zoho Accounts, by the refresh-token grant:
 *      POST {accounts}/oauth/v2/token?refresh_token&client_id&client_secret&grant_type=refresh_token
 *   2. The image uploaded for the agent to be shown:
 *      POST {agentBase}/ziaagents/api/v1/files  (multipart: file, fileName)
 *      headers: Authorization: Zoho-oauthtoken …, X-ZIAAGENTS-ORG (when set)
 *      → { data: { fileId } }
 *   3. The agent run, at its trigger URL from the agent's Integrate tab:
 *      POST {triggerUrl}  { query, attachments: [fileId] }
 *      headers: Authorization: Zoho-oauthtoken …, Content-Type: application/json
 *      → { data: { response: "<the agent's text>" } }
 *
 * Nothing about the request is invented beyond that. Credentials come only from
 * the function's environment and are never logged.
 */

class ZiaClientError extends Error {
	/**
	 * @param {'ZIA_NOT_CONFIGURED'|'ZIA_UNAUTHORIZED'|'ZIA_TIMEOUT'|'ZIA_UPLOAD_FAILED'|'ZIA_CALL_FAILED'|'ZIA_EMPTY_RESPONSE'|'INVALID_JSON'} code
	 */
	constructor(code, message, details) {
		super(message);
		this.name = 'ZiaClientError';
		this.code = code;
		/** Safe to log and to return: never a credential. */
		this.details = details;
	}
}

/** The environment variable each setting is read from. */
const ENV = {
	triggerUrl: 'ZIA_DAILY_AGENT_URL',
	agentBase: 'ZIA_AGENT_BASE',
	accounts: 'ZIA_AGENT_ACCOUNTS',
	orgId: 'ZIA_AGENT_ORG_ID',
	clientId: 'ZIA_AGENT_CLIENT_ID',
	clientSecret: 'ZIA_AGENT_CLIENT_SECRET',
	refreshToken: 'ZIA_AGENT_REFRESH_TOKEN',
	timeoutMs: 'ZIA_DAILY_TIMEOUT_MS'
};

class ZiaDailyPuzzleClient {
	/**
	 * @param {{
	 *   triggerUrl?: string, agentBase?: string, accounts?: string, orgId?: string,
	 *   clientId?: string, clientSecret?: string, refreshToken?: string,
	 *   timeoutMs?: number, fetchImpl?: typeof fetch
	 * }} config
	 */
	constructor(config = {}) {
		this.triggerUrl = config.triggerUrl || '';
		this.agentBase = config.agentBase || 'https://ziaagents.zoho.in';
		this.accounts = config.accounts || 'https://accounts.zoho.in';
		this.orgId = config.orgId || '';
		this.clientId = config.clientId || '';
		this.clientSecret = config.clientSecret || '';
		this.refreshToken = config.refreshToken || '';
		// A Catalyst Advanced I/O function is stopped at 30 seconds, so the
		// agent gets 25 of them there; the command-line test can wait longer.
		this.timeoutMs = Number(config.timeoutMs) || 25000;
		this.fetch = config.fetchImpl || fetch;
		this.token = null;
		this.tokenExpires = 0;
	}

	/** A client set up from the function's environment variables. */
	static fromEnv(env = process.env, overrides = {}) {
		// Trimmed: a value pasted into the console with a stray space round it
		// would otherwise be a wrong URL or a refused credential.
		const read = (name) => (typeof env[name] === 'string' ? env[name].trim() : env[name]);
		return new ZiaDailyPuzzleClient({
			triggerUrl: read(ENV.triggerUrl),
			agentBase: read(ENV.agentBase),
			accounts: read(ENV.accounts),
			orgId: read(ENV.orgId),
			clientId: read(ENV.clientId),
			clientSecret: read(ENV.clientSecret),
			refreshToken: read(ENV.refreshToken),
			timeoutMs: read(ENV.timeoutMs),
			...overrides
		});
	}

	/** The names of settings still missing, for a clear "not configured" error. */
	missingSettings() {
		const missing = [];
		if (!this.triggerUrl) missing.push(ENV.triggerUrl);
		if (!this.clientId) missing.push(ENV.clientId);
		if (!this.clientSecret) missing.push(ENV.clientSecret);
		if (!this.refreshToken) missing.push(ENV.refreshToken);
		return missing;
	}

	/**
	 * Runs the agent on one puzzle and gives back its JSON, parsed: the images
	 * uploaded, then the agent asked. For a caller that can wait the minute or
	 * two the agent takes — the command-line test, or the background job.
	 *
	 * The puzzle may come as one image or as the separate pieces the source
	 * page shows — word rows, cartoon, answer boxes — and every piece goes to
	 * the agent in the same call, so it reads them as one puzzle.
	 *
	 * @param {{images: {data: Buffer, fileName?: string, mimeType?: string}[], expectedDate: string, sourceUrl?: string}} input
	 * @returns {Promise<{json: object, text: string}>}
	 * @throws {ZiaClientError}
	 */
	async extract({ images, expectedDate, sourceUrl }) {
		const fileIds = await this.uploadAll(images, expectedDate);
		return this.run({ fileIds, expectedDate, sourceUrl });
	}

	/**
	 * Uploads every image for the agent and gives their file ids, in order.
	 * Quick — a few seconds — so it fits in a request that must answer in 30.
	 *
	 * @param {{data: Buffer, fileName?: string, mimeType?: string}[]} images
	 * @returns {Promise<string[]>}
	 */
	async uploadAll(images, expectedDate) {
		this.requireSettings();
		const fileIds = [];
		for (const [i, image] of images.entries()) {
			const type = image.mimeType || sniffMimeType(image.data);
			const name = image.fileName || `jumble_${expectedDate}_${i + 1}.${type === 'image/png' ? 'png' : 'jpg'}`;
			fileIds.push(await this.upload(image.data, name, type));
		}
		return fileIds;
	}

	/**
	 * Asks the agent to read the already-uploaded images [fileIds]. Slow — the
	 * agent takes a minute or two — so the live pipeline runs it in a job.
	 *
	 * @returns {Promise<{json: object, text: string}>}
	 * @throws {ZiaClientError}
	 */
	async run({ fileIds, expectedDate, sourceUrl }) {
		this.requireSettings();
		const query = [
			fileIds.length === 1
				? 'Extract the Daily Jumble in the attached image.'
				: `Extract the Daily Jumble from the ${fileIds.length} attached images: together they are one puzzle ` +
					'(word rows, cartoon and answer boxes, shown separately).',
			`Expected date (Asia/Kolkata): ${expectedDate}.`,
			`Source: Hindustan Times Daily Jumble${sourceUrl ? ` (${sourceUrl})` : ''}.`,
			'Answer with the JSON object only.'
		].join(' ');

		const reply = await this.call(this.triggerUrl, {
			method: 'POST',
			headers: {
				'Authorization': `Zoho-oauthtoken ${await this.accessToken()}`,
				'Content-Type': 'application/json'
			},
			body: JSON.stringify({ query, attachments: fileIds })
		});
		const body = await reply.json().catch(() => ({}));
		if (reply.status === 401 || reply.status === 403) {
			this.token = null;
			throw new ZiaClientError('ZIA_UNAUTHORIZED', `The agent refused the call (${reply.status}).`, { status: reply.status });
		}
		if (!reply.ok) {
			throw new ZiaClientError('ZIA_CALL_FAILED', `The agent call failed (${reply.status}).`, {
				status: reply.status, body: JSON.stringify(body).slice(0, 300)
			});
		}
		const text = body && body.data && body.data.response;
		if (typeof text !== 'string' || !text.trim()) {
			throw new ZiaClientError('ZIA_EMPTY_RESPONSE', 'The agent sent no response text.', {
				body: JSON.stringify(body).slice(0, 300)
			});
		}
		const json = jsonIn(text);
		if (!json) {
			throw new ZiaClientError('INVALID_JSON', 'The agent did not answer with JSON.', { text: text.slice(0, 300) });
		}
		return { json, text };
	}

	/** Throws ZIA_NOT_CONFIGURED, naming what is missing, before any call. */
	requireSettings() {
		const missing = this.missingSettings();
		if (missing.length) {
			throw new ZiaClientError('ZIA_NOT_CONFIGURED', `Missing settings: ${missing.join(', ')}`, { missing });
		}
	}

	/** An access token, reused until five minutes before it runs out. */
	async accessToken() {
		if (this.token && Date.now() < this.tokenExpires) return this.token;
		const params = new URLSearchParams({
			refresh_token: this.refreshToken,
			client_id: this.clientId,
			client_secret: this.clientSecret,
			grant_type: 'refresh_token'
		});
		const reply = await this.call(`${this.accounts}/oauth/v2/token?${params}`, { method: 'POST' });
		const json = await reply.json().catch(() => ({}));
		if (!json.access_token) {
			// The refusal reason only; the URL carries the credentials.
			throw new ZiaClientError('ZIA_UNAUTHORIZED', `Zoho Accounts refused the token: ${json.error || reply.status}`, {
				status: reply.status, error: json.error
			});
		}
		this.token = json.access_token;
		this.tokenExpires = Date.now() + ((Number(json.expires_in) || 3600) - 300) * 1000;
		return this.token;
	}

	/** Uploads the image for the agent and gives its file id. */
	async upload(bytes, fileName, mimeType) {
		const form = new FormData();
		form.append('file', new Blob([bytes], { type: mimeType }), fileName);
		form.append('fileName', fileName);
		const headers = { 'Authorization': `Zoho-oauthtoken ${await this.accessToken()}` };
		if (this.orgId) headers['X-ZIAAGENTS-ORG'] = this.orgId;
		const reply = await this.call(`${this.agentBase}/ziaagents/api/v1/files`, { method: 'POST', headers, body: form });
		const json = await reply.json().catch(() => ({}));
		if (reply.status === 401 || reply.status === 403) {
			this.token = null;
			throw new ZiaClientError('ZIA_UNAUTHORIZED', `The file upload was refused (${reply.status}).`, { status: reply.status });
		}
		const id = json && json.data && json.data.fileId;
		if (!id) {
			throw new ZiaClientError('ZIA_UPLOAD_FAILED', `The image could not be uploaded (${reply.status}).`, {
				status: reply.status, body: JSON.stringify(json).slice(0, 300)
			});
		}
		return String(id);
	}

	/** fetch, given up on after [timeoutMs]. */
	async call(url, init) {
		const controller = new AbortController();
		const timer = setTimeout(() => controller.abort(), this.timeoutMs);
		try {
			return await this.fetch(url, { ...init, signal: controller.signal });
		} catch (error) {
			if (error && error.name === 'AbortError') {
				throw new ZiaClientError('ZIA_TIMEOUT', `No reply from Zia within ${this.timeoutMs} ms.`, { timeoutMs: this.timeoutMs });
			}
			throw new ZiaClientError('ZIA_CALL_FAILED', `Could not reach Zia: ${error && error.message}`, {});
		} finally {
			clearTimeout(timer);
		}
	}
}

/** PNG or JPEG, from the first bytes. */
function sniffMimeType(bytes) {
	return bytes && bytes[0] === 0x89 && bytes[1] === 0x50 ? 'image/png' : 'image/jpeg';
}

/**
 * The first {...} in [text], parsed — agents wrap JSON in code fences at times.
 *
 * One slip is mended rather than failing the whole reading: a puzzle's
 * quotation mark written as a bare `"` inside a string (`"prefix": """`).
 * Only a lone quote standing as a whole string is touched, so nothing that
 * was valid JSON can change.
 */
function jsonIn(text) {
	const value = String(text || '');
	const start = value.indexOf('{');
	const end = value.lastIndexOf('}');
	if (start === -1 || end <= start) return null;
	const body = value.slice(start, end + 1);
	try { return JSON.parse(body); } catch (e) { /* try the mend below */ }
	// """ where a value is expected — after a colon, an opening bracket or a
	// comma — is a string holding one bare quote.
	const mended = body.replace(/([:\[,]\s*)"""(?=\s*[,\]}])/g, '$1"\\""');
	if (mended === body) return null;
	try { return JSON.parse(mended); } catch (e) { return null; }
}

module.exports = { ZiaDailyPuzzleClient, ZiaClientError, ENV, jsonIn, sniffMimeType };
