#!/usr/bin/env node
'use strict';

/**
 * Copies lib/ into the blujem_daily_job function, which needs the same code.
 *
 * Catalyst deploys each function folder on its own, so the job cannot reach
 * this folder's lib/ at run time; it carries a copy. blujem_daily/lib is the
 * one to edit — run this after changing it (npm run sync-job-lib), and the
 * job's tests fail if the copies have drifted apart.
 */

const fs = require('fs');
const path = require('path');

const from = path.join(__dirname, '..', 'lib');
const to = path.join(__dirname, '..', '..', 'blujem_daily_job', 'lib');
fs.mkdirSync(to, { recursive: true });
for (const name of fs.readdirSync(from).filter((n) => n.endsWith('.js'))) {
	fs.copyFileSync(path.join(from, name), path.join(to, name));
	console.log(`copied lib/${name}`);
}
