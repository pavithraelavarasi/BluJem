'use strict';

const crypto = require('crypto');
const { SLOTS, defaultSlot, indiaDate, releaseTime, isReleased, isTimedOpening } = require('./slots');
const { asBool, isComplete } = require('./puzzle-views');

/**
 * "A new BluJem is out", sent to every phone through Firebase Cloud
 * Messaging. The app subscribes to one topic, so there is no list of devices
 * to keep. Two moments send it:
 *
 *  - the admin publishes a morning or Sunday puzzle that opens straight away
 *    (announceOnPublish), and
 *  - the timer, every hour on the hour, finds a puzzle whose fixed time has
 *    just come — every afternoon and night one, and a morning or Sunday one
 *    uploaded ahead (dueAtTimer).
 *
 * A puzzle that opens on publishing gets a release time off the whole minute
 * and a timed one gets it on the minute, so the two never both announce it.
 */

/** Long enough that a late timer still counts; short enough that nothing stale is announced. */
const TIMER_WINDOW_MS = 30 * 60 * 1000;
/** Republishing a puzzle that went out hours ago is a fix, not news. */
const PUBLISH_WINDOW_MS = 3 * 3600 * 1000;

const slotOf = (row) => (SLOTS[row.Slot] ? row.Slot : defaultSlot(String(row.PublishDate)));
const isToday = (row, now) => String(row.PublishDate) === indiaDate(now);
const playable = (row) => asBool(row.Published) && isComplete(row);

/**
 * Whether publishing [row] should announce it now. [previous] is the row
 * already out for the same date and slot, if any: replacing or fixing a
 * puzzle that players have had is not announced twice.
 */
function announceOnPublish(row, previous, now = Date.now()) {
	// Not out yet (a night one before 21:00): the timer announces it then.
	// Out already — opened on publishing, or a night one published late at
	// 21:05, after the timer found nothing — so say it here.
	if (!playable(row) || !isToday(row, now) || !isReleased(row, now)) return false;
	if (now - releaseTime(row) > PUBLISH_WINDOW_MS) return false;
	return !(previous && playable(previous) && isReleased(previous, now) && slotOf(previous) === slotOf(row));
}

/** Today's puzzles whose timed opening has just come, for the timer to announce. */
function dueAtTimer(rows, now = Date.now()) {
	return rows.filter((row) => {
		const at = releaseTime(row);
		return playable(row) && isToday(row, now) && isTimedOpening(at) && at <= now && now - at < TIMER_WINDOW_MS;
	});
}

/** What the notification says for [row]. */
function messageFor(row) {
	const slot = slotOf(row);
	if (slot === 'sunday') return { title: "Sunday's Mega BluJem is out", body: 'Six words and a cartoon riddle — tap to play.' };
	const when = { morning: "This morning's", evening: "This afternoon's", night: "Tonight's" }[slot];
	return { title: `${when} BluJem is out`, body: 'Four new words and a cartoon riddle — tap to play.' };
}

// ------------------------------------------------------------------ Firebase

/**
 * The Firebase service account, from FCM_SERVICE_ACCOUNT: the JSON key file's
 * contents, as is or base64. Null when push is not set up yet.
 */
function serviceAccount(env = process.env) {
	const raw = String(env.FCM_SERVICE_ACCOUNT || '').trim();
	if (!raw) return null;
	try {
		const json = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
		const account = JSON.parse(json);
		return account.client_email && account.private_key && account.project_id ? account : null;
	} catch (error) {
		return null;
	}
}

let cachedToken = null;

/** A Google access token for FCM, from a JWT signed with the service account's key. */
async function accessToken(account) {
	if (cachedToken && cachedToken.email === account.client_email && cachedToken.expires > Date.now() + 60000) {
		return cachedToken.value;
	}
	const now = Math.floor(Date.now() / 1000);
	const encode = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
	const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
		iss: account.client_email,
		scope: 'https://www.googleapis.com/auth/firebase.messaging',
		aud: 'https://oauth2.googleapis.com/token',
		iat: now,
		exp: now + 3600
	})}`;
	const signature = crypto.sign('RSA-SHA256', Buffer.from(unsigned), account.private_key).toString('base64url');
	const reply = await fetch('https://oauth2.googleapis.com/token', {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: new URLSearchParams({
			grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
			assertion: `${unsigned}.${signature}`
		})
	});
	const data = await reply.json().catch(() => ({}));
	if (!reply.ok || !data.access_token) throw new Error(`Google sign-in for FCM failed (${reply.status})`);
	cachedToken = { email: account.client_email, value: data.access_token, expires: Date.now() + data.expires_in * 1000 };
	return cachedToken.value;
}

/**
 * Announces [row] to the topic every app subscribes to. Never throws:
 * publishing must not fail because a notification could not go out.
 */
async function announce(row, env = process.env) {
	const account = serviceAccount(env);
	if (!account) return { sent: false, skipped: 'push is not set up (FCM_SERVICE_ACCOUNT)' };
	const topic = env.FCM_TOPIC || 'puzzles';
	const { title, body } = messageFor(row);
	try {
		const reply = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
			method: 'POST',
			headers: { Authorization: `Bearer ${await accessToken(account)}`, 'Content-Type': 'application/json' },
			body: JSON.stringify({
				message: {
					topic,
					notification: { title, body },
					data: { puzzleId: String(row.PuzzleId || ''), date: String(row.PublishDate), slot: slotOf(row) },
					android: { priority: 'high', notification: { channel_id: 'new_puzzle' } },
					apns: { payload: { aps: { sound: 'default' } } }
				}
			})
		});
		if (!reply.ok) return { sent: false, error: `FCM refused it (${reply.status}): ${(await reply.text()).slice(0, 200)}` };
		return { sent: true, topic };
	} catch (error) {
		return { sent: false, error: String(error.message || error) };
	}
}

module.exports = { announceOnPublish, dueAtTimer, messageFor, serviceAccount, announce, TIMER_WINDOW_MS };
