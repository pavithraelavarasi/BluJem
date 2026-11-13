'use strict';

/**
 * One extraction request, from start to result: the endpoint starts it, the
 * blujem_daily_job job finishes it, and the result route reads it back — all
 * through one cache entry, the way jumble_ai and jumble_layout hand off
 * layout detection.
 *
 * The cache segment and the job pool are the layout detector's, so nothing new
 * has to be created in the console; both can be overridden by environment.
 */

/** The layout detector's cache segment (jumble_ai's LAYOUT_CACHE_SEGMENT_ID). */
const DEFAULT_SEGMENT_ID = '90527000000019043';
/** The layout detector's job pool (jumble_ai's LAYOUT_JOB_POOL). */
const DEFAULT_JOB_POOL = 'LayoutPool';
/** The job function that asks the agent. */
const JOB_FUNCTION = 'blujem_daily_job';
/** How long a result is kept, in hours: long enough to be collected. */
const KEEP_HOURS = 2;

const segmentId = () => (process.env.DAILY_CACHE_SEGMENT_ID || DEFAULT_SEGMENT_ID).trim();
const jobPool = () => (process.env.DAILY_JOB_POOL || DEFAULT_JOB_POOL).trim();
const cacheKey = (requestId) => `daily_${requestId}`;
const segment = (app) => app.cache().segment(segmentId());

/** A new request id: letters, digits and underscores only. */
function newRequestId() {
	return `${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

/**
 * Marks [requestId] pending and starts the job that reads the uploaded images.
 *
 * @param {object} app  catalyst.initialize(…) with admin scope
 * @param {{requestId: string, fileIds: string[], sourceKeys: string[], expectedDate: string, sourceUrl?: string}} request
 */
async function start(app, { requestId, fileIds, sourceKeys, expectedDate, sourceUrl }) {
	await segment(app).put(cacheKey(requestId), JSON.stringify({ status: 'PENDING', expectedDate }), KEEP_HOURS);
	const params = { requestId, fileIds: fileIds.join(','), sourceKeys: (sourceKeys || []).join(','), expectedDate };
	if (sourceUrl) params.sourceUrl = String(sourceUrl);
	await app.jobScheduling().job().submitJob({
		job_name: 'process_daily',
		jobpool_name: jobPool(),
		target_type: 'Function',
		target_name: JOB_FUNCTION,
		params
	});
}

/** Saves the job's result for [requestId]. */
async function save(app, requestId, result) {
	await segment(app).put(cacheKey(requestId), JSON.stringify(result), KEEP_HOURS);
}

/** The request's state: PENDING, a finished result, or EXPIRED when the cache has forgotten it. */
async function read(app, requestId) {
	const value = await segment(app).getValue(cacheKey(requestId)).catch(() => null);
	try {
		const result = value ? JSON.parse(value) : null;
		if (result) return { requestId, ...result };
	} catch (e) { /* treated as expired below */ }
	// Never started, or kept past KEEP_HOURS: it will not finish now.
	return { requestId, status: 'FAILED', error: { code: 'EXPIRED', message: 'No such request, or it expired.' } };
}

module.exports = { newRequestId, start, save, read, cacheKey, JOB_FUNCTION, DEFAULT_SEGMENT_ID, DEFAULT_JOB_POOL, KEEP_HOURS };
