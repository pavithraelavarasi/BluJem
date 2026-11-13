# blujem_daily — BluJem daily puzzle pipeline (extraction stage)

The first stage of the daily BluJem pipeline: one Daily Jumble image goes to the
**BluJem Daily Puzzle Processor** Zia agent, and its JSON comes back validated.

The agent is an **extractor, not a solver**: it returns the date printed on the
puzzle, the four scrambles exactly as printed, the 1-based circled positions,
the clue word for word, and the final answer's shape (box groups and the
punctuation round them). It never unscrambles a word or gives the answer, and
the validator rejects any reply that does.

Nothing is stored, rendered or published here yet. See *What comes next*.

| File | What it is |
|---|---|
| `ZIA_AGENT_INSTRUCTIONS.md` | The text to paste into Zia Agent Studio |
| `schema/zia-daily-puzzle-schema.json` | JSON Schema of the agent's reply |
| `lib/puzzle-extraction.js` | `BluJemPuzzleExtraction` — the backend model |
| `lib/puzzle-extraction-validator.js` | `PuzzleExtractionValidator` — every check, with error codes |
| `lib/zia-daily-puzzle-client.js` | `ZiaDailyPuzzleClient` — token, image upload, agent call |
| `lib/process-daily.js` | One extraction run, shared by the endpoint and the CLI test |
| `index.js` | The function: `POST …/process-daily-test`, admins only |
| `scripts/process-daily-test.js` | The same run from a laptop, saving `out/<date>/puzzle.json` |
| `test/` | `npm test` — validator, client (Zia faked) and endpoint |

---

## How to create and configure the BluJem Daily Puzzle Processor in Zia Agent Studio

**1. Create the agent.** In Zia Agents (agents.zoho.in, under the same Zoho org
as the hint and sheet agents, `60078541075`) choose **New agent**.

- **Name:** `BluJem Daily Puzzle Processor`
- **Purpose / description:** "Reads one Daily Jumble image and returns its
  structure as JSON. Never solves."

**2. Choose the model.** The job is careful reading of an image — small
printed letters, faint circles, a hand-lettered caption — so pick the strongest
**vision-capable** model Agent Studio offers. Reasoning speed matters less than
accuracy; a cheaper model that misreads one circle costs a manual review.
Keep temperature low (or "precise") if the setting exists — the reply must be
the same every time for the same image.

**3. Paste the instructions.** Open `ZIA_AGENT_INSTRUCTIONS.md` and copy
everything between the two `---8<---` lines into the agent's **Instructions**
box. If Agent Studio has a *response format / structured output* setting, give
it `schema/zia-daily-puzzle-schema.json` as well.

**4. Allow image input.** Make sure the agent accepts file attachments (images)
in its input settings — the backend attaches the puzzle image to every call.
Add no tools: the agent must not browse, fetch the source page or edit images.

**5. Test in Agent Studio first.** In the agent's test/preview panel, attach a
puzzle image (e.g. `~/WFH/images/image-Oct22.png`) with the query
`Extract the Daily Jumble in the attached image. Expected date (Asia/Kolkata): 2026-10-22. Source: Hindustan Times Daily Jumble. Answer with the JSON object only.`
Check that the reply is JSON only, with no solved words in it.

**6. Deploy it.** Use **Deploy** (or *Publish*) so a version is live.

**7. Get the trigger URL.** In the agent's **Integrate** tab, copy the
**trigger URL** — it looks like
`https://agents.zoho.in/ziaagents/api/v1/agents/<agentId>/trigger`. It always
runs the deployed version, so redeploying the agent needs no backend change.

**8. Configure the backend.** In the Catalyst console → DailyJumble →
**Development** → Functions → `blujem_daily` → Configuration → Environment
variables, set:

