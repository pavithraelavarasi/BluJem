'use strict';

const catalyst = require('zcatalyst-sdk-node');
const crypto = require('crypto');

/**
 * Email and password sign-in for Daily Jumble.
 *
 * The Users table holds password hashes and is readable only by the App
 * Administrator role, so verification has to happen here: the app posts the
 * credentials, this function checks them with admin scope and returns the
 * profile. A password never leaves this file in a form anyone can reuse, and
 * the client never touches the table.
 */

const TABLE = 'Users';
const TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const ALGORITHM = 'pbkdf2_sha256';
const ITERATIONS = 210000;
const KEY_LENGTH = 32;
const DIGEST = 'sha256';
const TOKEN_HEADER = 'x-jumble-token';
/** Tokens issued by the old DailyJumble project carry its user ids, so only BluJem's are accepted. */
const TOKEN_PROJECT = 'blujem';

// ------------------------------------------------------------------ helpers

function sendJson(res, statusCode, data) {
	res.writeHead(statusCode, { 'Content-Type': 'application/json' });
	res.end(JSON.stringify(data));
}

function readBody(req) {
	return new Promise((resolve, reject) => {
		if (req.body && typeof req.body === 'object') return resolve(req.body);
		if (req.body && typeof req.body === 'string') {
			try { return resolve(JSON.parse(req.body)); } catch (e) { return resolve({}); }
		}
		let data = '';
		req.on('data', (chunk) => { data += chunk; });
		req.on('end', () => {
			try { resolve(data ? JSON.parse(data) : {}); } catch (e) { resolve({}); }
		});
		req.on('error', reject);
	});
}

function hashPassword(password) {
	const salt = crypto.randomBytes(16);
	const derived = crypto.pbkdf2Sync(password, salt, ITERATIONS, KEY_LENGTH, DIGEST);
	return `${ALGORITHM}$${ITERATIONS}$${salt.toString('base64')}$${derived.toString('base64')}`;
}

/** Compares in constant time, so a wrong password cannot be found by timing. */
function verifyPassword(password, stored) {
	if (!stored) return false;
	const parts = String(stored).split('$');
	if (parts.length !== 4 || parts[0] !== ALGORITHM) return false;

	const iterations = parseInt(parts[1], 10);
	const salt = Buffer.from(parts[2], 'base64');
	const expected = Buffer.from(parts[3], 'base64');
	if (!Number.isFinite(iterations) || iterations < 1 || expected.length === 0) return false;

	const actual = crypto.pbkdf2Sync(password, salt, iterations, expected.length, DIGEST);
	return actual.length === expected.length && crypto.timingSafeEqual(actual, expected);
}

// ------------------------------------------------------------------- tokens

const b64url = (buf) => Buffer.from(buf).toString('base64')
	.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

/**
 * A signed statement of who this is, for jumble_data to trust without another
 * password check. The role travels inside the signature, so a client cannot
 * promote itself by editing the payload.
 */
function issueToken(user) {
	const secret = process.env.JUMBLE_TOKEN_SECRET;
	if (!secret) throw new Error('JUMBLE_TOKEN_SECRET is not set');

	const payload = b64url(JSON.stringify({
		id: user.ROWID,
		email: user.Email,
		name: user.Name || '',
		username: user.Username || '',
		role: user.Role || 'player',
		project: TOKEN_PROJECT,
		exp: Date.now() + TOKEN_TTL_MS
	}));
	const signature = b64url(crypto.createHmac('sha256', secret).update(payload).digest());
	return `${payload}.${signature}`;
}

const isEmail = (value) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);

/** Returns the caller described by the token, or null if it does not hold up. */
function readToken(req) {
	const secret = process.env.JUMBLE_TOKEN_SECRET;
	if (!secret) return null;

	const token = String(req.headers[TOKEN_HEADER] || '').trim();
	const [payload, signature] = token.split('.');
	if (!payload || !signature) return null;

	const expected = b64url(crypto.createHmac('sha256', secret).update(payload).digest());
	const a = Buffer.from(signature);
	const b = Buffer.from(expected);
	if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;

	try {
		const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8'));
		if (!claims.exp || Date.now() > claims.exp) return null;
		if (claims.project !== TOKEN_PROJECT) return null;
		return claims;
	} catch (e) {
		return null;
	}
}

