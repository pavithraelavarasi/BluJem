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
	header.bar .logo { height: 40px; width: auto; flex: none; display: block; }
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
	.modal { position: fixed; inset: 0; z-index: 50; background: rgba(22,38,74,.45); display: grid; place-items: center; padding: 16px; }
	.modal .box { background: var(--card); border-radius: 18px; padding: 22px 22px 18px; max-width: 380px; width: 100%; box-shadow: 0 20px 50px rgba(22,38,74,.3); text-align: center; }
	.modal .ico { width: 46px; height: 46px; border-radius: 50%; background: #FBEAE8; color: var(--bad); display: grid; place-items: center; margin: 0 auto 10px; font-size: 24px; font-weight: 700; }
	.modal h3 { font: 600 1.15rem/1.3 Fredoka, Inter, sans-serif; margin: 0 0 6px; color: var(--ink); }
	.modal p { margin: 0 0 16px; color: var(--soft); font-size: .95rem; }
	.modal .acts { display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }
	.modal .acts button { margin: 0; }
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
<header class="bar"><div class="in"><img class="logo" alt="BluJem" src="data:image/png;base64,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"><h1>Admin</h1><span class="grow"></span><button class="out hidden" id="signOutBtn">Sign out</button></div></header>
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
		<div class="modal hidden" id="sameModal" role="alertdialog" aria-modal="true" aria-labelledby="sameTitle"><div class="box"><div class="ico">!</div><h3 id="sameTitle">Pictures don't match</h3><p>The wordless cartoon isn't the same picture as the cartoon. Please choose the right one.</p><div class="acts"><button type="button" class="plain hidden" id="sameAnyway">Upload anyway</button><button type="button" class="primary" id="sameOk">OK</button></div></div></div>
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
		return "The two pictures don't match (" + Math.round(changed * 100) + '% different' + (shape > 0.05 ? ', different shape' : '') + ').';
	}
	// The in-page pop-up for pictures that don't match. With [canGoOn] it also
	// offers Upload anyway; resolves true only when that is tapped.
	function askSame(canGoOn) {
		return new Promise((done) => {
			$('sameAnyway').classList.toggle('hidden', !canGoOn);
			$('sameModal').classList.remove('hidden');
			$('sameOk').focus();
			const close = (goOn) => { $('sameModal').classList.add('hidden'); document.removeEventListener('keydown', onKey); done(goOn); };
			const onKey = (e) => { if (e.key === 'Escape') close(false); };
			document.addEventListener('keydown', onKey);
			$('sameOk').onclick = () => close(false);
			$('sameAnyway').onclick = () => close(true);
		});
	}
	async function checkSame() {
		$('sameMsg').textContent = '';
		try {
			const problem = await sameProblem();
			if (problem) { show($('sameMsg'), problem, false); await askSame(false); }
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
			if (problem && !(await askSame(true))) { show($('uploadMsg'), problem, false); return; }
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