| Variable | Value |
|---|---|
| `ZIA_DAILY_AGENT_URL` | the trigger URL from step 7 — **new** |
| `ZIA_AGENT_CLIENT_ID` | same value as in `jumble_ai` |
| `ZIA_AGENT_CLIENT_SECRET` | same value as in `jumble_ai` |
| `ZIA_AGENT_REFRESH_TOKEN` | same value as in `jumble_ai` |
| `ZIA_AGENT_ORG_ID` | `60078541075` (same as `jumble_ai`) |
| `JUMBLE_TOKEN_SECRET` | same value as in `jumble_ai` — to accept admin sign-in tokens |
| `BLUJEM_INGEST_KEY` | optional; 32+ random characters — lets a server call `store-daily-puzzle` with `x-blujem-ingest-key` instead of an admin token |
| `BLUJEM_DAILY_BUCKET` | optional; default `blujem-daily` — where `store-daily-puzzle` writes |
| `ZIA_AGENT_BASE` | optional; default `https://ziaagents.zoho.in` |
| `ZIA_AGENT_ACCOUNTS` | optional; default `https://accounts.zoho.in` |
| `ZIA_DAILY_TIMEOUT_MS` | optional; default `25000` |

These are deliberately **not** in `catalyst-config.json`, so no secret is ever
in a file. The refresh token's OAuth client must have the Zia Agents scopes the
existing agents already use; it is the same client, so it does.

---

## How to deploy the function

Local first, then Development (never straight to Production):

```bash
cd functions/blujem_daily && npm test            # Zia and Catalyst faked
cd ../blujem_daily_job && npm test               # the job, and that its lib/ copy matches
cd ../.. && catalyst serve --only functions:blujem_daily   # smoke test locally
catalyst deploy --only functions:blujem_daily,functions:blujem_daily_job   # to Development
```

After deploying, set the environment variables (step 8) if they are not there yet.

## How to run the manual extraction test

**From a laptop, no deploy needed** — the real agent, your credentials in a
git-ignored file:

```bash
cd functions/blujem_daily
cat > .env.local <<'ENV'
ZIA_DAILY_AGENT_URL=https://agents.zoho.in/ziaagents/api/v1/agents/<agentId>/trigger
ZIA_AGENT_CLIENT_ID=...
ZIA_AGENT_CLIENT_SECRET=...
ZIA_AGENT_REFRESH_TOKEN=...
ZIA_AGENT_ORG_ID=60078541075
ENV
node scripts/process-daily-test.js ~/WFH/images/image-Oct22.png --date 2026-10-22

# or the three pieces the source page shows, in one run:
node scripts/process-daily-test.js words.png cartoon.png answer.png --date 2026-10-23
```

It prints the result and saves it to `out/2026-10-22/puzzle.json`.

**Against the deployed function** — as an admin. The agent takes a minute or
two and an Advanced I/O function is stopped at 30 s, so it is two calls: start,
then collect.

```bash
TOKEN=...   # an admin's x-jumble-token, from signing in through jumble_auth
B=https://blujem-60093843442.development.catalystserverless.in/server/blujem_daily
IMAGE=$(base64 -i ~/WFH/images/ht-2026-10-23.png)

# 1. Start: uploads the image to Zia and starts blujem_daily_job → 202 {requestId}
curl -X POST $B/process-daily-test -H "x-jumble-token: $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"images\":[{\"base64\":\"$IMAGE\"}],\"expectedDate\":\"2026-10-23\"}"

# 2. Collect: PENDING until the job is done (about 1-2 minutes), then the result
curl -X POST $B/process-daily-result -H "x-jumble-token: $TOKEN" -H 'Content-Type: application/json' \
  -d '{"requestId":"<requestId from step 1>"}'
```

Up to three images can be sent as `images` — the word rows, cartoon and answer
boxes as the source page shows them. Results are kept for 2 hours.

**How the two functions share the work:** `blujem_daily` (Advanced I/O) checks
the images, uploads them to Zia, marks the request PENDING in the cache and
submits `blujem_daily_job` to the `LayoutPool` job pool. The job asks the agent
(up to 4 minutes), validates the reply and saves the result in the cache, where
`process-daily-result` reads it. The cache segment and job pool are the layout
detector's (`lib/daily-requests.js`; override with `DAILY_CACHE_SEGMENT_ID` and
`DAILY_JOB_POOL`). The job needs the same Zia variables as `blujem_daily` except
`JUMBLE_TOKEN_SECRET`. `blujem_daily_job/lib` is a copy of `lib/` — edit `lib/`
here and run `npm run sync-job-lib`; the job's tests fail if they differ.

