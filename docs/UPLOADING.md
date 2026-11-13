# Uploading BluJem puzzles

*For the admin. One page: what to send for each puzzle, where to upload it, and when it goes live.*

## When puzzles go live (India time)

| Day | Slot | Opens | Words |
|---|---|---|---|
| Monday to Saturday | **Morning** | the moment you publish it | 4 |
| Monday to Saturday | **Evening** | 4:00 PM | 4 |
| Sunday | **Mega Jumble** | the moment you publish it | 6 |

Players get a notification when each puzzle opens: right after you publish the morning or Sunday one, and at 4:00 PM for the evening one.

You can upload days ahead. A morning or Sunday puzzle uploaded ahead (or before 6:00 AM on its day) opens at **6:00 AM** on its day, with its notification. An evening puzzle stays hidden until 4:00 PM. Fixing a puzzle that is already out does not send a second notification.

## Where to upload

Open this page on your computer and sign in with your BluJem admin email and password:

**https://blujem-60093843442.development.catalystserverless.in/server/jumble_data/execute/upload**

Admins can also upload in the app under **Upload → Type the letters**, after choosing the date and the slot.

## What to give for each puzzle

1. **Date and slot.** The page offers only the slots that day has.
2. **Cartoon.** The coloured cartoon only (the right-hand page), as a PNG or JPEG. The app draws the word page itself.
3. **Puzzle text**, typed like this:

   ```
   aDRra
   tuYpT
   hcNRcu
   cRaoCD

   □□□-□□□-
   □□□
   ```

   - One jumbled word per line, in the order printed.
   - **CAPITAL letters are the circled ones.** Lowercase letters are not circled.
   - A Sunday puzzle has **6** word lines; every other puzzle has **4**.
   - Then a **blank line**, then the answer boxes. Each □ is one letter. You can type `_` instead of □.
   - Type spaces, hyphens, quotes and apostrophes exactly as printed. They show outside the boxes: `"□□□□□-` / `□□□□□" □□□`.
   - A **new line** in the boxes is where the answer wraps on the phone.
4. **Answers.** One answer per word, plus the final answer, e.g. `ADMIT TENTS FEE`. The punctuation comes from the boxes, so you only need the letters. You can also leave the answers out and add them later.
5. **Caption and "why it's funny".** Both are optional. The explanation shows after the puzzle is solved.

Click **Check** first. The page then says what it read, for example "4 words, 9 answer boxes (3-3-3)", or exactly what to fix:

- the wrong number of words for the slot
- a word with something other than letters
- no capitals
- the circled letters don't add up to the boxes

Then click **Upload**.

## Good to know

- **Answers stay on the server.** Players' phones check their letters against a fingerprint of each answer, so the words can't be read off the phone before they're solved.
- **No answers yet?** The puzzle is saved but not published. Upload the same date and slot again with the answers to publish it.
- **To fix a puzzle,** upload the same date and slot again. It replaces the earlier one. Leave the cartoon empty to keep the one already uploaded.
- The page refuses an answer that doesn't use a word's own letters, or a final answer that doesn't use exactly the circled letters.
