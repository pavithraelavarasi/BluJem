'use strict';

/**
 * A player's "About me": free text they choose to share — a name, hobbies,
 * a way to reach them — shown to other signed-in players who tap them on
 * the leaderboard. Kept short and plain.
 */

const ABOUT_MAX = 300;

/** [text] tidied for saving: trimmed, no control characters, at most two blank lines in a row. */
function cleanAbout(text) {
	return String(text || '')
		.replace(/\r\n?/g, '\n')
		.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, '')
		.replace(/[ \t]+\n/g, '\n')
		.replace(/\n{3,}/g, '\n\n')
		.trim();
}

/** Why [about] cannot be saved, or null. */
function aboutProblem(about) {
	return about.length > ABOUT_MAX ? `Keep it to ${ABOUT_MAX} characters (this is ${about.length}).` : null;
}

/** Where a player's About me is kept in Stratus. */
const aboutKey = (userId) => `profiles/${userId}.json`;

module.exports = { ABOUT_MAX, cleanAbout, aboutProblem, aboutKey };
