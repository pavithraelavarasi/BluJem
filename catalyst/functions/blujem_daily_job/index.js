'use strict';

/**
 * The slow half of the BluJem daily puzzle processor.
 *
 * blujem_daily takes the puzzle image, stores it, uploads it to Zia and starts
 * this job, which:
 *   1. asks the Zia agent to read the puzzle (a minute or two) and validates it,
 *   2. draws the three BluJem images from that reading and checks them,
 *   3. stores them, with the day's puzzle.json, under blujem-daily/yyyy/MM/dd/,
 *   4. leaves the record in the cache for blujem_daily's result route.
 *
 * A stale puzzle is recorded but not drawn, so no misleading "today" images
 * exist; a reading too broken to draw from goes straight to review. Nothing is
 * ever published here.
 *
 * lib/ is a copy of blujem_daily/lib — edit it there and run
 * `npm run sync-job-lib` in blujem_daily.
 */

const { ZiaDailyPuzzleClient } = require('./lib/zia-daily-puzzle-client');
const { resultFrom, failure, failureFrom } = require('./lib/process-daily');
const { isIsoDate } = require('./lib/india-date');
const daily = require('./lib/daily-requests');
const storage = require('./lib/daily-storage');

/** The agent has this long to answer; it took 73-110 s on its first real puzzles. */
const AGENT_TIMEOUT_MS = 240 * 1000;

/** Validation errors that leave nothing sound to draw from. */
const CANNOT_DRAW = new Set([
	'INVALID_RESPONSE_SHAPE', 'WRONG_WORD_COUNT', 'BAD_SCRAMBLE', 'BAD_BOX_COUNT', 'BOX_COUNT_MISMATCH',
	'BAD_CIRCLE_POSITIONS', 'NO_CIRCLES', 'INVALID_ANSWER_GROUPS', 'BAD_GROUP_SEPARATORS', 'MISSING_FINAL_CLUE'
]);

/** The real services; tests pass their own. */
const realDeps = {
	client: () => ZiaDailyPuzzleClient.fromEnv(process.env, { timeoutMs: AGENT_TIMEOUT_MS }),
	catalyst: (context) => require('zcatalyst-sdk-node').initialize(context, { scope: 'admin' }),
	storage,
	render: (input) => require('./render').renderAssets(input),
	// The colouring step plugs in here (a later stage); until then the
	// original black-and-white cartoon is drawn.
	colorize: null
};

/**
 * Draws and stores the images for a validated reading, and gives the day's
 * record. Statuses: RENDERED when the reading and every image check passed;
 * NEEDS_REVIEW otherwise; STALE_SOURCE and FAILED pass through undrawn.
 */
async function finish(deps, app, { requestId, expectedDate, sourceKeys }, result) {
	const record = {
		requestId,
		date: expectedDate,
		createdAt: new Date().toISOString(),
		extractionStatus: result.status,
		...result,
		sources: sourceKeys
	};
	if (result.status === 'FAILED' || result.status === 'STALE_SOURCE') return record;

	const blocking = (result.errors || []).filter((e) => CANNOT_DRAW.has(e.code));
	if (blocking.length) return { ...record, status: 'NEEDS_REVIEW', needsReview: true };

	try {
		const sources = [];
		for (const key of sourceKeys) sources.push(await deps.storage.read(app, key));
		const drawn = await deps.render({ extraction: result.extraction, sources, colorize: deps.colorize });
		const assets = await deps.storage.saveAssets(app, expectedDate, drawn.files);
		const status = result.status === 'EXTRACTED' && drawn.ok ? 'RENDERED' : 'NEEDS_REVIEW';
		return {
			...record,
			status,
			needsReview: status !== 'RENDERED',
			checks: drawn.checks,
			colorized: drawn.colorized,
			clue: drawn.clue,
			layout: drawn.layout,
			cartoonCrop: drawn.cartoonCrop,
			assets
		};
	} catch (error) {
		console.error('process_daily: drawing failed:', error && error.message);
		return {
			...record,
			status: 'NEEDS_REVIEW',
			needsReview: true,
			error: { code: 'RENDER_FAILED', message: 'The images could not be drawn.' }
		};
	}
}

function createJob(deps = realDeps) {
	/**
	 * @param {{getJobParam: (name: string) => string}} jobRequest
	 * @param {{closeWithSuccess: () => void, closeWithFailure: () => void}} context
	 */
	return async (jobRequest, context) => {
		const param = (name) => String(jobRequest.getJobParam(name) || '').trim();
		const requestId = param('requestId').replace(/[^A-Za-z0-9_]/g, '');
		const fileIds = param('fileIds').split(',').map((id) => id.trim()).filter(Boolean);
		const sourceKeys = param('sourceKeys').split(',').map((k) => k.trim()).filter(storage.isDailyKey);
		const expectedDate = param('expectedDate');
		const sourceUrl = param('sourceUrl') || undefined;
		const started = Date.now();

		try {
			let result;
			if (!requestId || !fileIds.length || !isIsoDate(expectedDate)) {
				result = failure(expectedDate, 'BAD_JOB_PARAMS', 'The job was started without its images or date.');
			} else {
				try {
					const reply = await deps.client().run({ fileIds, expectedDate, sourceUrl });
					result = resultFrom(reply.json, expectedDate, started);
				} catch (error) {
					result = failureFrom(error, expectedDate, started);
				}
			}

			const app = deps.catalyst(context);
			const record = requestId && isIsoDate(expectedDate)
				? await finish(deps, app, { requestId, expectedDate, sourceKeys }, result)
				: result;
			if (requestId && isIsoDate(expectedDate)) await deps.storage.savePuzzle(app, expectedDate, record);
			if (requestId) await daily.save(app, requestId, record);
			// The outcome, never a credential or the agent's full reply.
			console.log('process_daily:', JSON.stringify({
				requestId,
				status: record.status,
				failure: record.error && record.error.code,
				errors: (record.errors || []).map((e) => e.code),
				failedChecks: (record.checks || []).filter((c) => !c.ok).map((c) => c.code),
				elapsedMs: Date.now() - started
			}));
			context.closeWithSuccess();
		} catch (error) {
			console.error('process_daily failed:', error && error.message);
			context.closeWithFailure();
		}
	};
}

module.exports = createJob();
module.exports.createJob = createJob;
module.exports.finish = finish;
