'use strict';

/**
 * The admin page the admin opens on a computer or phone:
 * GET /server/jumble_data/execute/admin (or the older …/upload). After
 * signing in it shows two ways in: Upload puzzles and Leaderboard. They sign in with their BluJem admin
 * account (jumble_auth login), and the page sends each puzzle to
 * puzzles/upload. The page holds no secrets; every check that counts is on
 * the server, which refuses anyone who is not an admin.
 */
function uploadPage() {
	return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BluJem Admin</title>
<link rel="icon" type="image/png" sizes="64x64" href="data:image/png;base64,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">
<link rel="apple-touch-icon" sizes="180x180" href="data:image/png;base64,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">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@500;600&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<style>
	/* BluJem beige and navy, always light (the same look as the tech page). */
	:root {
		color-scheme: light;
		--bg: #F1E9D8; --card: #FFFDF8; --soft-bg: #F8F3E8; --ink: #18264A; --soft: #5E6680; --faint: #8F95A8;
		--line: #E4DAC6; --navy: #16264A; --accent: #1F3A6E; --gold: #E8C27A; --bad: #B3261E; --good: #2E7D32;
		--shadow: 0 1px 2px rgba(22,38,74,.06), 0 8px 24px rgba(22,38,74,.07);
	}
	* { box-sizing: border-box; }
	html { -webkit-text-size-adjust: 100%; }
	body { margin: 0; background: var(--bg); color: var(--ink); font: 15.5px/1.6 Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
	a { color: var(--accent); }

	/* Header band */
	header.bar { background: var(--navy); color: #FFF8EC; }
	header.bar .in { max-width: 880px; margin: 0 auto; padding: 16px 20px; display: flex; align-items: center; gap: 12px; }
	header.bar .gem { width: 30px; height: 30px; flex: none; }
	header.bar h1 { font: 600 1.35rem/1 Fredoka, Inter, sans-serif; margin: 0; letter-spacing: .01em; }
	header.bar h1 span { color: var(--gold); }
	header.bar .sub { color: #C9D0E2; font-size: .85rem; margin-left: 2px; }
	header.bar .grow { flex: 1; }
	header.bar button.out { margin: 0; padding: 7px 14px; font-size: .85rem; background: transparent; color: #FFF8EC; border: 1px solid rgba(255,248,236,.35); border-radius: 999px; }
	header.bar button.out:hover { border-color: var(--gold); color: var(--gold); }

	main { max-width: 880px; margin: 0 auto; padding: 28px 20px 72px; }
	h2 { font: 600 1.15rem/1.3 Fredoka, Inter, sans-serif; margin: 0 0 14px; color: var(--ink); }
	section { background: var(--card); border: 1px solid var(--line); border-radius: 18px; padding: 24px; margin-bottom: 20px; box-shadow: var(--shadow); }
	label { display: block; font-weight: 600; font-size: .92rem; margin: 16px 0 6px; }
	.hint { color: var(--soft); font-size: .86rem; font-weight: 400; }
	input, select, textarea { width: 100%; font: inherit; color: inherit; background: #fff; border: 1px solid var(--line); border-radius: 10px; padding: 10px 12px; transition: border-color .15s, box-shadow .15s; }
	input:focus, select:focus, textarea:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(31,58,110,.14); }
	input[type=file] { padding: 9px; background: var(--soft-bg); }
	textarea { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 1.05rem; min-height: 200px; }
	.datebox { position: relative; }
	button.datefield { width: 100%; margin: 0; text-align: left; font-weight: 400; color: var(--ink); background: #fff; border: 1px solid var(--line); border-radius: 10px; padding: 10px 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: none; }
	button.datefield:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(31,58,110,.14); }
	button.datefield:disabled { background: var(--soft-bg); cursor: default; opacity: .8; }
	.cal { position: absolute; left: 0; top: 100%; z-index: 20; margin-top: 6px; width: 320px; max-width: calc(100vw - 48px); border: 1px solid var(--line); border-radius: 14px; padding: 10px 12px; background: #fff; box-shadow: 0 10px 30px rgba(22,38,74,.18); }
	.cal .head { display: flex; align-items: center; justify-content: space-between; font-weight: 700; margin-bottom: 6px; }
	.cal .head button { margin: 0; padding: 2px 10px; }
	.cal .days { display: grid; grid-template-columns: repeat(7, 1fr); gap: 4px; text-align: center; }
	.cal .dow { font-size: .75rem; color: #7a7266; font-weight: 600; }
	.cal button.day { margin: 0; padding: 0; height: 34px; border-radius: 9px; border: 1px solid transparent; background: transparent; color: var(--ink); font-weight: 500; font-size: .9rem; box-shadow: none; }
	.cal button.day:hover { border-color: var(--accent); }
	.cal button.day.some { background: #F2C14E; font-weight: 700; }
	.cal button.day.full { background: #7CC98A; font-weight: 700; }
	.cal button.day.today { font-weight: 800; text-decoration: underline; }
	.cal button.day.picked { border: 2px solid var(--accent); }
	.cal .key { display: flex; gap: 14px; margin-top: 8px; font-size: .78rem; color: #7a7266; }
	.cal .key i { display: inline-block; width: 12px; height: 12px; border-radius: 3px; vertical-align: -2px; margin-right: 4px; }
	.row { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
	@media (max-width: 560px) { .row { grid-template-columns: 1fr; } section { padding: 18px; border-radius: 16px; } }

	button { font: inherit; font-weight: 600; border-radius: 999px; padding: 10px 20px; border: 1px solid var(--accent); cursor: pointer; margin: 18px 8px 0 0; transition: background .15s, color .15s, box-shadow .15s; }
	button.primary { background: var(--accent); color: #FFF8EC; box-shadow: 0 2px 6px rgba(31,58,110,.25); }
	button.primary:hover { background: var(--navy); }
	button.plain { background: transparent; color: var(--accent); }
	button.plain:hover { background: rgba(31,58,110,.07); }
	button:disabled { opacity: .5; cursor: default; }
	button:focus-visible { outline: 3px solid var(--gold); outline-offset: 2px; }
	button.social { display: flex; align-items: center; justify-content: center; gap: 10px; width: 100%; background: #fff; color: #1f1f1f; border: 1px solid #dadce0; border-radius: 12px; margin-top: 4px; }
	button.social:hover { background: #f7f7f7; }
	button.social svg { width: 20px; height: 20px; }
	.or { display: flex; align-items: center; gap: 12px; color: var(--faint); font-size: .82rem; margin: 22px 0 2px; }
	.or::before, .or::after { content: ""; flex: 1; height: 1px; background: var(--line); }

	.msg { margin-top: 14px; white-space: pre-line; font-size: .92rem; }
	.msg:empty { display: none; }
	.msg.good, .msg.bad { padding: 10px 14px; border-radius: 10px; }
	.msg.good { background: #EAF4EA; } .msg.bad { background: #FBEAE8; }
	.bad { color: var(--bad); } .good { color: var(--good); }
	.hidden { display: none !important; }

	/* Sign-in card, narrow and centred */
	#signin { max-width: 440px; margin: 24px auto; }
	#signin h2 { text-align: center; font-size: 1.35rem; margin-bottom: 4px; }
	#signin .hint.center { text-align: center; display: block; margin-bottom: 18px; }
	#signin button.primary { width: 100%; }

	/* Admin home */
	.welcome { margin: 4px 0 20px; }
	.welcome h2 { font-size: 1.6rem; margin: 0 0 2px; }
	.welcome p { margin: 0; color: var(--soft); }
	.tiles2 { display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
	@media (max-width: 560px) { .tiles2 { grid-template-columns: 1fr; } }
	button.tile2 { margin: 0; display: flex; flex-direction: column; align-items: flex-start; gap: 8px; text-align: left; padding: 26px 24px; background: var(--card); color: var(--ink); border: 1px solid var(--line); border-radius: 20px; font-weight: 400; box-shadow: var(--shadow); transition: transform .15s, box-shadow .15s, border-color .15s; }
	button.tile2:hover { transform: translateY(-2px); border-color: var(--accent); box-shadow: 0 2px 4px rgba(22,38,74,.08), 0 14px 32px rgba(22,38,74,.12); background: var(--card); }
	button.tile2 .ico { width: 48px; height: 48px; border-radius: 14px; display: grid; place-items: center; background: var(--navy); color: var(--gold); margin-bottom: 6px; }
	button.tile2 .ico svg { width: 24px; height: 24px; }
	button.tile2 b { font: 600 1.2rem/1.2 Fredoka, Inter, sans-serif; color: var(--ink); }
	button.tile2 .go { margin-top: 6px; color: var(--accent); font-weight: 600; font-size: .9rem; }

	/* Breadcrumb and page intro */
	.crumbs { display: flex; align-items: center; gap: 10px; margin: 0 0 18px; }
	.crumbs button.back { margin: 0; padding: 6px 14px; font-size: .88rem; }
	.crumbs .here { font: 600 1.15rem Fredoka, Inter, sans-serif; }
	p.lead { color: var(--soft); background: var(--soft-bg); border: 1px solid var(--line); border-left: 4px solid var(--gold); border-radius: 12px; padding: 12px 16px; margin: 0 0 20px; font-size: .92rem; }

	/* Tables */
	table { width: 100%; border-collapse: collapse; font-size: .93rem; }
	th { text-align: left; font-size: .74rem; text-transform: uppercase; letter-spacing: .06em; color: var(--faint); font-weight: 600; padding: 8px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
	td { text-align: left; padding: 10px; border-bottom: 1px solid var(--line); vertical-align: middle; }
	tbody tr:last-child td { border-bottom: none; }
	tbody tr:hover td { background: var(--soft-bg); }
	.num { text-align: right; font-variant-numeric: tabular-nums; }
	.scroll { overflow-x: auto; margin: 0 -4px; }
	#playerList td:nth-child(1) { color: var(--faint); width: 40px; }
	#playerList tr:nth-child(-n+3) td:nth-child(1) { color: var(--accent); font-weight: 700; }
	#playerList td:nth-child(2) { font-weight: 600; }

	.thumbs { display: flex; gap: 8px; }
	.thumbs img { height: 64px; width: auto; max-width: 96px; object-fit: cover; border-radius: 8px; border: 1px solid var(--line); background: #fff; cursor: zoom-in; transition: transform .15s; }
	.thumbs img:hover { transform: scale(1.04); }
	.thumbs .none { color: var(--faint); font-size: .82rem; }
	#viewer { position: fixed; inset: 0; background: rgba(12,20,40,.88); display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 10; cursor: zoom-out; }
	#viewer img { max-width: 100%; max-height: 100%; object-fit: contain; border-radius: 10px; background: #fff; }

	/* Puzzle form helpers */
	pre { background: var(--soft-bg); padding: 10px; border-radius: 8px; overflow-x: auto; }
	.words input, #final { font-family: Fredoka, Inter, sans-serif; font-weight: 500; font-size: 1.15rem; letter-spacing: .12em; text-transform: uppercase; margin-bottom: 6px; }
	.wordhead { display: flex; align-items: center; gap: 10px; margin: 16px 0 6px; }
	.wordhead label { margin: 0; }
	.mix { font-family: Fredoka, Inter, sans-serif; letter-spacing: .18em; font-size: 1.15rem; font-weight: 600; color: var(--ink); }
	button.shuffle { margin: 0; padding: 0; width: 32px; height: 32px; flex: none; border-radius: 9px; border: none; background: #e0123f; color: #fff; font-size: 17px; line-height: 32px; box-shadow: 0 2px 5px rgba(224,18,63,.3); }
	.tiles { display: flex; flex-wrap: wrap; gap: 6px; min-height: 46px; align-items: center; padding: 6px 8px; background: var(--soft-bg); border: 1px dashed var(--line); border-radius: 10px; margin-bottom: 6px; }
	.tile { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 50%; border: 2px solid var(--accent); background: #fff; font-family: Fredoka, Inter, sans-serif; font-weight: 600; font-size: 1.05rem; }
	.tile.empty { border-style: dashed; border-color: var(--line); color: var(--faint); background: transparent; }
	.tiles .gap { width: 20px; }
	.tiles .word { display: inline-flex; gap: 6px; align-items: center; flex-wrap: nowrap; }
	.tiles .mark { font-weight: 700; font-size: 1.2rem; color: var(--ink); margin: 0 -2px; align-self: flex-end; padding-bottom: 4px; }
	.tiles .wrap { flex-basis: 100%; height: 0; }
	.preview { margin: 12px 0 4px; }
	.preview img { display: block; width: 100%; max-height: 80vh; object-fit: contain; border-radius: 12px; border: 1px solid var(--line); background: #fff; }
	.preview figcaption { margin-top: 6px; }
</style>
</head>
<body>
<header class="bar"><div class="in"><svg class="gem" viewBox="0 0 40 40" aria-hidden="true"><path d="M12 6h16l8 10-16 19L4 16z" fill="#E8C27A"/><path d="M12 6l8 10 8-10M4 16h32M20 16v19" stroke="#FFF4DC" stroke-width="1.6" fill="none"/></svg><h1>Blu<span>Jem</span> Admin</h1><span class="grow"></span><button class="out hidden" id="signOutBtn">Sign out</button></div></header>
<main>
	<section id="home" class="hidden" style="background:none;border:none;box-shadow:none;padding:0">
		<div class="welcome"><h2>Welcome back</h2><p>What would you like to do?</p></div>
		<div class="tiles2">
			<button class="tile2" id="goUpload"><span class="ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16V4M6 10l6-6 6 6"/><path d="M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3"/></svg></span><b>Upload puzzles</b><span class="hint">Add a puzzle, check drafts, and see or edit what's uploaded.</span><span class="go">Open &rarr;</span></button>
			<button class="tile2" id="goBoard"><span class="ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 21h8M12 17v4M7 4h10v5a5 5 0 0 1-10 0z"/><path d="M17 5h3v2a3 3 0 0 1-3 3M7 5H4v2a3 3 0 0 0 3 3"/></svg></span><b>Leaderboard</b><span class="hint">Every player: when they joined, games played and total score.</span><span class="go">Open &rarr;</span></button>
		</div>
	</section>

	<div id="backBar" class="crumbs hidden"><button class="plain back" id="backBtn">&larr; Admin home</button><span class="here" id="crumbHere"></span></div>

	<p class="lead hidden" id="uploadLead">Upload a puzzle for any date. Every day, Sunday included, has three: morning (9:00 AM), afternoon (3:00 PM) and night (9:00 PM), 4 words each. The morning puzzle opens the moment you publish it, but not before 9:00 AM. The afternoon and night puzzles open at their time. Players get a notification when each opens. India time.</p>

	<section id="signin">
		<h2>Sign in</h2>
		<span class="hint center">Admins only.</span>
		<button class="social" id="socialBtn"><svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9.1 3.6l6.8-6.8C35.8 2.4 30.3 0 24 0 14.6 0 6.6 5.4 2.7 13.3l7.9 6.1C12.5 13.6 17.8 9.5 24 9.5z"/><path fill="#4285F4" d="M46.1 24.6c0-1.6-.1-3.1-.4-4.6H24v9h12.4c-.5 2.9-2.2 5.3-4.6 6.9l7.4 5.7c4.3-4 6.9-9.9 6.9-17z"/><path fill="#FBBC05" d="M10.6 28.6c-.5-1.4-.8-3-.8-4.6s.3-3.2.8-4.6l-7.9-6.1C1 16.6 0 20.2 0 24s1 7.4 2.7 10.7l7.9-6.1z"/><path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.4-5.7c-2.1 1.4-4.8 2.3-8.5 2.3-6.2 0-11.5-4.1-13.4-9.9l-7.9 6.1C6.6 42.6 14.6 48 24 48z"/></svg>Sign in with Google or Zoho</button>
		<div class="msg" id="socialMsg"></div>
		<div class="or">or with a BluJem password</div>
		<label for="email">Email</label><input id="email" type="email" autocomplete="username">
		<label for="password">Password</label><input id="password" type="password" autocomplete="current-password">
		<button class="primary" id="signinBtn">Sign in</button>
		<div class="msg" id="signinMsg"></div>
	</section>

	<section id="form" class="hidden">
		<h2 id="formTitle">Puzzle</h2>
		<div id="editing" class="hidden" style="margin-bottom:12px">
			<div class="msg good" id="editingText" style="margin-top:0"></div>
			<div style="display:flex;gap:12px;flex-wrap:wrap;margin:10px 0">
				<figure style="margin:0" id="editCartoonBox"><img id="editCartoon" alt="" style="max-height:160px;border-radius:8px;border:1px solid var(--line)"><figcaption class="hint">Cartoon now</figcaption></figure>
				<figure style="margin:0" id="editWordlessBox"><img id="editWordless" alt="" style="max-height:160px;border-radius:8px;border:1px solid var(--line)"><figcaption class="hint">Wordless now</figcaption></figure>
			</div>
			<button class="plain" id="cancelEdit" style="margin:0">Cancel edit</button>
		</div>
		<div class="row">
			<div class="datebox"><label for="dateBtn">Date</label><input id="date" type="hidden"><button type="button" class="datefield" id="dateBtn" aria-haspopup="dialog"><span id="dateText">Pick a day</span><span aria-hidden="true">📅</span></button><div class="cal hidden" id="cal" aria-label="Days already uploaded"></div></div>
			<div><label for="slot">Slot</label><select id="slot"></select></div>
		</div>
		<label for="cartoon">Cartoon <span class="hint">— the coloured cartoon only (PNG or JPEG). Leave empty to keep the one already uploaded.</span></label>
		<input id="cartoon" type="file" accept="image/png,image/jpeg">
		<figure class="preview hidden" id="cartoonPreviewBox"><img id="cartoonPreview" alt="Cartoon to upload"><figcaption class="hint">This cartoon will be uploaded.</figcaption></figure>
		<label for="wordless">Wordless cartoon <span class="hint">— the same cartoon with no speech bubbles or caption, for the picture players share. Optional; leave empty to keep the one already uploaded.</span></label>
		<input id="wordless" type="file" accept="image/png,image/jpeg">
		<figure class="preview hidden" id="wordlessPreviewBox"><img id="wordlessPreview" alt="Wordless cartoon to upload"><figcaption class="hint">This wordless cartoon will be uploaded.</figcaption></figure>
		<div class="msg" id="sameMsg"></div>
		<label for="text">Puzzle text <span class="hint">— one jumbled word per line, circled letters in CAPITALS; a blank line; then the answer boxes □ (or _), punctuation as printed. A new line in the boxes is where the answer wraps.</span></label>
		<textarea id="text" spellcheck="false" placeholder="aDRra&#10;tuYpT&#10;hcNRcu&#10;cRaoCD&#10;&#10;□□□-□□□-&#10;□□□"></textarea>
		<button class="plain" id="checkBtn">Check</button>
		<div class="msg" id="checkMsg"></div>

		<div id="answers" class="hidden">
			<h2 style="margin-top:24px">Answers <span class="hint">— kept on the server; players never receive them before solving. Optional now: without them the puzzle is saved but not published.</span></h2>
			<div class="words" id="wordAnswers"></div>
			<div class="wordhead"><label>Circled letters <span class="hint">— fill in as the words are solved</span></label><button type="button" class="shuffle" id="shuffleFinal" tabindex="-1" title="Shuffle the circled letters" aria-label="Shuffle the circled letters">&#x21bb;</button></div>
			<div class="tiles" id="finalTiles"></div>
			<label for="final">Final answer <span class="hint">— letters in the boxes' order; punctuation comes from the boxes</span></label>
			<input id="final" autocomplete="off" spellcheck="false" style="text-transform:uppercase">
			<button class="primary" id="uploadBtn">Upload</button>
		</div>
		<div class="msg" id="uploadMsg"></div>
	</section>

	<section id="upcoming" class="hidden">
		<h2>Uploaded puzzles</h2>
		<div class="scroll"><table><thead><tr><th>Pictures</th><th>Date</th><th>Slot</th><th>Goes live</th><th>Status</th><th></th></tr></thead><tbody id="list"></tbody></table></div>
		<p class="hint">Tap a picture to see it full size.</p>
		<div class="msg" id="listMsg"></div>
	</section>

	<section id="players" class="hidden">
		<h2>All players <span class="hint" id="playerCount"></span></h2>
		<p class="hint">Every player, most points first. Only admins can see this list.</p>
		<div class="scroll"><table><thead><tr><th>#</th><th>Player name</th><th>Player since</th><th class="num">Games played</th><th class="num">Total score</th></tr></thead><tbody id="playerList"></tbody></table></div>
		<button class="plain" id="playersRefresh">Refresh</button>
		<div class="msg" id="playersMsg"></div>
	</section>

	<section id="draft" class="hidden">
		<h2 id="draftTitle">Draft</h2>
		<p class="hint">Sent by the BluJem GPT. Check the cartoon, the letters and the answers before publishing. Players see nothing until you publish.</p>
		<img id="draftImg" alt="Cartoon" style="max-width:100%;border-radius:10px;border:1px solid var(--line)">
		<table><thead><tr><th>Scrambled</th><th>Answer</th></tr></thead><tbody id="draftWords"></tbody></table>
		<p><b>Final answer:</b> <span id="draftFinal"></span></p>
		<p id="draftClue" class="hint"></p>
		<button class="primary" id="draftPublish">Publish</button>
		<button class="plain" id="draftClose">Close</button>
		<div class="msg" id="draftMsg"></div>
	</section>
</main>
<div id="viewer" class="hidden"><img id="viewerImg" alt="Full-size picture"></div>
<script>
(() => {
	const AUTH = '/server/jumble_auth/execute/';
	const DATA = '/server/jumble_data/execute/';
	const $ = (id) => document.getElementById(id);
	let token = sessionStorage.getItem('blujemToken') || '';

	async function call(url, body) {
		const res = await fetch(url, {
			method: 'POST',
			headers: Object.assign({ 'Content-Type': 'application/json' }, token ? { 'X-Jumble-Token': token } : {}),
			body: JSON.stringify(body || {})
		});
		let json = {};
		try { json = await res.json(); } catch (e) {}
		if (res.status === 401 && token) { signOut(); throw new Error('Signed out. Sign in again.'); }
		if (!res.ok && !json.problems) throw new Error(json.error || ('Request failed (' + res.status + ').'));
		return json;
	}

	function show(el, text, ok) { el.textContent = text; el.className = 'msg ' + (ok ? 'good' : 'bad'); }

	// Three screens after sign-in: the Admin home with its two buttons, Upload
	// and Leaderboard. The address (#upload, #leaderboard) says which, so the
	// browser's back button returns to the home.
	const VIEWS = { home: ['home'], upload: ['uploadLead', 'form', 'upcoming'], leaderboard: ['players'] };
	const ALL = ['signin', 'home', 'backBar', 'uploadLead', 'form', 'upcoming', 'draft', 'players'];
	let signedInNow = false;

	function showView() {
		if (!signedInNow) return;
		const view = VIEWS[location.hash.slice(1)] ? location.hash.slice(1) : 'home';
		ALL.forEach((id) => $(id).classList.add('hidden'));
		VIEWS[view].forEach((id) => $(id).classList.remove('hidden'));
		if (view !== 'home') $('backBar').classList.remove('hidden');
		$('crumbHere').textContent = view === 'upload' ? 'Upload puzzles' : view === 'leaderboard' ? 'Leaderboard' : '';
		$('signOutBtn').classList.remove('hidden');
		if (view === 'upload') loadList();
		if (view === 'leaderboard') loadPlayers();
		document.title = view === 'upload' ? 'Upload · BluJem Admin' : view === 'leaderboard' ? 'Leaderboard · BluJem Admin' : 'BluJem Admin';
		window.scrollTo(0, 0);
	}
	window.addEventListener('hashchange', showView);
	$('goUpload').onclick = () => { location.hash = 'upload'; };
	$('goBoard').onclick = () => { location.hash = 'leaderboard'; };
	$('backBtn').onclick = () => { location.hash = ''; };

	function signOut() {
		token = ''; signedInNow = false; sessionStorage.removeItem('blujemToken');
		ALL.forEach((id) => $(id).classList.add('hidden'));
		$('signOutBtn').classList.add('hidden');
		$('signin').classList.remove('hidden');
	}
	$('signOutBtn').onclick = () => { signOut(); history.replaceState(null, '', location.pathname); };

	function signedIn() { signedInNow = true; showView(); }

	// Google or Zoho: Catalyst's own sign-in page checks the account (no
	// password ever reaches this page) and sends the browser back here; its
	// session then becomes a BluJem one, the same way the app does it.
	$('socialBtn').onclick = () => {
		location.href = '/__catalyst/auth/login?service_url=' + encodeURIComponent(location.pathname + '?social=1');
	};

	function cookie(name) {
		const hit = document.cookie.split('; ').find((c) => c.startsWith(name + '='));
		return hit ? decodeURIComponent(hit.slice(name.length + 1)) : '';
	}

	async function finishSocial() {
		history.replaceState(null, '', location.pathname);
		show($('socialMsg'), 'Signing in…', true);
		try {
			const res = await fetch(AUTH + 'zoho', {
				method: 'POST',
				credentials: 'same-origin',
				headers: { 'Content-Type': 'application/json', 'X-ZCSRF-TOKEN': 'zd_csrparam=' + cookie('ZD_CSRF_TOKEN') },
				body: '{}'
			});
			let reply = {};
			try { reply = await res.json(); } catch (e) {}
			if (res.status === 401) throw new Error('The Google or Zoho sign-in did not finish. Try again.');
			if (!res.ok) throw new Error(reply.error || 'Sign-in did not finish. Try again.');
			if (!reply.user || reply.user.role !== 'admin') {
				show($('socialMsg'), (reply.user ? reply.user.email + ' is' : 'This account is') + ' not a BluJem admin.', false);
				return;
			}
			token = reply.token; sessionStorage.setItem('blujemToken', token); $('socialMsg').textContent = ''; signedIn();
		} catch (e) { show($('socialMsg'), e.message, false); }
	}

	// Enter in the email or password box signs in, like tapping the button.
	['email', 'password'].forEach((id) => $(id).addEventListener('keydown', (e) => {
		if (e.key === 'Enter') { e.preventDefault(); $('signinBtn').click(); }
	}));
	$('signinBtn').onclick = async () => {
		try {
			const reply = await call(AUTH + 'login', { email: $('email').value.trim(), password: $('password').value });
			if (!reply.user || reply.user.role !== 'admin') { show($('signinMsg'), 'This account is not a BluJem admin.', false); return; }
			token = reply.token; sessionStorage.setItem('blujemToken', token); $('password').value = ''; signedIn();
		} catch (e) { show($('signinMsg'), e.message, false); }
	};

	// ---- Calendar under the date: days with puzzles uploaded are coloured
	// (green when all three slots are in, yellow when some are). Tap a day
	// to pick it.
	let uploaded = {};
	let calMonth = null;
	const DAY_SLOTS = ['morning', 'evening', 'night'];
	function drawCal() {
		const picked = $('date').value;
		const todayIso = new Date(Date.now() + 5.5 * 3600e3).toISOString().slice(0, 10);
		if (!calMonth) calMonth = (picked || todayIso).slice(0, 7);
		const [y, m] = calMonth.split('-').map(Number);
		const first = new Date(Date.UTC(y, m - 1, 1));
		const count = new Date(Date.UTC(y, m, 0)).getUTCDate();
		const pad = (n) => String(n).padStart(2, '0');
		let cells = ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => '<span class="dow">' + d + '</span>').join('');
		cells += '<span></span>'.repeat(first.getUTCDay());
		for (let d = 1; d <= count; d++) {
			const iso = y + '-' + pad(m) + '-' + pad(d);
			const slots = uploaded[iso] || [];
			const done = DAY_SLOTS.filter((s) => slots.includes(s)).length;
			const cls = ['day', done >= 3 ? 'full' : done ? 'some' : '', iso === todayIso ? 'today' : '', iso === picked ? 'picked' : ''].filter(Boolean).join(' ');
			const title = done ? 'Uploaded: ' + DAY_SLOTS.filter((s) => slots.includes(s)).map((s) => SLOT_NAMES[s]).join(', ') : 'Nothing uploaded';
			cells += '<button type="button" tabindex="-1" class="' + cls + '" data-day="' + iso + '" title="' + title + '">' + d + '</button>';
		}
		const name = first.toLocaleString('en-IN', { month: 'long', year: 'numeric', timeZone: 'UTC' });
		$('cal').innerHTML = '<div class="head"><button type="button" class="plain" tabindex="-1" data-month="-1" aria-label="Previous month">‹</button><span>' + name + '</span><button type="button" class="plain" tabindex="-1" data-month="1" aria-label="Next month">›</button></div><div class="days">' + cells + '</div><div class="key"><span><i style="background:#7CC98A"></i>All 3 uploaded</span><span><i style="background:#F2C14E"></i>Some uploaded</span></div>';
		$('cal').querySelectorAll('[data-month]').forEach((b) => { b.onclick = () => {
			const t = new Date(Date.UTC(y, m - 1 + Number(b.dataset.month), 1));
			calMonth = t.getUTCFullYear() + '-' + pad(t.getUTCMonth() + 1);
			drawCal();
		}; });
		$('cal').querySelectorAll('[data-day]').forEach((b) => { b.onclick = () => {
			if ($('date').disabled) return;
			$('date').value = b.dataset.day;
			fillSlots();
			$('cal').classList.add('hidden');
		}; });
	}

	// The calendar opens in place of the browser's own date picker, only when
	// the date is clicked; it closes on a day, a click elsewhere, or Esc.
	// The day picked, shown on the Date button (the value itself is kept in
	// the hidden #date field as YYYY-MM-DD).
	function showDate() {
		const iso = $('date').value;
		$('dateText').textContent = iso ? new Date(iso + 'T00:00:00Z').toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }) : 'Pick a day';
		$('dateBtn').disabled = $('date').disabled;
	}
	$('dateBtn').onclick = () => { if (!$('date').disabled) { drawCal(); $('cal').classList.toggle('hidden'); } };
	document.addEventListener('keydown', (e) => { if (e.key === 'Escape') $('cal').classList.add('hidden'); });
	document.addEventListener('mousedown', (e) => {
		if (!e.target.closest || !e.target.closest('.datebox')) $('cal').classList.add('hidden');
	});

	function fillSlots() {
		const iso = $('date').value;
		showDate();
		if (iso) calMonth = iso.slice(0, 7);
		const taken = uploaded[iso] || [];
		const mark = (v, t) => taken.includes(v) ? t + ' · ✓ uploaded' : t;
		const options = !iso ? [] : [['morning', mark('morning', 'Morning · 9:00 AM, or when published if later · 4 words')], ['evening', mark('evening', 'Afternoon · 3:00 PM · 4 words')], ['night', mark('night', 'Night · 9:00 PM · 4 words')]];
		const keep = $('slot').value;
		$('slot').innerHTML = options.map(([v, t]) => '<option value="' + v + '">' + t + '</option>').join('');
		if (options.some(([v]) => v === keep)) $('slot').value = keep;
		$('answers').classList.add('hidden');
		drawCal();
	}
	$('slot').onchange = () => $('answers').classList.add('hidden');
	$('text').oninput = () => $('answers').classList.add('hidden');

	const form = () => ({ date: $('date').value, slot: $('slot').value, text: $('text').value });

	// ---- Playing it through: shuffle buttons for each word, and the circled
	// letters gathered from the typed answers, ready for the final answer.
	let parsedWords = [];
	let finalOrder = null;
	// The answer boxes as typed (□□□ □□□, □□ □□□□): the circled letters are
	// laid out in them, so the words of the answer show with their gaps.
	let finalPattern = '';

	// [text]'s letters in a new random order (a different one when possible).
	function shuffled(text) {
		const letters = [...text];
		if (new Set(letters).size < 2) return text;
		let out = text;
		while (out === text) {
			for (let i = letters.length - 1; i > 0; i--) {
				const j = Math.floor(Math.random() * (i + 1));
				[letters[i], letters[j]] = [letters[j], letters[i]];
			}
			out = letters.join('');
		}
		return out;
	}

	const sortedLetters = (t) => [...t].sort().join('');

	// The circled letters of each word whose answer uses exactly its letters;
	// the others stay as empty circles until they are solved.
	function circledLetters() {
		return parsedWords.flatMap((w, i) => {
			const input = $('word' + i);
			const answer = input && !input.dataset.jumbled ? input.value.trim().toUpperCase() : '';
			const solved = answer.length === w.letters.length && sortedLetters(answer) === sortedLetters(w.letters);
			return w.circled.map((c) => (solved ? answer[c] : ''));
		});
	}

	// [letters] (one per box, '' for a box still empty) in the answer's boxes:
	// a gap between words, the punctuation as typed, a new line where it wraps.
	function answerTiles(letters) {
		const tile = (c) => c ? '<span class="tile">' + esc(c) + '</span>' : '<span class="tile empty">?</span>';
		const boxes = (finalPattern.match(/□/g) || []).length;
		if (boxes !== letters.length) return letters.map(tile).join('');
		// Each word of the answer is kept together on one line.
		let i = 0, out = '', word = '';
		const end = () => { if (word) out += '<span class="word">' + word + '</span>'; word = ''; };
		for (const ch of finalPattern) {
			if (ch === '□') word += tile(letters[i++]);
			else if (ch === NL) { end(); out += '<span class="wrap"></span>'; }
			else if (ch === ' ') { end(); out += '<span class="gap"></span>'; }
			else word += '<span class="mark">' + esc(ch) + '</span>';
		}
		end();
		return out;
	}

	// The circled letters put in the Final answer box, a space between the
	// answer's words, for the admin to rearrange. Until the admin types in it,
	// the box is only a guide: Upload does not take it as the answer.
	let finalTyped = false;
	function prefillFinal(letters) {
		if (finalTyped) return;
		const boxes = (finalPattern.match(/□/g) || []).length;
		let text = letters.filter(Boolean).join('');
		if (boxes === letters.length) {
			let i = 0;
			text = [...finalPattern].map((ch) => (ch === '□' ? letters[i++] || '' : ' ')).join('').replace(/ +/g, ' ').trim();
		}
		$('final').value = text;
	}
	$('final').oninput = () => { finalTyped = true; };

	function showFinalLetters() {
		const letters = circledLetters();
		const filled = letters.filter(Boolean);
		const shown = finalOrder && sortedLetters(finalOrder) === sortedLetters(filled.join('')) ? [...finalOrder] : letters;
		$('finalTiles').innerHTML = answerTiles(shown);
		prefillFinal(shown);
	}

	$('shuffleFinal').onclick = () => {
		const filled = circledLetters().filter(Boolean).join('');
		if (!filled) return;
		const empties = circledLetters().length - filled.length;
		finalOrder = shuffled(finalOrder && sortedLetters(finalOrder) === sortedLetters(filled) ? finalOrder : filled);
		$('finalTiles').innerHTML = answerTiles([...finalOrder, ...Array(empties).fill('')]);
		prefillFinal([...finalOrder, ...Array(empties).fill('')]);
	};

	$('checkBtn').onclick = () => check();
	async function check() {
		try {
			const reply = await call(DATA + 'puzzles/upload', Object.assign(form(), { dryRun: true }));
			if (reply.problems && reply.problems.length) { show($('checkMsg'), reply.problems.join('\\n'), false); return false; }
			const p = reply.parsed;
			show($('checkMsg'), 'Looks right: ' + p.words.length + ' words, ' + p.pattern.boxes + ' answer boxes (' + p.pattern.groups.join('-') + '). Goes live ' + reply.goesLive + '.', true);
			// Answers already typed stay when Check is tapped again for the same words.
			const kept = p.words.map((w, i) => {
				const input = $('word' + i);
				return input && !input.dataset.jumbled && parsedWords[i] && sortedLetters(parsedWords[i].letters) === sortedLetters(w.letters) ? input.value : '';
			});
			parsedWords = p.words;
			finalOrder = null;
			finalPattern = String(p.pattern.text || '').replace(/_/g, '□');
			$('wordAnswers').innerHTML = p.words.map((w, i) => '<div class="wordhead"><label for="word' + i + '">Word ' + (i + 1) + ' <span class="hint mix" id="mix' + i + '">' + w.letters + '</span></label><button type="button" class="shuffle" data-shuffle="' + i + '" title="Shuffle these letters" aria-label="Shuffle the letters of word ' + (i + 1) + '" tabindex="-1">&#x21bb;</button></div><input id="word' + i + '" data-word="' + i + '" maxlength="' + w.letters.length + '" autocomplete="off" spellcheck="false" style="text-transform:uppercase">').join('');
			// Each box starts with its jumbled letters, to rearrange in place; it
			// counts as an answer only once the admin has typed in it.
			document.querySelectorAll('[data-word]').forEach((input, i) => {
				const before = kept[i];
				if (before) input.value = before;
				else { input.value = p.words[i].letters; input.dataset.jumbled = '1'; }
				input.oninput = () => { delete input.dataset.jumbled; finalOrder = null; showFinalLetters(); };
			});
			document.querySelectorAll('[data-shuffle]').forEach((b) => { b.onclick = () => {
				const i = b.dataset.shuffle, el = $('mix' + i), input = $('word' + i);
				el.textContent = shuffled(el.textContent);
				if (input.dataset.jumbled) input.value = el.textContent;
			}; });
			showFinalLetters();
			$('answers').classList.remove('hidden');
			return true;
		} catch (e) { show($('checkMsg'), e.message, false); return false; }
	}

	// ---- Editing a puzzle already uploaded, live or not: the form is filled
	// with it, its date and slot locked, and Upload saves it in place — same
	// puzzle, same opening time, no second notification. Pictures left empty
	// stay as they are.
	let listed = {};
	let editing = null;
	const NL = String.fromCharCode(10);

	// Only cartoon puzzles, whose page the app builds from the letters; an
	// old full newspaper sheet keeps its own layout and is not edited here.
	function editable(p) {
		const key = String(p.sheetKey || '');
		return key.startsWith('puzzles/') || key.startsWith('drafts/') || key.includes('-cartoon');
	}

	// The text as it was typed, or rebuilt from the stored words: circled
	// letters in capitals, a blank line, then the answer boxes.
	function puzzleTextOf(p) {
		if (p.puzzleText) return p.puzzleText;
		let words = [];
		try { words = JSON.parse(p.words || '[]'); } catch (e) {}
		const lines = words.map((w) => [...String(w.scrambled || '')].map((c, i) => ((w.boxes || [])[i] || {}).c ? c.toUpperCase() : c.toLowerCase()).join(''));
		return lines.join(NL) + NL + NL + String(p.finalPattern || '');
	}

	async function picture(key, img, box) {
		img.removeAttribute('src');
		if (box) box.style.display = 'none';
		if (!key) return;
		try {
			const res = await fetch(DATA + 'puzzles/sheet', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Jumble-Token': token }, body: JSON.stringify({ key }) });
			if (res.ok) { img.src = URL.createObjectURL(await res.blob()); if (box) box.style.display = ''; }
		} catch (e) {}
	}

	async function startEdit(p) {
		editing = p;
		$('date').value = p.publishDate;
		fillSlots();
		$('slot').value = p.slot;
		$('date').disabled = true;
		showDate();
		$('slot').disabled = true;
		for (const name of ['cartoon', 'wordless']) {
			$(name).value = '';
			previewFile($(name), $(name + 'Preview'), $(name + 'PreviewBox'));
		}
		$('text').value = puzzleTextOf(p);
		finalTyped = false;
		$('uploadMsg').textContent = '';
		$('formTitle').textContent = 'Edit puzzle';
		$('editingText').textContent = 'Editing ' + p.publishDate + ' · ' + (SLOT_NAMES[p.slot] || p.slot) + (p.published ? ' (already published)' : '') + '. Change anything, then tap Upload: it is saved in place, players keep their results and get no second notification. Choose a picture only to replace it.';
		$('editing').classList.remove('hidden');
		$('form').scrollIntoView({ behavior: 'smooth' });
		picture(p.sheetKey, $('editCartoon'), $('editCartoonBox'));
		const sheet = String(p.sheetKey || '');
		picture(sheet ? sheet.replace(/[.][^./]+$/, '') + '-wordless.png' : '', $('editWordless'), $('editWordlessBox'));
		if (!(await check())) return;
		let words = [];
		try { words = JSON.parse(p.words || '[]'); } catch (e) {}
		document.querySelectorAll('[data-word]').forEach((input, i) => {
			const answer = words[i] && words[i].answer;
			if (answer) { input.value = answer; delete input.dataset.jumbled; }
		});
		showFinalLetters();
		if (p.finalAnswer) { $('final').value = String(p.finalAnswer).replace(/[^A-Za-z]+/g, ' ').trim(); finalTyped = true; }
	}

	function endEdit() {
		editing = null;
		$('date').disabled = false;
		showDate();
		$('slot').disabled = false;
		$('formTitle').textContent = 'Puzzle';
		$('editing').classList.add('hidden');
	}

	$('cancelEdit').onclick = () => { clearForm(); $('uploadMsg').textContent = ''; };

	// Shows the picture just chosen, large enough to read, before it is sent.
	function previewFile(input, img, box) {
		if (img.src && img.src.startsWith('blob:')) URL.revokeObjectURL(img.src);
		const file = input.files[0];
		if (!file) { img.removeAttribute('src'); box.classList.add('hidden'); return; }
		img.src = URL.createObjectURL(file);
		box.classList.remove('hidden');
	}
	$('cartoon').onchange = () => { previewFile($('cartoon'), $('cartoonPreview'), $('cartoonPreviewBox')); checkSame(); };
	$('wordless').onchange = () => { previewFile($('wordless'), $('wordlessPreview'), $('wordlessPreviewBox')); checkSame(); };

	// ---- Same cartoon? The wordless picture must be the cartoon with only the
	// bubbles and caption taken out. Both are shrunk to 96x144 and compared with
	// pixelmatch: the same cartoon differs in under 10% of the pixels (the
	// bubbles), two different cartoons in 80% or more. Over 40% is flagged.
	const SAME_W = 96, SAME_H = 144, SAME_LIMIT = 0.4;
	let pixelmatch = null;
	async function loadPixelmatch() {
		if (!pixelmatch) pixelmatch = (await import('https://cdn.jsdelivr.net/npm/pixelmatch@5.3.0/+esm')).default;
		return pixelmatch;
	}
	async function pixelsOf(img) {
		if (!img || !img.getAttribute('src')) return null;
		if (!img.complete || !img.naturalWidth) await img.decode().catch(() => {});
		if (!img.naturalWidth) return null;
		const canvas = document.createElement('canvas');
		canvas.width = SAME_W; canvas.height = SAME_H;
		const ctx = canvas.getContext('2d');
		ctx.drawImage(img, 0, 0, SAME_W, SAME_H);
		return { data: ctx.getImageData(0, 0, SAME_W, SAME_H).data, ratio: img.naturalWidth / img.naturalHeight };
	}
	// The cartoon and the wordless cartoon to compare: the one just chosen,
	// or, while editing, the one already uploaded.
	const shownPicture = (name) => ($(name).files[0] ? $(name + 'Preview') : editing ? $(name === 'cartoon' ? 'editCartoon' : 'editWordless') : null);
	// Returns '' when the two look like the same cartoon (or one is missing),
	// otherwise the problem to show the admin.
	async function sameProblem() {
		if (!$('cartoon').files[0] && !$('wordless').files[0]) return '';
		const [a, b] = await Promise.all([pixelsOf(shownPicture('cartoon')), pixelsOf(shownPicture('wordless'))]);
		if (!a || !b) return '';
		const match = await loadPixelmatch();
		const changed = match(a.data, b.data, null, SAME_W, SAME_H, { threshold: 0.1 }) / (SAME_W * SAME_H);
		const shape = Math.abs(a.ratio - b.ratio) / a.ratio;
		if (changed <= SAME_LIMIT && shape <= 0.05) return '';
		return 'The cartoon and the wordless cartoon do not look like the same picture (' + Math.round(changed * 100) + '% different' + (shape > 0.05 ? ', different shape' : '') + '). Check that you chose the right two files.';
	}
	async function checkSame() {
		$('sameMsg').textContent = '';
		try {
			const problem = await sameProblem();
			if (problem) { show($('sameMsg'), problem, false); alert(problem); }
		} catch (e) { show($('sameMsg'), 'Could not compare the two pictures: ' + e.message, false); }
	}

	// An empty form, ready for the next puzzle.
	function clearForm() {
		endEdit();
		$('sameMsg').textContent = '';
		$('date').value = '';
		fillSlots();
		$('text').value = '';
		$('final').value = '';
		finalTyped = false;
		$('wordAnswers').innerHTML = '';
		parsedWords = [];
		finalOrder = null;
		$('finalTiles').innerHTML = '';
		$('checkMsg').textContent = '';
		for (const name of ['cartoon', 'wordless']) {
			$(name).value = '';
			previewFile($(name), $(name + 'Preview'), $(name + 'PreviewBox'));
		}
	}

	function readFile(file) {
		return new Promise((resolve, reject) => {
			const r = new FileReader();
			r.onload = () => resolve(String(r.result).split(',')[1] || '');
			r.onerror = () => reject(new Error('The cartoon could not be read.'));
			r.readAsDataURL(file);
		});
	}

	$('uploadBtn').onclick = async () => {
		const btn = $('uploadBtn');
		btn.disabled = true;
		try {
			let problem = '';
			try { problem = await sameProblem(); } catch (e) {}
			if (problem && !confirm(problem + '\\n\\nUpload anyway?')) { show($('uploadMsg'), problem, false); return; }
			const file = $('cartoon').files[0];
			const wordless = $('wordless').files[0];
			const final = finalTyped ? $('final').value.trim() : '';
			const words = Array.from(document.querySelectorAll('[data-word]')).map((i) => (i.dataset.jumbled ? '' : i.value.trim()));
			const body = Object.assign(form(), {
				cartoonBase64: file ? await readFile(file) : '',
				wordlessBase64: wordless ? await readFile(wordless) : '',
				answers: words.some(Boolean) || final ? { words, final } : null
			});
			show($('uploadMsg'), 'Uploading…', true);
			const reply = await call(DATA + 'puzzles/upload', body);
			if (reply.problems && reply.problems.length) { show($('uploadMsg'), reply.problems.join('\\n'), false); return; }
			show($('uploadMsg'), (reply.published ? 'Published. ' : 'Saved. ') + 'Goes live ' + reply.goesLive + '.' + (reply.notified && reply.notified.sent ? ' Players have been notified.' : '') + (reply.warnings && reply.warnings.length ? '\\n' + reply.warnings.join('\\n') : ''), true);
			if (editing && !reply.published) show($('uploadMsg'), 'Saved, but NOT published: fill in every answer and the final answer, then Upload again.', false);
			else { clearForm(); $('form').scrollIntoView({ behavior: 'smooth' }); }
			loadList();
		} catch (e) { show($('uploadMsg'), e.message, false); }
		finally { btn.disabled = false; }
	};

	const SLOT_NAMES = { morning: 'Morning', evening: 'Afternoon', night: 'Night', sunday: 'Sunday' };
	const esc = (t) => String(t == null ? '' : t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
	let drafts = {};

	const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
	function sinceLabel(day) {
		const m = /^([0-9]{4})-([0-9]{2})-([0-9]{2})$/.exec(day || '');
		return m ? Number(m[3]) + ' ' + MONTHS[Number(m[2]) - 1] + ' ' + m[1] : '—';
	}

	async function loadPlayers() {
		const body = $('playerList');
		$('playersMsg').textContent = '';
		try {
			const { players } = await call(DATA + 'admin/players');
			body.replaceChildren(...players.map((p, i) => {
				const tr = document.createElement('tr');
				[String(i + 1), p.name, sinceLabel(p.since), String(p.games), p.points.toLocaleString('en-IN')].forEach((text, c) => {
					const td = document.createElement('td');
					td.textContent = text;
					if (c >= 3) td.className = 'num';
					tr.appendChild(td);
				});
				return tr;
			}));
			$('playerCount').textContent = '— ' + players.length + (players.length === 1 ? ' player' : ' players');
			if (!players.length) show($('playersMsg'), 'No players yet.', true);
		} catch (e) {
			show($('playersMsg'), e.message, false);
		}
	}
	$('playersRefresh').onclick = loadPlayers;

	async function loadList() {
		try {
			const reply = await call(DATA + 'puzzles/list', { client: 2, all: true });
			const today = new Date(Date.now() + 5.5 * 3600e3).toISOString().slice(0, 10);
			const all = reply.puzzles || [];
			uploaded = {};
			all.forEach((p) => { (uploaded[p.publishDate] = uploaded[p.publishDate] || []).push(p.slot); });
			const taken = uploaded[$('date').value] || [];
			[...$('slot').options].forEach((o) => { o.textContent = o.textContent.replace(' · ✓ uploaded', '') + (taken.includes(o.value) ? ' · ✓ uploaded' : ''); });
			drawCal();
			const live = new Set(all.filter((p) => p.published).map((p) => p.publishDate + '/' + p.slot));
			// A draft from the GPT has its answers; one whose slot is taken is left out.
			const rows = all.filter((p) => p.publishDate >= today)
				.filter((p) => p.published || !live.has(p.publishDate + '/' + p.slot))
				.sort((a, b) => a.publishAt - b.publishAt);
			const when = (ms) => new Date(ms).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' });
			drafts = {};
			listed = {};
			$('list').innerHTML = rows.length ? rows.map((p) => {
				let status = p.published ? (p.publishAt <= Date.now() ? 'Live' : 'Scheduled') : 'Needs answers';
				if (!p.published && p.finalAnswer) { drafts[p.id] = p; status = '<b>Draft</b> <button class="plain" data-check="' + esc(p.id) + '" style="margin:0;padding:4px 10px">Check</button>'; }
				listed[p.id] = p;
				const edit = editable(p) ? '<button class="plain" data-edit="' + esc(p.id) + '" style="margin:0;padding:4px 10px">Edit</button>' : '';
				return '<tr><td><div class="thumbs" data-thumbs="' + esc(p.id) + '"><span class="none">…</span></div></td><td>' + esc(p.publishDate) + '</td><td>' + esc(SLOT_NAMES[p.slot] || p.slot) + '</td><td>' + when(p.publishAt) + '</td><td>' + status + '</td><td>' + edit + '</td></tr>';
			}).join('') : '<tr><td colspan="6">Nothing uploaded from today on.</td></tr>';
			document.querySelectorAll('[data-thumbs]').forEach((box) => thumbs(listed[box.dataset.thumbs], box));
			document.querySelectorAll('[data-check]').forEach((b) => { b.onclick = () => openDraft(drafts[b.dataset.check]); });
			document.querySelectorAll('[data-edit]').forEach((b) => { b.onclick = () => startEdit(listed[b.dataset.edit]); });
		} catch (e) { $('list').innerHTML = '<tr><td colspan="6" class="bad">' + esc(e.message) + '</td></tr>'; }
	}

	// The cartoon and the wordless cartoon of an uploaded puzzle, small, each
	// opening full size when tapped. Loaded one row at a time, after the list.
	const pictures = {};
	async function pictureUrl(key) {
		if (!key) return '';
		if (key in pictures) return pictures[key];
		try {
			const res = await fetch(DATA + 'puzzles/sheet', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Jumble-Token': token }, body: JSON.stringify({ key }) });
			pictures[key] = res.ok ? URL.createObjectURL(await res.blob()) : '';
		} catch (e) { return ''; }
		return pictures[key];
	}
	async function thumbs(p, box) {
		if (!p) return;
		const sheet = String(p.sheetKey || '');
		const keys = [['Cartoon', sheet], ['Wordless', sheet ? sheet.replace(/[.][^./]+$/, '') + '-wordless.png' : '']];
		const imgs = [];
		for (const [name, key] of keys) {
			const url = await pictureUrl(key);
			if (!url) continue;
			const img = document.createElement('img');
			img.src = url; img.alt = name; img.title = name + ' — tap to enlarge';
			img.onclick = () => { $('viewerImg').src = url; $('viewer').classList.remove('hidden'); };
			imgs.push(img);
		}
		box.replaceChildren(...(imgs.length ? imgs : [Object.assign(document.createElement('span'), { className: 'none', textContent: 'No picture' })]));
	}
	$('viewer').onclick = () => { $('viewer').classList.add('hidden'); $('viewerImg').removeAttribute('src'); };
	document.addEventListener('keydown', (e) => { if (e.key === 'Escape') $('viewer').click(); });

	let openId = '';
	async function openDraft(p) {
		openId = p.id;
		$('draft').classList.remove('hidden');
		$('draftMsg').textContent = '';
		$('draftTitle').textContent = 'Draft · ' + p.publishDate + ' · ' + (SLOT_NAMES[p.slot] || p.slot);
		let words = [];
		try { words = JSON.parse(p.words || '[]'); } catch (e) {}
		$('draftWords').innerHTML = words.map((w) => {
			const circled = (w.boxes || []).map((b, i) => (b.c ? i : -1)).filter((i) => i >= 0);
			const shown = [...String(w.scrambled || '')].map((c, i) => circled.includes(i) ? '<b style="color:var(--accent)">' + esc(c) + '</b>' : esc(c.toLowerCase())).join('');
			return '<tr><td style="font-family:Fredoka,Inter,sans-serif;letter-spacing:.1em">' + shown + '</td><td>' + esc(w.answer) + '</td></tr>';
		}).join('');
		$('draftFinal').textContent = p.finalAnswer + '  (' + (p.finalPattern || '').replace(/\\n/g, ' ') + ')';
		$('draftClue').textContent = p.finalClue ? 'Caption: ' + p.finalClue : '';
		$('draftImg').removeAttribute('src');
		$('draft').scrollIntoView({ behavior: 'smooth' });
		try {
			const res = await fetch(DATA + 'puzzles/sheet', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Jumble-Token': token }, body: JSON.stringify({ key: p.sheetKey }) });
			if (res.ok) $('draftImg').src = URL.createObjectURL(await res.blob());
		} catch (e) {}
	}
	$('draftClose').onclick = () => { $('draft').classList.add('hidden'); openId = ''; };
	$('draftPublish').onclick = async () => {
		const btn = $('draftPublish');
		btn.disabled = true;
		try {
			const reply = await call(DATA + 'puzzles/publish-draft', { id: openId });
			show($('draftMsg'), 'Published. Goes live ' + reply.goesLive + '.' + (reply.notified && reply.notified.sent ? ' Players have been notified.' : ' Players are notified when it opens.'), true);
			loadList();
		} catch (e) { show($('draftMsg'), e.message, false); }
		finally { btn.disabled = false; }
	};

	const tomorrow = new Date(Date.now() + 5.5 * 3600e3 + 864e5).toISOString().slice(0, 10);
	$('date').value = tomorrow;
	fillSlots();
	if (token) signedIn();
	else if (new URLSearchParams(location.search).get('social')) finishSocial();
})();
</script>
</body>
</html>`;
}

module.exports = { uploadPage };
