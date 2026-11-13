'use strict';

const { ZiaClientError } = require('./zia-daily-puzzle-client');
const { PuzzleExtractionValidator } = require('./puzzle-extraction-validator');
const { indiaDate, isIsoDate } = require('./india-date');

/** Largest image accepted, the same limit the sheet checker uses. */
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

/**
 * Most pieces one puzzle comes in: the source page shows the word rows, the
 * cartoon and the answer boxes as three separate images.
 */
const MAX_IMAGES = 3;

/**
 * One extraction run, in the pieces every caller shares:
 *
 *   checkInput   — the images and the expected day, before anything is sent
 *   resultFrom   — the agent's JSON through the validator, as one result
 *   failure      — a run that could not complete, with its cause
 *
 * The command-line test runs them in one go ([processDaily]); the live
 * endpoint checks and uploads, and a background job does the slow part — the
 * agent takes a minute or two, and an Advanced I/O function is stopped at 30
 * seconds.
 *
 * Statuses: EXTRACTED, STALE_SOURCE, NEEDS_REVIEW, FAILED (and PENDING while
 * the job runs). A failure always names its cause in `error.code`.
 */

/** A run that could not complete. */
function failure(expectedDate, code, message, details, started = Date.now()) {
	return {
		status: 'FAILED',
		needsReview: true,
		expectedDate,
		error: { code, message, ...(details ? { details } : {}) },
		elapsedMs: Date.now() - started
	};
}

/**
 * The images to send and the day to expect, or why there is nothing to send.
 *
 * @returns {{expected: string, pieces: {data: Buffer, fileName?: string, mimeType?: string}[]} | {failed: object}}
 */
function checkInput({ images, image, fileName, mimeType, expectedDate, now }) {
	const expected = expectedDate || indiaDate(now);
	if (!isIsoDate(expected)) return { failed: failure(expected, 'BAD_EXPECTED_DATE', `"${expected}" is not a yyyy-MM-dd date.`) };
	// One image, or the separate pieces of one puzzle.
	const pieces = (images || (image ? [{ data: image, fileName, mimeType }] : []))
		.filter((piece) => piece && piece.data && piece.data.length);
	if (!pieces.length) return { failed: failure(expected, 'SOURCE_UNAVAILABLE', 'No puzzle image was supplied.') };
	if (pieces.length > MAX_IMAGES) {
		return { failed: failure(expected, 'TOO_MANY_IMAGES', `A puzzle comes in at most ${MAX_IMAGES} images; got ${pieces.length}.`) };
	}
	if (pieces.some((piece) => piece.data.length > MAX_IMAGE_BYTES)) {
		return { failed: failure(expected, 'SOURCE_TOO_LARGE', 'An image is larger than 10 MB.') };
	}
	return { expected, pieces };
}

/** The agent's parsed reply, validated, as the run's result. */
function resultFrom(json, expected, started, validator) {
	const checked = (validator || new PuzzleExtractionValidator()).validate(json, expected);
	return {
		status: checked.status,
		needsReview: checked.needsReview,
		expectedDate: checked.expectedDate,
		sourceDate: checked.sourceDate,
		errors: checked.errors,
		warnings: checked.warnings,
		extraction: checked.extraction.toJSON(),
		elapsedMs: Date.now() - started
	};
}

/**
 * A thrown error as a failed result: the client's own code, or a generic one.
 * Recognised by name rather than class, so an error from another copy of this
 * library (the job carries one) still keeps its code.
 */
function failureFrom(error, expected, started) {
	const fromClient = error instanceof ZiaClientError ||
		(error && error.name === 'ZiaClientError' && typeof error.code === 'string');
	if (fromClient) return failure(expected, error.code, error.message, error.details, started);
	return failure(expected, 'ZIA_CALL_FAILED', 'The agent could not be run.', undefined, started);
}

/**
 * The whole run in one go: images to the agent, its reply validated. For a
 * caller that can wait the minute or two the agent takes.
 *
 * @param {{
 *   images?: {data: Buffer, fileName?: string, mimeType?: string}[],
 *   image?: Buffer, fileName?: string, mimeType?: string,
 *   expectedDate?: string, sourceUrl?: string,
 *   client: import('./zia-daily-puzzle-client').ZiaDailyPuzzleClient,
 *   validator?: PuzzleExtractionValidator, now?: Date
 * }} input
 */
async function processDaily({ images, image, fileName, mimeType, expectedDate, sourceUrl, client, validator, now }) {
	const started = Date.now();
	const input = checkInput({ images, image, fileName, mimeType, expectedDate, now });
	if (input.failed) return input.failed;

	try {
		const reply = await client.extract({ images: input.pieces, expectedDate: input.expected, sourceUrl });
		return resultFrom(reply.json, input.expected, started, validator);
	} catch (error) {
		return failureFrom(error, input.expected, started);
	}
}

module.exports = { processDaily, checkInput, resultFrom, failure, failureFrom, MAX_IMAGE_BYTES, MAX_IMAGES };
