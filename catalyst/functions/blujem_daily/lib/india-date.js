'use strict';

/** The puzzle day is India's day: what the date is in Asia/Kolkata. */
const ZONE = 'Asia/Kolkata';

/** [now] as a yyyy-MM-dd date in India. */
function indiaDate(now = new Date()) {
	// en-CA formats as yyyy-MM-dd.
	return new Intl.DateTimeFormat('en-CA', {
		timeZone: ZONE, year: 'numeric', month: '2-digit', day: '2-digit'
	}).format(now);
}

/** True when [isoDate] (yyyy-MM-dd) is a Sunday. */
function isSunday(isoDate) {
	const [y, m, d] = String(isoDate).split('-').map(Number);
	return new Date(Date.UTC(y, m - 1, d)).getUTCDay() === 0;
}

/** True when [value] is a real calendar date written yyyy-MM-dd. */
function isIsoDate(value) {
	if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
	const [y, m, d] = value.split('-').map(Number);
	const date = new Date(Date.UTC(y, m - 1, d));
	return date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
}

module.exports = { ZONE, indiaDate, isSunday, isIsoDate };
