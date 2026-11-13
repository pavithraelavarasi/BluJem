#!/usr/bin/env node
'use strict';

/**
 * The manual extraction test, run from a laptop against the real agent:
 *
 *   node scripts/process-daily-test.js <image> [<image> <image>] [--date yyyy-MM-dd] [--source <url>]
 *
 * One image of the whole puzzle, or up to three pieces of it (word rows,
 * cartoon, answer boxes) as the source page shows them.
 *
 * Zia settings come from environment variables — the same names the function
 * uses (see README.md) — exported in the shell or put in a .env.local file
 * next to package.json, which is git-ignored. Nothing is deployed and nothing
 * is published: the result is printed and saved to out/<date>/puzzle.json.
 */

const fs = require('fs');
const path = require('path');
const { ZiaDailyPuzzleClient } = require('../lib/zia-daily-puzzle-client');
const { processDaily } = require('../lib/process-daily');

function loadEnvFile(file) {
	if (!fs.existsSync(file)) return;
	for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
		const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
		if (match && !(match[1] in process.env)) process.env[match[1]] = match[2].replace(/^["']|["']$/g, '');
	}
}

async function main() {
	const args = process.argv.slice(2);
	const option = (name) => {
		const i = args.indexOf(`--${name}`);
		return i === -1 ? undefined : args[i + 1];
	};
	const values = new Set([option('date'), option('source')].filter(Boolean));
	const imagePaths = args.filter((a) => !a.startsWith('--') && !values.has(a));
	if (!imagePaths.length) {
		console.error('Usage: node scripts/process-daily-test.js <image> [<image> <image>] [--date yyyy-MM-dd] [--source <url>]');
		process.exit(2);
	}
	loadEnvFile(path.join(__dirname, '..', '.env.local'));

	const result = await processDaily({
		images: imagePaths.map((p) => ({ data: fs.readFileSync(p), fileName: path.basename(p) })),
		expectedDate: option('date'),
		sourceUrl: option('source'),
		// No 30-second function limit here, so the agent may take longer.
		client: ZiaDailyPuzzleClient.fromEnv(process.env, { timeoutMs: 120000 })
	});

	console.log(JSON.stringify(result, null, 2));
	const dir = path.join(__dirname, '..', 'out', result.expectedDate || 'undated');
	fs.mkdirSync(dir, { recursive: true });
	fs.writeFileSync(path.join(dir, 'puzzle.json'), JSON.stringify(result, null, 2));
	console.error(`\n${result.status} — saved to ${path.join(dir, 'puzzle.json')}`);
	process.exit(result.status === 'FAILED' ? 1 : 0);
}

main().catch((error) => {
	console.error('process-daily-test failed:', error && error.message);
	process.exit(1);
});
