'use strict';

/**
 * The upload page the admin opens on a computer:
 * GET /server/jumble_data/execute/upload. They sign in with their BluJem admin
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
<title>BluJem Upload</title>
<style>
	:root { --bg: #faf6ee; --card: #fffdf8; --ink: #1d1b16; --soft: #5c5648; --line: #e3dccb; --accent: #1f5fae; --bad: #b3261e; --good: #2e7d32; }
	@media (prefers-color-scheme: dark) {
		:root { --bg: #17150f; --card: #211e17; --ink: #f2ede1; --soft: #b9b1a0; --line: #3a352a; --accent: #8db8f0; --bad: #f2b8b5; --good: #8fd694; }
	}
	* { box-sizing: border-box; }
	body { margin: 0; background: var(--bg); color: var(--ink); font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
	main { max-width: 760px; margin: 0 auto; padding: 32px 16px 64px; }
	h1 { font-size: 1.8rem; margin: 0 0 4px; }
	h2 { font-size: 1.1rem; margin: 0 0 12px; }
	p.lead { color: var(--soft); margin: 0 0 24px; }
	section { background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 20px; margin-bottom: 20px; }
	label { display: block; font-weight: 600; margin: 14px 0 4px; }
	.hint { color: var(--soft); font-size: 0.9rem; font-weight: 400; }
	input, select, textarea { width: 100%; font: inherit; color: inherit; background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px; }
	textarea { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 1.1rem; min-height: 200px; }
	.row { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
	@media (max-width: 520px) { .row { grid-template-columns: 1fr; } }
	button { font: inherit; font-weight: 600; border-radius: 10px; padding: 10px 18px; border: 1px solid var(--accent); cursor: pointer; margin: 16px 8px 0 0; }
	button.primary { background: var(--accent); color: var(--bg); }
	button.plain { background: transparent; color: var(--accent); }
	button:disabled { opacity: 0.5; cursor: default; }
	.msg { margin-top: 14px; white-space: pre-line; }
	.bad { color: var(--bad); } .good { color: var(--good); }
	.words input { font-family: ui-monospace, Menlo, Consolas, monospace; text-transform: uppercase; margin-bottom: 6px; }
	table { width: 100%; border-collapse: collapse; font-size: 0.95rem; }
	td, th { text-align: left; padding: 6px 4px; border-bottom: 1px solid var(--line); }
	.hidden { display: none; }
	pre { background: var(--bg); padding: 10px; border-radius: 8px; overflow-x: auto; }
</style>
</head>
<body>
<main>
	<h1>BluJem upload</h1>
	<p class="lead">Upload a puzzle for any date. Every day, Sunday included, has three: morning (9:00 AM), afternoon (3:00 PM) and night (9:00 PM), 4 words each. The morning puzzle opens the moment you publish it, but not before 9:00 AM. The afternoon and night puzzles open at their time. Players get a notification when each opens. India time.</p>

	<section id="signin">
		<h2>Sign in</h2>
		<label for="email">Email</label><input id="email" type="email" autocomplete="username">
		<label for="password">Password</label><input id="password" type="password" autocomplete="current-password">
		<button class="primary" id="signinBtn">Sign in</button>
		<div class="msg" id="signinMsg"></div>
	</section>

	<section id="form" class="hidden">
		<h2>Puzzle</h2>
		<div class="row">
			<div><label for="date">Date</label><input id="date" type="date"></div>
			<div><label for="slot">Slot</label><select id="slot"></select></div>
		</div>
		<label for="cartoon">Cartoon <span class="hint">— the coloured cartoon only (PNG or JPEG). Leave empty to keep the one already uploaded.</span></label>
		<input id="cartoon" type="file" accept="image/png,image/jpeg">
		<label for="text">Puzzle text <span class="hint">— one jumbled word per line, circled letters in CAPITALS; a blank line; then the answer boxes □ (or _), punctuation as printed. A new line in the boxes is where the answer wraps.</span></label>
		<textarea id="text" spellcheck="false" placeholder="aDRra&#10;tuYpT&#10;hcNRcu&#10;cRaoCD&#10;&#10;□□□-□□□-&#10;□□□"></textarea>
		<button class="plain" id="checkBtn">Check</button>
		<div class="msg" id="checkMsg"></div>

		<div id="answers" class="hidden">
			<h2 style="margin-top:24px">Answers <span class="hint">— kept on the server; players never receive them before solving. Optional now: without them the puzzle is saved but not published.</span></h2>
			<div class="words" id="wordAnswers"></div>
			<label for="final">Final answer <span class="hint">— letters in the boxes' order; punctuation comes from the boxes</span></label>
			<input id="final" style="text-transform:uppercase">
			<label for="clue">Caption / clue <span class="hint">(optional)</span></label><input id="clue">
			<label for="explanation">Why it's funny <span class="hint">(optional, shown after solving)</span></label><input id="explanation">
			<button class="primary" id="uploadBtn">Upload</button>
		</div>
		<div class="msg" id="uploadMsg"></div>
	</section>

	<section id="upcoming" class="hidden">
		<h2>Uploaded puzzles</h2>
		<table><thead><tr><th>Date</th><th>Slot</th><th>Goes live</th><th>Status</th></tr></thead><tbody id="list"></tbody></table>
		<div class="msg" id="listMsg"></div>
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

	function signOut() { token = ''; sessionStorage.removeItem('blujemToken'); $('signin').classList.remove('hidden'); $('form').classList.add('hidden'); $('upcoming').classList.add('hidden'); $('draft').classList.add('hidden'); }

	function signedIn() { $('signin').classList.add('hidden'); $('form').classList.remove('hidden'); $('upcoming').classList.remove('hidden'); loadList(); }

	$('signinBtn').onclick = async () => {
		try {
			const reply = await call(AUTH + 'login', { email: $('email').value.trim(), password: $('password').value });
			if (!reply.user || reply.user.role !== 'admin') { show($('signinMsg'), 'This account is not a BluJem admin.', false); return; }
			token = reply.token; sessionStorage.setItem('blujemToken', token); $('password').value = ''; signedIn();
		} catch (e) { show($('signinMsg'), e.message, false); }
	};

	function fillSlots() {
		const iso = $('date').value;
		const options = !iso ? [] : [['morning', 'Morning · 9:00 AM, or when published if later · 4 words'], ['evening', 'Afternoon · 3:00 PM · 4 words'], ['night', 'Night · 9:00 PM · 4 words']];
		const keep = $('slot').value;
		$('slot').innerHTML = options.map(([v, t]) => '<option value="' + v + '">' + t + '</option>').join('');
		if (options.some(([v]) => v === keep)) $('slot').value = keep;
		$('answers').classList.add('hidden');
	}
	$('date').onchange = fillSlots;
	$('slot').onchange = () => $('answers').classList.add('hidden');
	$('text').oninput = () => $('answers').classList.add('hidden');

	const form = () => ({ date: $('date').value, slot: $('slot').value, text: $('text').value });

	$('checkBtn').onclick = async () => {
		try {
			const reply = await call(DATA + 'puzzles/upload', Object.assign(form(), { dryRun: true }));
			if (reply.problems && reply.problems.length) { show($('checkMsg'), reply.problems.join('\\n'), false); return; }
			const p = reply.parsed;
			show($('checkMsg'), 'Looks right: ' + p.words.length + ' words, ' + p.pattern.boxes + ' answer boxes (' + p.pattern.groups.join('-') + '). Goes live ' + reply.goesLive + '.', true);
			$('wordAnswers').innerHTML = p.words.map((w, i) => '<label>Word ' + (i + 1) + ' <span class="hint">' + w.letters + '</span></label><input data-word="' + i + '" maxlength="' + w.letters.length + '">').join('');
			if (p.clue && !$('clue').value) $('clue').value = p.clue;
			$('answers').classList.remove('hidden');
		} catch (e) { show($('checkMsg'), e.message, false); }
	};

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
			const words = Array.from(document.querySelectorAll('[data-word]')).map((i) => i.value.trim());
			const body = Object.assign(form(), {
				cartoonBase64: file ? await readFile(file) : '',
				answers: words.some(Boolean) || $('final').value.trim() ? { words, final: $('final').value.trim() } : null,
				clue: $('clue').value.trim(),
				explanation: $('explanation').value.trim()
			});
			show($('uploadMsg'), 'Uploading…', true);
			const reply = await call(DATA + 'puzzles/upload', body);
			if (reply.problems && reply.problems.length) { show($('uploadMsg'), reply.problems.join('\\n'), false); return; }
			show($('uploadMsg'), (reply.published ? 'Published. ' : 'Saved. ') + 'Goes live ' + reply.goesLive + '.' + (reply.notified && reply.notified.sent ? ' Players have been notified.' : '') + (reply.warnings && reply.warnings.length ? '\\n' + reply.warnings.join('\\n') : ''), true);
			loadList();
		} catch (e) { show($('uploadMsg'), e.message, false); }
		finally { btn.disabled = false; }
	};

	const SLOT_NAMES = { morning: 'Morning', evening: 'Afternoon', night: 'Night', sunday: 'Sunday' };
	const esc = (t) => String(t == null ? '' : t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
	let drafts = {};

	async function loadList() {
		try {
			const reply = await call(DATA + 'puzzles/list', { client: 2, all: true });
			const today = new Date(Date.now() + 5.5 * 3600e3).toISOString().slice(0, 10);
			const all = reply.puzzles || [];
			const live = new Set(all.filter((p) => p.published).map((p) => p.publishDate + '/' + p.slot));
			// A draft from the GPT has its answers; one whose slot is taken is left out.
			const rows = all.filter((p) => p.publishDate >= today)
				.filter((p) => p.published || !live.has(p.publishDate + '/' + p.slot))
				.sort((a, b) => a.publishAt - b.publishAt);
			const when = (ms) => new Date(ms).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' });
			drafts = {};
			$('list').innerHTML = rows.length ? rows.map((p) => {
				let status = p.published ? (p.publishAt <= Date.now() ? 'Live' : 'Scheduled') : 'Needs answers';
				if (!p.published && p.finalAnswer) { drafts[p.id] = p; status = '<b>Draft</b> <button class="plain" data-check="' + esc(p.id) + '" style="margin:0;padding:4px 10px">Check</button>'; }
				return '<tr><td>' + esc(p.publishDate) + '</td><td>' + esc(SLOT_NAMES[p.slot] || p.slot) + '</td><td>' + when(p.publishAt) + '</td><td>' + status + '</td></tr>';
			}).join('') : '<tr><td colspan="4">Nothing uploaded from today on.</td></tr>';
			document.querySelectorAll('[data-check]').forEach((b) => { b.onclick = () => openDraft(drafts[b.dataset.check]); });
		} catch (e) { $('list').innerHTML = '<tr><td colspan="4" class="bad">' + esc(e.message) + '</td></tr>'; }
	}

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
})();
</script>
</body>
</html>`;
}

module.exports = { uploadPage };
