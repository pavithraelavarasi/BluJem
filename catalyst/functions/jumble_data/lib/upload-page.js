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
	.cal { margin-top: 10px; border: 1px solid var(--line); border-radius: 14px; padding: 10px 12px; background: #fff; max-width: 360px; }
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
	.words input { font-family: ui-monospace, Menlo, Consolas, monospace; text-transform: uppercase; margin-bottom: 6px; }
	.wordhead { display: flex; align-items: center; gap: 10px; margin: 16px 0 6px; }
	.wordhead label { margin: 0; }
	.mix { font-family: ui-monospace, Menlo, Consolas, monospace; letter-spacing: .15em; font-size: 1.1rem; font-weight: 600; color: var(--ink); }
	button.shuffle { margin: 0; padding: 0; width: 32px; height: 32px; flex: none; border-radius: 9px; border: none; background: #e0123f; color: #fff; font-size: 17px; line-height: 32px; box-shadow: 0 2px 5px rgba(224,18,63,.3); }
	.tiles { display: flex; flex-wrap: wrap; gap: 6px; min-height: 46px; align-items: center; padding: 6px 8px; background: var(--soft-bg); border: 1px dashed var(--line); border-radius: 10px; margin-bottom: 6px; }
	.tile { width: 34px; height: 34px; display: grid; place-items: center; border-radius: 50%; border: 2px solid var(--accent); background: #fff; font-family: ui-monospace, Menlo, Consolas, monospace; font-weight: 700; font-size: 1.05rem; }
	.tile.empty { border-style: dashed; border-color: var(--line); color: var(--faint); background: transparent; }
	.tiles .gap { width: 14px; }
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
			<div><label for="date">Date</label><input id="date" type="date"></div>
			<div><label for="slot">Slot</label><select id="slot"></select></div>
		</div>
		<div class="cal" id="cal" aria-label="Days already uploaded"></div>
		<label for="cartoon">Cartoon <span class="hint">— the coloured cartoon only (PNG or JPEG). Leave empty to keep the one already uploaded.</span></label>
		<input id="cartoon" type="file" accept="image/png,image/jpeg">
		<figure class="preview hidden" id="cartoonPreviewBox"><img id="cartoonPreview" alt="Cartoon to upload"><figcaption class="hint">This cartoon will be uploaded.</figcaption></figure>
		<label for="wordless">Wordless cartoon <span class="hint">— the same cartoon with no speech bubbles or caption, for the picture players share. Optional; leave empty to keep the one already uploaded.</span></label>
		<input id="wordless" type="file" accept="image/png,image/jpeg">
		<figure class="preview hidden" id="wordlessPreviewBox"><img id="wordlessPreview" alt="Wordless cartoon to upload"><figcaption class="hint">This wordless cartoon will be uploaded.</figcaption></figure>
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
		}; });
	}

	function fillSlots() {
		const iso = $('date').value;
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
	$('date').onchange = fillSlots;
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
		let i = 0;
		return [...finalPattern].map((ch) => {
			if (ch === '□') return tile(letters[i++]);
			if (ch === NL) return '<span class="wrap"></span>';
			if (ch === ' ') return '<span class="gap"></span>';
			return '<span class="mark">' + esc(ch) + '</span>';
		}).join('');
	}

	function showFinalLetters() {
		const letters = circledLetters();
		const filled = letters.filter(Boolean);
		const shown = finalOrder && sortedLetters(finalOrder) === sortedLetters(filled.join('')) ? [...finalOrder] : letters;
		$('finalTiles').innerHTML = answerTiles(shown);
	}

	$('shuffleFinal').onclick = () => {
		const filled = circledLetters().filter(Boolean).join('');
		if (!filled) return;
		const empties = circledLetters().length - filled.length;
		finalOrder = shuffled(finalOrder && sortedLetters(finalOrder) === sortedLetters(filled) ? finalOrder : filled);
		$('finalTiles').innerHTML = answerTiles([...finalOrder, ...Array(empties).fill('')]);
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
		$('slot').disabled = true;
		for (const name of ['cartoon', 'wordless']) {
			$(name).value = '';
			previewFile($(name), $(name + 'Preview'), $(name + 'PreviewBox'));
		}
		$('text').value = puzzleTextOf(p);
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
		$('final').value = String(p.finalAnswer || '').replace(/[^A-Za-z]+/g, ' ').trim();
	}

	function endEdit() {
		editing = null;
		$('date').disabled = false;
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
	$('cartoon').onchange = () => previewFile($('cartoon'), $('cartoonPreview'), $('cartoonPreviewBox'));
	$('wordless').onchange = () => previewFile($('wordless'), $('wordlessPreview'), $('wordlessPreviewBox'));

	// An empty form, ready for the next puzzle.
	function clearForm() {
		endEdit();
		$('date').value = '';
		fillSlots();
		$('text').value = '';
		$('final').value = '';
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
			const file = $('cartoon').files[0];
			const wordless = $('wordless').files[0];
			const words = Array.from(document.querySelectorAll('[data-word]')).map((i) => (i.dataset.jumbled ? '' : i.value.trim()));
			const body = Object.assign(form(), {
				cartoonBase64: file ? await readFile(file) : '',
				wordlessBase64: wordless ? await readFile(wordless) : '',
				answers: words.some(Boolean) || $('final').value.trim() ? { words, final: $('final').value.trim() } : null
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
			return '<tr><td style="font-family:ui-monospace,Menlo,monospace">' + shown + '</td><td>' + esc(w.answer) + '</td></tr>';
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
