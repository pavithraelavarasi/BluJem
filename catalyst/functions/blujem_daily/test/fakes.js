'use strict';

/** A stand-in for catalyst.initialize(…): an in-memory cache and a job recorder. */
function fakeCatalyst() {
	const store = new Map();
	const jobs = [];
	const objects = new Map();
	const app = {
		stratus: () => ({
			bucket: () => ({
				putObject: async (key, body) => {
					const chunks = [];
					for await (const c of body) chunks.push(Buffer.from(c));
					objects.set(key, Buffer.concat(chunks));
					return true;
				},
				getObject: async (key) => {
					if (!objects.has(key)) throw new Error('no such key');
					return require('stream').Readable.from([objects.get(key)]);
				},
				generatePreSignedUrl: async (key, action) => ({ signature: `https://signed.example/${key}?action=${action}` }),
				listPagedObjects: async ({ prefix }) => ({
					contents: [...objects.keys()].filter((k) => k.startsWith(prefix)).map((key) => ({ key, size: objects.get(key).length })),
					truncated: 'false'
				})
			})
		}),
		cache: () => ({
			segment: (id) => ({
				put: async (key, value, hours) => { store.set(key, { value, hours, id }); },
				getValue: async (key) => (store.has(key) ? store.get(key).value : null)
			})
		}),
		jobScheduling: () => ({
			job: () => ({ submitJob: async (job) => { jobs.push(job); return { id: `J${jobs.length}` }; } })
		})
	};
	return { app, store, jobs, objects };
}

/** A stand-in Zia client: uploads give file ids, the agent gives [reply]. */
function fakeClient(reply) {
	const calls = { uploads: [], runs: [] };
	return {
		calls,
		uploadAll: async (images) => {
			calls.uploads.push(images.length);
			return images.map((_, i) => `F${i + 1}`);
		},
		run: async (input) => {
			calls.runs.push(input);
			if (reply instanceof Error) throw reply;
			return { json: reply, text: JSON.stringify(reply) };
		}
	};
}

/** A stand-in renderer: three small files, every check passed. */
function fakeRender({ ok = true } = {}) {
	return async ({ extraction }) => ({
		files: {
			'cartoon-original.png': Buffer.from('cartoon'),
			'collage-letters.png': Buffer.from('letters'),
			'collage-blank.png': Buffer.from('blank'),
			'answer-strip.png': Buffer.from('strip')
		},
		checks: [{ code: 'BLANK_HAS_NO_LETTERS', ok, message: '' }],
		ok,
		colorized: false,
		clue: extraction.finalClue,
		layout: { width: 1800, height: 1361, words: extraction.words.map(() => []) },
		cartoonCrop: { x: 0, y: 0, w: 10, h: 10, frameFound: true }
	});
}

module.exports = { fakeCatalyst, fakeClient, fakeRender };
