'use strict';

/**
 * When each puzzle goes live, in India's time (IST, UTC+5:30, no daylight
 * saving). Monday to Saturday three 4-word puzzles: morning at 9:00,
 * afternoon at 15:00 and night at 21:00; Sunday one 6-word Mega Jumble. The
 * morning and Sunday puzzles open the moment the admin publishes them — but
 * not before 9:00 (Sunday 6:00), so one uploaded ahead waits for its time.
 * The afternoon and night ones open at their time sharp. The afternoon slot
 * keeps its old name, evening, from when it was the second of two at 16:00.
 * The app's twin is lib/core/slots.dart.
 */

const SLOTS = {
	morning: { hour: 9, words: 4, label: 'Morning', onPublish: true },
	evening: { hour: 15, words: 4, label: 'Afternoon', onPublish: false },
	night: { hour: 21, words: 4, label: 'Night', onPublish: false },
	sunday: { hour: 6, words: 6, label: 'Mega Jumble', onPublish: true }
};

const IST_OFFSET_MS = 5.5 * 3600 * 1000;

function isIsoDate(value) {
	if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
	const [y, m, d] = value.split('-').map(Number);
	const date = new Date(Date.UTC(y, m - 1, d));
	return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

function isSunday(isoDate) {
	const [y, m, d] = String(isoDate).split('-').map(Number);
	return new Date(Date.UTC(y, m - 1, d)).getUTCDay() === 0;
}

/** The slots a day has: Sunday's one, or a weekday's three. */
function slotsFor(isoDate) {
	return isSunday(isoDate) ? ['sunday'] : ['morning', 'evening', 'night'];
}

/** What a puzzle from before slots existed counts as: its day's first slot. */
function defaultSlot(isoDate) {
	return slotsFor(isoDate)[0];
}

/** Why [slot] cannot be on [isoDate], or null when it can. */
function slotProblem(isoDate, slot) {
	if (!isIsoDate(isoDate)) return 'The date must be a real date, written yyyy-MM-dd.';
	if (!SLOTS[slot]) return 'The slot must be morning, evening, night or sunday.';
	if (isSunday(isoDate) && slot !== 'sunday') return `${isoDate} is a Sunday: it has only the sunday slot.`;
	if (!isSunday(isoDate) && slot === 'sunday') return `${isoDate} is not a Sunday: use morning, evening or night.`;
	return null;
}

/** The earliest [slot] on [isoDate] can go live — its fixed time for the afternoon and night — in epoch ms. */
function publishAt(isoDate, slot) {
	const [y, m, d] = isoDate.split('-').map(Number);
	return Date.UTC(y, m - 1, d, SLOTS[slot].hour) - IST_OFFSET_MS;
}

/**
 * When a puzzle being published now goes live. An afternoon or night puzzle
 * keeps its fixed time. A morning or Sunday one opens now, or at its time if
 * that is later; [previous] is the row as it was, so republishing one that
 * is already out (to fix a typo) keeps the time it first went out.
 */
function openingTime(isoDate, slot, now = Date.now(), previous = null) {
	const earliest = publishAt(isoDate, slot);
	if (!SLOTS[slot].onPublish) return earliest;
	const wasOut = previous
		&& String(previous.Published) === 'true'
		&& previous.PublishDate === isoDate
		&& (previous.Slot || defaultSlot(isoDate)) === slot
		&& isReleased(previous, now);
	if (wasOut) return releaseTime(previous);
	if (now <= earliest) return earliest;
	// Off the whole minute, so a puzzle that went out on publishing (and was
	// announced then) never looks like one waiting for the timer.
	return now % 60000 === 0 ? now + 1 : now;
}

/** Whether [ms] is a timed opening (9:00, 15:00, …) rather than a publish moment. */
function isTimedOpening(ms) {
	return Number.isFinite(ms) && ms % 60000 === 0;
}

/** India's date at [now] (epoch ms), yyyy-MM-dd. */
function indiaDate(now = Date.now()) {
	return new Date(now + IST_OFFSET_MS).toISOString().slice(0, 10);
}

/** When a stored puzzle goes live: its PublishAt, or for an older row its date's first slot. */
function releaseTime(row) {
	const stored = Number(row.PublishAt || 0);
	if (stored > 0) return stored;
	const date = String(row.PublishDate || '');
	if (!isIsoDate(date)) return Infinity;
	return publishAt(date, SLOTS[row.Slot] ? row.Slot : defaultSlot(date));
}

function isReleased(row, now = Date.now()) {
	return releaseTime(row) <= now;
}

module.exports = { SLOTS, isIsoDate, isSunday, slotsFor, defaultSlot, slotProblem, publishAt, openingTime, isTimedOpening, indiaDate, releaseTime, isReleased };
