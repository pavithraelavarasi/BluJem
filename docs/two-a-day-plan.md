# Two puzzles a day: plan

**Status (6 Nov 2026): built and running on Development**, with the recommended choices: hashed answers, notifications on the phone, and Sunday at 10 AM. It differs from the plan below in these ways:
- **Columns added:** `Slot`, `PublishAt`, `PuzzleText` and `FinalPattern` only. The answer hashes are computed on the fly, and the cartoon key goes in the existing `SheetKey` column.
- **`HISTORY_START` is unset for now.** Setting it to `2026-12-01` today would hide every existing puzzle. Set it on `jumble_data` on launch day.
- **Older app versions still get plain answers.** Set `STRIP_ANSWERS_FOR_ALL=true` once everyone has updated.
- **The in-app upload keeps its AI-assisted publish screen.** It now also asks for the slot. The admin's computer upload uses the new `puzzles/upload` route.

## How it works today

| Area | Today |
|---|---|
| **Storage** | Data Store table `Puzzles` has one row per puzzle: `PuzzleId`, `PublishDate` (a yyyy-MM-dd string), `Published`, `Words` (JSON with scrambled letters, answers and box positions), `FinalAnswer`, `FinalClue`, `FinalBoxes`, `FinalGroupSizes`, `SheetKey`, `AspectRatio`, `Difficulty` and `TimeLimitSeconds`. Images are in Stratus bucket `blujem`. Older puzzles are stored as whole sheets under `sheets/<id>.png`. Typed puzzles store only the cartoon, as `sheets/<id>-cartoon.jpg`. |
| **Upload** | In the app, under Profile → Upload. **Type the letters** (`lib/admin/typed_puzzle.dart`) already reads the admin's puzzle format: capitals mark circled letters, and the box pattern can include hyphens and line breaks. The app draws the left page itself (`lib/game/puzzle_page.dart`). **Choose puzzle image** sends a newspaper photo to the Zia agent instead (`blujem_daily` + `blujem_daily_job`). |
| **Fetching** | `jumble_data` `puzzles/list` returns every published row, **including all the answers**, to every player. `puzzles/sheet` streams any key it is asked for. Nothing on the server checks the publish time. A puzzle uploaded for tomorrow can already be fetched today, and the app just doesn't show it yet. |
| **Showing** | `PuzzleLibrary` picks one puzzle per date (`todaysSheet` / `forDay`), and the Home, History and Play screens all assume one puzzle per day. |
| **Scores** | `PuzzleScores`, `PuzzleCompletions` and the local records are keyed by `PuzzleId`, so they already work per puzzle. **Streaks** and "solved today" are counted per day, and the History calendar marks days, not puzzles. |
| **Notifications** | There is **no 11 AM notification** in the code. `jumble_data` sends one push at publish time, but only when the puzzle is for today and `PUSH_APP_ID` is set. It isn't set, because FCM was never connected, so no notification goes out today. |

## Decisions needed

1. **Hiding answers.** Words are checked on the phone, so the phone needs some form of the answer. There are two options:
   - **(a) Recommended: hashed answers.** The payload carries `sha256(puzzleId + word)` instead of the word, the phone compares hashes, and a solved word is revealed from the letters the player typed. Offline play keeps working. A determined player could still brute-force a 6-letter scramble (720 orders), but nobody can read the answers out of the payload.
   - **(b) Server checks every word.** Answers never leave the server, but each tap needs the network and adds about 300 ms. Offline play stops working.

   Either way, the final answer is revealed only after all words are solved, through a new `puzzles/reveal` call that requires the player to have solved them.
2. **Notifications.**
   - **(a) Recommended: local scheduled notifications** in the app (`flutter_local_notifications`) at 10:00 and 16:00 IST, Monday to Saturday, plus Sunday morning. This needs no FCM setup and works on the next app release.
   - **(b) Server push.** A Catalyst cron at 10:00 and 16:00 sends the push. This needs Firebase/FCM registered and loaded into Catalyst first.
3. **Launch date.** It becomes the config value `HISTORY_START`, defaulting to `2026-12-01`. Puzzles from before that date stay stored but are hidden from History.
4. **Sunday release time.** The plan assumes 10:00 AM.