To serve it at `/api/blujem/process-daily-test`, add an API Gateway route that
points that path at this function; the handler already accepts it.

**What to confirm** in the result for a known puzzle (22 October 2026):
`status: EXTRACTED`; `puzzleDate` 2026-10-22; the words `NCWOR`, `RPEGU`,
`ILEKFC`, `OPTRAS` in that order; circles `[2,3,5]`, `[1,4,5]`, `[1,2,3]`,
`[2,3,4,5]`; the clue word for word; groups `[5,2,6]`; no punctuation; and
no solved word anywhere. Run it with `--date 2026-10-23` too: it must come back
`STALE_SOURCE`.

## Results

| `status` | Meaning | HTTP |
|---|---|---|
| `EXTRACTED` | Every check passed | 200 |
| `STALE_SOURCE` | The date on the puzzle is not the expected day (India) | 200 |
| `NEEDS_REVIEW` | A check failed or something was uncertain — see `errors` / `warnings` | 200 |
| `FAILED` | The run could not complete — see `error.code` | 400/502/503/504 |

Error codes: `SOURCE_UNAVAILABLE`, `SOURCE_TOO_LARGE`, `BAD_EXPECTED_DATE`,
`ZIA_NOT_CONFIGURED`, `ZIA_UNAUTHORIZED`, `ZIA_TIMEOUT`, `ZIA_UPLOAD_FAILED`,
`ZIA_CALL_FAILED`, `ZIA_EMPTY_RESPONSE`, `INVALID_JSON`; and from validation
`MISSING_DATE`, `BAD_DATE`, `WRONG_WORD_COUNT`, `BAD_SCRAMBLE`, `BAD_BOX_COUNT`,
`BOX_COUNT_MISMATCH`, `BAD_CIRCLE_POSITIONS`, `NO_CIRCLES`,
`CIRCLES_DO_NOT_FILL_ANSWER`, `MISSING_FINAL_CLUE`, `INVALID_ANSWER_GROUPS`,
`BAD_GROUP_SEPARATORS`, `BAD_PUNCTUATION`, `MISSING_CARTOON`, `BAD_CARTOON_BOX`,
`BAD_CONFIDENCE`, `ANSWER_LEAKED`, `INVALID_RESPONSE_SHAPE`.

## What comes next (not built yet)

1. Fetching the source page and its puzzle image (only once licensing is settled).
2. Cropping the cartoon from `cartoon.boundingBox`; colourising it through a
   separate image service.
3. Deterministic rendering of the three assets (letters collage, blank collage,
   answer strip).
4. Stratus storage under `blujem-daily/yyyy/MM/dd/`, a Data Store row per
   puzzle, the quality checks, and the admin review actions.
5. A scheduled Catalyst job (Asia/Kolkata, morning) with a stale-source retry.

---

## Storing a source image: `store-daily-puzzle`

`POST /server/blujem_daily/store-daily-puzzle` stores one day's puzzle image and
its metadata in the **`blujem-daily`** bucket, and does nothing else (no Zia, no
drawing, no publishing). See `lib/store-daily-puzzle.js`.

- **Auth:** `x-jumble-token` (an admin's) or `x-blujem-ingest-key` (= `BLUJEM_INGEST_KEY`).
- **Body:** `{ puzzleDate: "yyyy-MM-dd", sourceUrl?, imageUrl | imageBase64, metadata?: {} }`.
  `imageUrl` is fetched server-side, http(s) and public hosts only, up to 3 redirects,
  10 MB, 15 s. PNG is kept as it is, and JPEG is converted to PNG.
- **Writes:** `yyyy/MM/dd/source.png` and `yyyy/MM/dd/puzzle.json`, replacing any earlier ones.
- **Returns:** `{ status: "success", imageKey, metadataKey }`, or
  `{ status: "error", error: { code, message } }` with one of these codes:
  - `BAD_PUZZLE_DATE`, `MISSING_IMAGE`, `INVALID_URL`, `BAD_METADATA`, `NOT_AN_IMAGE` (400)
  - `IMAGE_TOO_LARGE` (413)
  - `DOWNLOAD_FAILED`, `STRATUS_UPLOAD_FAILED` (502)
