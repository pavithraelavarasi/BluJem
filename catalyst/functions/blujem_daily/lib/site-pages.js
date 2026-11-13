'use strict';

/**
 * BluJem's public web pages: a home page, the privacy policy and the app
 * download page. Google needs
 * both linked from the OAuth consent screen before "Continue with Google" can
 * be opened to every account, and they must sit on an authorised domain, so
 * they are served from here rather than hosted elsewhere.
 */

const CONTACT = 'pavithrabeus2001@gmail.com';
const UPDATED = '27 October 2026';

function page(title, body) {
	return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
	:root { --bg: #faf6ee; --ink: #1d1b16; --soft: #5c5648; --line: #e3dccb; --accent: #9a4a12; }
	@media (prefers-color-scheme: dark) {
		:root { --bg: #17150f; --ink: #f2ede1; --soft: #b9b1a0; --line: #3a352a; --accent: #e59a5c; }
	}
	body { margin: 0; background: var(--bg); color: var(--ink);
		font: 17px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
	main { max-width: 680px; margin: 0 auto; padding: 40px 16px 64px; }
	h1 { font-family: Georgia, serif; font-size: 2.2rem; margin: 0 0 4px; }
	h2 { font-size: 1.15rem; margin: 32px 0 8px; }
	p, li { color: var(--soft); }
	a { color: var(--accent); }
	.tag { color: var(--soft); margin: 0 0 24px; }
	.button { display: inline-block; padding: 14px 26px; border-radius: 999px; background: #1e6fe0; color: #fff;
		font-weight: 600; text-decoration: none; }
	footer { margin-top: 48px; padding-top: 16px; border-top: 1px solid var(--line); font-size: .9rem; color: var(--soft); }
</style>
</head>
<body><main>
${body}
<footer><a href="home">BluJem</a> · <a href="privacy">Privacy policy</a> · <a href="mailto:${CONTACT}">${CONTACT}</a></footer>
</main></body>
</html>`;
}

const HOME = page('BluJem', `
<h1>BluJem</h1>
<p class="tag">A daily word-jumble puzzle game.</p>
<p>Every day there is a new puzzle: unscramble four jumbled words, then use the circled letters to solve the riddle that goes with the cartoon.</p>
<ul>
	<li>Tap the letters in the order of the word, or drag a letter to where it goes.</li>
	<li>Shake the phone to mix the letters again.</li>
	<li>Use a hint when you are stuck, and beat the clock for more points.</li>
	<li>Keep your streak, see your history, and climb the leaderboard.</li>
</ul>
<p>Sign in with an email and password, with Google, or with Zoho. Your account works on any phone you sign in from.</p>
<p>Questions or feedback: <a href="mailto:${CONTACT}">${CONTACT}</a></p>
`);

const PRIVACY = page('BluJem Privacy Policy', `
<h1>Privacy policy</h1>
<p class="tag">BluJem · last updated ${UPDATED}</p>

<p>This policy explains what BluJem collects when you play, why, and what you can ask us to do with it.</p>

<h2>What we collect</h2>
<ul>
	<li><strong>Account details:</strong> your name, email address and a username. If you sign up with a password, we store only a salted hash of it, never the password itself.</li>
	<li><strong>Google or Zoho sign-in:</strong> if you choose one of these, we receive your name and email address from that provider to create or find your BluJem account. We do not receive your Google or Zoho password and do not access anything else in those accounts.</li>
	<li><strong>Game data:</strong> the puzzles you finish, your scores, times, hints used and streaks.</li>
</ul>
<p>We do not collect your location, contacts, photos or advertising identifiers, and there are no ads or in-app purchases.</p>

<h2>How we use it</h2>
<ul>
	<li>To sign you in and keep your progress across phones.</li>
	<li>To show the leaderboard. It shows only your username, never your name or email address.</li>
	<li>To answer you if you contact us.</li>
</ul>
<p>We do not sell your data or share it with advertisers.</p>

<h2>Where it is stored</h2>
<p>Your account and game data are stored on Zoho Catalyst, the cloud service that runs BluJem's backend. Hints are produced by a Zoho Zia AI agent, which is sent only the puzzle's words, not your personal details.</p>

<h2>Keeping and deleting your data</h2>
<p>We keep your account while you use BluJem. To delete your account and all your game data, email <a href="mailto:${CONTACT}">${CONTACT}</a> from the address you signed up with, and we will delete it within 30 days.</p>

<h2>Children</h2>
<p>BluJem is not directed at children under 13, and we do not knowingly collect their personal data.</p>

<h2>Changes</h2>
<p>If this policy changes, we will update the date at the top of this page.</p>

<h2>Contact</h2>
<p><a href="mailto:${CONTACT}">${CONTACT}</a></p>
`);

// Where the QR code on a shared "win" card leads. The button goes through
// download-apk, which signs a fresh link to the latest release each time.
const DOWNLOAD = page('Get BluJem', `
<h1>BluJem</h1>
<p class="tag">A new word jumble every day — free.</p>
<p><a class="button" href="download-apk">Download for Android</a></p>
<ol>
	<li>Tap <strong>Download for Android</strong>.</li>
	<li>Open the downloaded file. If Android asks, allow installing apps from your browser.</li>
	<li>Tap <strong>Install</strong>, then open BluJem and sign in.</li>
</ol>
<p>The app keeps itself up to date after that. Not on iPhone yet.</p>
`);

const PAGES = { home: HOME, privacy: PRIVACY, download: DOWNLOAD };

/** The page for [route], or null when it isn't one of these. */
function sitePage(route) {
	return Object.prototype.hasOwnProperty.call(PAGES, route) ? PAGES[route] : null;
}

module.exports = { sitePage };