/** ZCQL takes single-quoted strings, so a quote in the input must be doubled. */
const quote = (value) => String(value).replace(/'/g, "''");

/** What the app is allowed to see about an account. */
function publicProfile(row) {
	return {
		id: row.ROWID,
		email: row.Email,
		name: row.Name || '',
		username: row.Username || '',
		role: row.Role || 'player'
	};
}

async function findUserByEmail(app, email) {
	const rows = await app.zcql().executeZCQLQuery(
		`SELECT ROWID, Email, Name, Username, Role, PasswordHash, Active FROM ${TABLE} ` +
		`WHERE Email = '${quote(email)}'`
	);
	// ZCQL wraps every row under its table name.
	return rows.map((r) => r[TABLE]).filter(Boolean)[0] || null;
}

// ---------------------------------------------------------------- usernames
//
// The leaderboard shows a handle, never a name or an email. Every account has
// one from its first sign-in — a made-up one until the player picks their own
// — so the board never has to fall back on who somebody really is. The
// lowercase copy in UsernameKey is unique in the table itself, so two players
// racing for the same handle cannot both get it.

const USERNAME_RULE = /^[A-Za-z0-9_]{3,16}$/;
const RESERVED = new Set(['admin', 'administrator', 'moderator', 'dailyjumble', 'jumble', 'player', 'you']);

const ADJECTIVES = [
	'Brave', 'Calm', 'Clever', 'Cosy', 'Curious', 'Daring', 'Eager', 'Gentle', 'Happy', 'Jolly',
	'Lucky', 'Merry', 'Nimble', 'Plucky', 'Quick', 'Quiet', 'Sly', 'Sunny', 'Swift', 'Witty'
];
const ANIMALS = [
	'Badger', 'Crane', 'Dolphin', 'Falcon', 'Fox', 'Gecko', 'Heron', 'Koala', 'Lynx', 'Marten',
	'Otter', 'Owl', 'Panda', 'Puffin', 'Quokka', 'Raven', 'Robin', 'Seal', 'Tiger', 'Wren'
];

const pick = (list) => list[crypto.randomInt(list.length)];

/** Why a handle cannot be used, or null when it can. */
function usernameProblem(username) {
	if (!USERNAME_RULE.test(username)) {
		return 'Use 3 to 16 letters, numbers or underscores.';
	}
	if (RESERVED.has(username.toLowerCase())) return 'That username is reserved.';
	return null;
}

async function usernameTaken(app, username, exceptRowId) {
	const rows = await app.zcql().executeZCQLQuery(
		`SELECT ROWID FROM ${TABLE} WHERE UsernameKey = '${quote(username.toLowerCase())}'`
	);
	return rows.map((r) => r[TABLE]).filter(Boolean)
		.some((r) => String(r.ROWID) !== String(exceptRowId || ''));
}

/** The table's own unique check, for the race the lookup above cannot see. */
const isDuplicate = (error) => /duplicate|unique/i.test(String(error && (error.message || error)));

/** A free made-up handle like QuietOtter42. */
async function freshUsername(app) {
	for (let attempt = 0; attempt < 8; attempt++) {
		const candidate = `${pick(ADJECTIVES)}${pick(ANIMALS)}${crypto.randomInt(10, 100)}`;
		if (!(await usernameTaken(app, candidate))) return candidate;
	}
	return `Player${crypto.randomInt(100000, 1000000)}`;
}

/**
 * Gives an account that predates usernames — or was just made — a handle of
 * its own. Returns the row with it filled in.
 */
async function ensureUsername(app, row) {
	if (row.Username) return row;
	for (let attempt = 0; attempt < 3; attempt++) {
		const username = await freshUsername(app);
		try {
			await app.datastore().table(TABLE).updateRow({
				ROWID: row.ROWID, Username: username, UsernameKey: username.toLowerCase()
			});
			return { ...row, Username: username };
		} catch (error) {
			if (!isDuplicate(error)) throw error;
		}
	}
	return row;
}

// ------------------------------------------------------------------- routes

async function login(app, body, res) {
	const email = String(body.email || '').trim().toLowerCase();
	const password = String(body.password || '');

	if (!email || !password) {
		return sendJson(res, 400, { error: 'Email and password are both required.' });
	}

	const user = await findUserByEmail(app, email);
	const ok = user && verifyPassword(password, user.PasswordHash);

	// The same answer whether the email is unknown or the password is wrong, so
	// this cannot be used to discover who has an account.
	if (!ok) {
		return sendJson(res, 401, { error: 'Email or password is incorrect.' });
	}
	if (String(user.Active) === 'false') {
		return sendJson(res, 403, { error: 'This account has been disabled.' });
	}

	const named = await ensureUsername(app, user);
	return sendJson(res, 200, { user: publicProfile(named), token: issueToken(named) });
}

/**
 * Turns a signed-in Zoho account into a Daily Jumble session.
 *
 * Who the caller is never comes from the request body. The app sends the OAuth
 * token Catalyst gave it, Catalyst validates that token before this function
 * runs, and the identity is then read back from Catalyst with user scope — so
 * the email here is one Zoho has vouched for, and posting somebody else's
 * address gets you nothing.
 *
 * A first sign-in creates the account. It is stored with no password hash: this
 * is a Zoho-only account, and an empty hash can never verify, so nobody can
 * later sign into it with a password. The role is always player, exactly as in
 * signup — an admin is made deliberately, never by signing in.
 */
async function zohoSession(req, admin, res) {
	const caller = catalyst.initialize(req);
	const zoho = await caller.userManagement().getCurrentUser().catch(() => null);

	const email = String(zoho?.email_id || '').trim().toLowerCase();
	if (!email) {
		return sendJson(res, 401, { error: 'Sign in with Zoho, then try again.' });
	}

	const existing = await findUserByEmail(admin, email);
	if (existing) {
		if (String(existing.Active) === 'false') {
			return sendJson(res, 403, { error: 'This account has been disabled.' });
		}
		const named = await ensureUsername(admin, existing);
		return sendJson(res, 200, {
			user: publicProfile(named),
			token: issueToken(named)
		});
	}

	const name = [zoho.first_name, zoho.last_name]
		.filter(Boolean).join(' ').trim() || email.split('@')[0];

	const created = await admin.datastore().table(TABLE).insertRow({
		Email: email,
		Name: name,
		Role: 'player',
		PasswordHash: '',
		Active: true
	});
	const row = await ensureUsername(admin, Array.isArray(created) ? created[0] : created);

	return sendJson(res, 201, { user: publicProfile(row), token: issueToken(row) });
}

async function signup(app, body, res) {
	const email = String(body.email || '').trim().toLowerCase();
	const password = String(body.password || '');
	const name = String(body.name || '').trim();
	const username = String(body.username || '').trim();

	if (!isEmail(email)) {
		return sendJson(res, 400, { error: 'Enter a valid email address.' });
	}
	if (password.length < 6) {
		return sendJson(res, 400, { error: 'Use at least six characters for the password.' });
	}

	if (username) {
		const problem = usernameProblem(username);
		if (problem) return sendJson(res, 400, { error: problem });
	}

	if (await findUserByEmail(app, email)) {
		return sendJson(res, 409, { error: 'An account already exists for that email.' });
	}
	if (username && await usernameTaken(app, username)) {
		return sendJson(res, 409, { error: 'That username is taken. Try another.' });
	}

	// Role is never taken from the request: everyone signs up as a player, and
	// an admin is promoted deliberately.
	let row;
	try {
		row = await app.datastore().table(TABLE).insertRow({
			Email: email,
			Name: name,
			...(username ? { Username: username, UsernameKey: username.toLowerCase() } : {}),
			Role: 'player',
			PasswordHash: hashPassword(password),
			Active: 'true'
		});
	} catch (error) {
		if (username && isDuplicate(error)) {
			return sendJson(res, 409, { error: 'That username is taken. Try another.' });
		}
		throw error;
	}

	const created = await ensureUsername(app, {
		...row, Email: email, Name: name, Username: username || row.Username || '', Role: 'player'
	});
	return sendJson(res, 201, { user: publicProfile(created), token: issueToken(created) });
}

// ----------------------------------------------------------- forgot password
//
// A player who forgot their password asks for a code by email, then sends it
// back with a new password. The code is six digits, good for 15 minutes and
// five tries, and only its hash is kept — in the cache, never the table. The
// first step answers the same whether or not the email has an account, so it
// cannot be used to find out who plays.

const RESET_CODE_MINUTES = 15;
const RESET_MAX_TRIES = 5;
const RESET_RESEND_SECONDS = 60;
/** The sender verified in Catalyst Mail. */
const RESET_FROM = () => (process.env.RESET_FROM_EMAIL || 'pavithrabeus2001@gmail.com').trim();

const resetKey = (email) => `pwreset_${crypto.createHash('sha256').update(email).digest('hex').slice(0, 40)}`;
const codeHash = (code, salt) => crypto.createHash('sha256').update(`${salt}:${code}`).digest('hex');

async function readReset(app, email) {
	const value = await app.cache().segment().getValue(resetKey(email)).catch(() => null);
	try { return value ? JSON.parse(value) : null; } catch (e) { return null; }
}

/** Kept for an hour at most; the code itself stops working after 15 minutes. */
async function writeReset(app, email, entry) {
	const segment = app.cache().segment();
	const value = JSON.stringify(entry);
	// put adds a key, update replaces one: a second code or a wrong try needs the latter.
	await segment.put(resetKey(email), value, 1).catch(() => segment.update(resetKey(email), value, 1));
}

const dropReset = (app, email) => app.cache().segment().delete(resetKey(email)).catch(() => null);

async function forgotPassword(app, body, res) {
	const email = String(body.email || '').trim().toLowerCase();
	if (!isEmail(email)) return sendJson(res, 400, { error: 'Enter a valid email address.' });
	const sent = { status: 'sent', minutes: RESET_CODE_MINUTES };

	// Why no email went out is logged by reason only, never by address.
	const user = await findUserByEmail(app, email);
	if (!user || String(user.Active) === 'false') {
		console.log(`Reset code not sent: ${user ? 'account disabled' : 'no account for that email'}`);
		return sendJson(res, 200, sent);
	}

	// One email a minute, however often the button is pressed.
	const previous = await readReset(app, email);
	if (previous && Date.now() - previous.created < RESET_RESEND_SECONDS * 1000) {
		console.log('Reset code not sent: one was sent less than a minute ago');
		return sendJson(res, 200, sent);
	}

	const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
	const salt = crypto.randomBytes(12).toString('hex');
	await writeReset(app, email, {
		hash: codeHash(code, salt),
		salt,
		created: Date.now(),
		expires: Date.now() + RESET_CODE_MINUTES * 60 * 1000,
		tries: 0
	});
	const mail = app.email().sendMail({
		from_email: RESET_FROM(),
		to_email: [email],
		subject: `Your BluJem code: ${code}`,
		html_mode: true,
		content:
			`<p>Hi${user.Name ? ` ${String(user.Name).replace(/[<>&]/g, '')}` : ''},</p>` +
			`<p>Your code to set a new BluJem password is</p>` +
			`<p style="font-size:28px;font-weight:bold;letter-spacing:6px">${code}</p>` +
			`<p>It works for ${RESET_CODE_MINUTES} minutes. If you did not ask for it, ignore this email; ` +
			`your password stays as it is.</p>`
	});
	try {
		await mail;
		console.log(`Reset code sent to account ${user.ROWID}`);
	} catch (error) {
		// Not sent (the sender not yet verified in Catalyst Mail, say): forget the
		// code so the next try is not held back by the one-a-minute rule.
		console.error('Reset email not sent:', error);
		await dropReset(app, email);
		return sendJson(res, 503, { error: "We couldn't send the email just now. Try again in a few minutes." });
	}
	return sendJson(res, 200, sent);
}

/**
 * Whether [code] is the one emailed to [email]: null when it is, otherwise
 * what to tell the player. A wrong code uses up one of the five tries.
 */
async function codeProblem(app, email, code) {
	if (!isEmail(email) || code.length !== 6) return 'Enter your email and the 6-digit code from the email.';
	const entry = await readReset(app, email);
	if (!entry || Date.now() > entry.expires) {
		await dropReset(app, email);
		return 'That code has expired. Ask for a new one.';
	}
	const a = Buffer.from(codeHash(code, entry.salt));
	const b = Buffer.from(String(entry.hash));
	if (a.length === b.length && crypto.timingSafeEqual(a, b)) return null;

	const tries = (entry.tries || 0) + 1;
	if (tries >= RESET_MAX_TRIES) {
		await dropReset(app, email);
		return 'Too many wrong codes. Ask for a new one.';
	}
	await writeReset(app, email, { ...entry, tries });
	return 'That code is not right. Check the email and try again.';
}

const resetFields = (body) => ({
	email: String(body.email || '').trim().toLowerCase(),
	code: String(body.code || '').replace(/\D/g, '')
});

/** The code on its own, before the new password is asked for. Nothing is used up. */
async function checkResetCode(app, body, res) {
	const { email, code } = resetFields(body);
	const problem = await codeProblem(app, email, code);
	return problem ? sendJson(res, 400, { error: problem }) : sendJson(res, 200, { status: 'ok' });
}

async function resetPassword(app, body, res) {
	const { email, code } = resetFields(body);
	const password = String(body.password || '');
	if (password.length < 6) {
		return sendJson(res, 400, { error: 'Use at least six characters for the password.' });
	}
	const problem = await codeProblem(app, email, code);
	if (problem) return sendJson(res, 400, { error: problem });

	const user = await findUserByEmail(app, email);
	if (!user || String(user.Active) === 'false') {
		await dropReset(app, email);
		return sendJson(res, 400, { error: 'That code has expired. Ask for a new one.' });
	}
	await app.datastore().table(TABLE).updateRow({ ROWID: user.ROWID, PasswordHash: hashPassword(password) });
	await dropReset(app, email);

	// Straight in with the new password.
	const named = await ensureUsername(app, user);
	return sendJson(res, 200, { user: publicProfile(named), token: issueToken(named) });
}

/**
 * The signed-in player's profile, fresh from the table, with a session that
 * carries it. Sessions issued before usernames existed come through here once
 * to pick one up, without the player having to sign in again.
 */
async function me(req, app, res) {
	const caller = readToken(req);
	if (!caller) return sendJson(res, 401, { error: 'Sign in again.' });

	const rows = await app.zcql().executeZCQLQuery(
		`SELECT ROWID, Email, Name, Username, Role, Active FROM ${TABLE} ` +
		`WHERE ROWID = '${quote(caller.id)}'`
	);
	const user = rows.map((r) => r[TABLE]).filter(Boolean)[0];
	if (!user) return sendJson(res, 401, { error: 'Sign in again.' });
	if (String(user.Active) === 'false') {
		return sendJson(res, 403, { error: 'This account has been disabled.' });
	}
	const named = await ensureUsername(app, user);
	return sendJson(res, 200, { user: publicProfile(named), token: issueToken(named) });
}

/**
 * Changes the signed-in player's handle and hands back a session that carries
 * it. Who is asking comes from their token, never the body.
 */
async function changeUsername(req, app, body, res) {
	const caller = readToken(req);
	if (!caller) return sendJson(res, 401, { error: 'Sign in again.' });

	const username = String(body.username || '').trim();
	const problem = usernameProblem(username);
	if (problem) return sendJson(res, 400, { error: problem });

	const rows = await app.zcql().executeZCQLQuery(
		`SELECT ROWID, Email, Name, Username, Role, Active FROM ${TABLE} ` +
		`WHERE ROWID = '${quote(caller.id)}'`
	);
	const user = rows.map((r) => r[TABLE]).filter(Boolean)[0];
	if (!user) return sendJson(res, 401, { error: 'Sign in again.' });
	if (String(user.Active) === 'false') {
		return sendJson(res, 403, { error: 'This account has been disabled.' });
	}

	if (await usernameTaken(app, username, user.ROWID)) {
		return sendJson(res, 409, { error: 'That username is taken. Try another.' });
	}
	try {
		await app.datastore().table(TABLE).updateRow({
			ROWID: user.ROWID, Username: username, UsernameKey: username.toLowerCase()
		});
	} catch (error) {
		if (isDuplicate(error)) {
			return sendJson(res, 409, { error: 'That username is taken. Try another.' });
		}
		throw error;
	}

	const updated = { ...user, Username: username };
	return sendJson(res, 200, { user: publicProfile(updated), token: issueToken(updated) });
}

// ------------------------------------------------------------------ handler

module.exports = async (req, res) => {
	try {
		// Admin scope: the Users table is closed to the App User role, and there
		// is no signed-in Catalyst user to act as during sign-in anyway.
		const app = catalyst.initialize(req, { scope: 'admin' });

		const path = new URL(req.url, `https://${req.headers.host || 'localhost'}`).pathname;
		const route = path.replace(/\/+$/, '').split('/').pop() || '';

		if (req.method === 'OPTIONS') {
			res.writeHead(204);
			return res.end();
		}
		if (req.method !== 'POST') {
			return sendJson(res, 405, { error: 'Use POST.' });
		}

		const body = await readBody(req);

		if (route === 'login') return await login(app, body, res);
		if (route === 'signup') return await signup(app, body, res);
		if (route === 'zoho') return await zohoSession(req, app, res);
		if (route === 'username') return await changeUsername(req, app, body, res);
		if (route === 'me') return await me(req, app, res);
		if (route === 'forgot-password') return await forgotPassword(app, body, res);
		if (route === 'check-reset-code') return await checkResetCode(app, body, res);
		if (route === 'reset-password') return await resetPassword(app, body, res);

		return sendJson(res, 404, {
			error: 'Unknown route. Use /login, /signup, /zoho, /me, /username, /forgot-password, /check-reset-code or /reset-password.'
		});
	} catch (error) {
		console.error('jumble_auth failed:', error);
		return sendJson(res, 500, { error: 'Something went wrong. Try again.' });
	}
};