## Data changes (additive only: nothing is dropped or rewritten)

- **`Puzzles`**: new columns:
  - `Slot` (`morning` / `evening` / `sunday`)
  - `PublishAt` (epoch ms, IST slot time)
  - `PuzzleText` (the admin's text as typed)
  - `Parsed` (JSON: words with circled indices, and the answer pattern)
  - `AnswerHashes`
  - `CartoonKey`

  The answer columns that already exist (`Words` with answers, `FinalAnswer`) stay on the server only.
  - **Migration** (`jumble_data` admin route `migrate/slots`, which can be re-run safely): every existing row gets `Slot = morning` (or `sunday` on a Sunday) and `PublishAt` = its date at 10:00 IST. Nothing is deleted.
  - **Uniqueness:** `(PublishDate, Slot)` is enforced in the publish route. Re-uploading the same slot updates that slot's row, as re-publishing a date does today.
- **Stratus**: new cartoons go to `puzzles/{YYYY-MM-DD}/{slot}/cartoon.png` in bucket `blujem`. Existing `sheets/...` files stay where they are.
- **Config, not code**: bucket, table names, segment ID and `HISTORY_START` move to function environment variables, with today's values as defaults.

## Server (Catalyst functions)

- **`jumble_data`**:
  - `puzzles/list` returns only rows with `PublishAt <= now` to players, without answers. Admins get everything.
  - `puzzles/sheet` refuses the cartoon of an unreleased puzzle.
  - `scores/start` and `scores/submit` refuse unreleased puzzles.
  - New routes: `puzzles/reveal`, and `puzzles/upload` (see below).
- **New shared parser** `lib/puzzle-text.js`, plus its Dart twin `lib/models/puzzle_text.dart`. Both get the same unit tests, and the tests share one JSON file of cases. It enforces:
  - exactly 4 words, or 6 on Sunday
  - letters only
  - at least one circled letter
  - circled letters = answer boxes

  It keeps the punctuation and line breaks of the answer pattern.
- **New slot logic** `lib/slots.js` (and its Dart twin): turns (date, slot) into its publish time, IST only, and enforces the Sunday rule.
- **Upload from a computer**: a small admin web page served by `jumble_data` at `/upload`, in the same style as the existing privacy pages. The admin signs in with their BluJem admin email and password, then picks:
  - the date and slot
  - the cartoon
  - the puzzle text
  - the answers (optional, and they can be added later)

  The page validates the text with the parser, puts the cartoon in Stratus and writes the row. Future dates are allowed. The in-app **Type the letters** screen moves to the same route.
- **No change to `jumble_auth`.** Existing sign-ins and tokens stay valid, and no one is signed out.

## App (Flutter)

- `Puzzle` model: adds `slot`, `publishAt` and `answerHashes`. `PuzzleLibrary` replaces `todaysSheet` with `todaysPuzzles` (morning, evening, or Sunday).
- **Home**: two cards on weekdays, "Morning · 10 AM" and "Evening · 4 PM". A locked card shows "Unlocks at 4:00 PM". Sunday shows one "Mega Jumble" card.
- **History**: lists every puzzle from `HISTORY_START` onward, two per weekday. The calendar shows a half-filled day when one of the two slots is solved.
- **Streak**: counts a day when at least one of that day's puzzles is solved. Per-puzzle scores and times stay as they are. Profile shows puzzles solved as well as days.
- **Left page**: draws from the parsed data, as typed puzzles do today. The Sunday layout fits 6 rows into the same height, and the answer strip wraps at the typed line breaks.
- Shake to reshuffle, swipe between pages, Zia hints and the in-app update notice are left untouched.

## Tests

- Parser: valid weekday and Sunday inputs, wrong word count, a digit in a word, no capitals, a mismatch between circled letters and boxes, and punctuation and line breaks in the pattern.
- Slots: IST times, around midnight, Sunday morning only, and an evening slot rejected on Sunday.
- Answer strip: box and punctuation positions, and wrap points.
- Server: an unreleased puzzle is hidden from players and its sheet is refused, answers are absent from the list, the migration fills every row, and running the migration twice changes nothing.

## Deliverables

- `docs/UPLOADING.md`: a one-page guide for the admin covering the format, the web page, and when each slot goes live.
