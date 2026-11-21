# BluJem Puzzle Maker: the Custom GPT that sends puzzles to BluJem

The GPT makes a puzzle as it does today and then sends it to BluJem itself.
Everything it sends arrives as a **draft**: players see nothing until an admin
checks it on the upload page (tinyurl.com/blujem-upload) and taps **Publish**.
It can never replace a puzzle that is already published.

Needs a paid ChatGPT plan (Plus, Team or Enterprise) to create a Custom GPT.

## 1. Create the GPT

ChatGPT → **Explore GPTs** → **Create** → **Configure**.

- **Name:** BluJem Puzzle Maker
- **Capabilities:** turn on **Image Generation**.
- **Instructions:** paste the manager's own puzzle-making instructions, then
  add the block below.

```
When a puzzle is ready, send it to BluJem with the uploadPuzzle action.

- date: the day it is for, yyyy-MM-dd (India time).
- slot: morning, evening (the 3:00 PM afternoon puzzle) or night — every
  day, Sunday included.
- text: one scrambled word per line, the circled letters in CAPITALS and the
  rest in small letters; then an empty line; then the answer boxes as □,
  with the punctuation as it should be printed. Example:
    aDRra
    tuYpT
    hcNRcu
    cRaoCD

    □□□-□□□-
    □□□
  Four words, at most 8 letters each. The number of □ must
  equal the number of capital letters.
- answers.words: each word unscrambled, in the same order.
- answers.final: the final answer's letters in the order of the boxes.
- clue: the cartoon's caption, if it has one.
- The pictures: attach the cartoon image you made first (only the cartoon,
  no letters or answer boxes drawn on it), then the same cartoon with no
  speech bubbles or caption — the wordless one players share.

If BluJem answers with problems, fix them and send again. Sending the same
date and slot again replaces the earlier draft. Tell me when it is saved:
an admin then checks and publishes it.
```

## 2. Add the Action

In **Configure** → **Actions** → **Create new action**.

**Authentication:** API Key → **Auth Type: Custom** → header name
`X-BluJem-Key` → paste the key (ask Pavithra; it is never written in a file).

**Schema:** paste this.

```yaml
openapi: 3.1.0
info:
  title: BluJem puzzle upload
  version: 1.0.0
servers:
  - url: https://blujem-60093843442.development.catalystserverless.in
paths:
  /server/jumble_data/execute/gpt/puzzle:
    post:
      operationId: uploadPuzzle
      summary: Save a BluJem puzzle as a draft for an admin to publish
      x-openai-isConsequential: false
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [date, slot, text, answers, openaiFileIdRefs]
              properties:
                date:
                  type: string
                  description: The puzzle's day, yyyy-MM-dd, India time.
                slot:
                  type: string
                  enum: [morning, evening, night]
                  description: evening is the 3:00 PM afternoon puzzle. The same three every day, Sunday included.
                text:
                  type: string
                  description: Scrambled words one per line (circled letters in CAPITALS), an empty line, then the answer boxes as □ with punctuation.
                answers:
                  type: object
                  required: [words, final]
                  properties:
                    words:
                      type: array
                      items: { type: string }
                      description: Each word unscrambled, same order as in text.
                    final:
                      type: string
                      description: The final answer's letters in box order.
                clue:
                  type: string
                  description: The cartoon's caption, if any.
                openaiFileIdRefs:
                  type: array
                  items: { type: string }
                  description: The cartoon first; then, optionally, the same cartoon with no speech bubbles or caption (for the share picture).
      responses:
        '200':
          description: Saved as a draft.
        '400':
          description: Something to fix; see problems.
        '409':
          description: That slot already has a published puzzle.
```

**Privacy policy URL:** not needed while the GPT is private ("Only me" or
"Only people with a link").

## 3. Try it

Ask the GPT for a puzzle for a future date. When it says it is saved, open
tinyurl.com/blujem-upload, sign in as an admin, and the puzzle shows under
**Uploaded puzzles** as **Draft** with a **Check** button: look at the cartoon,
letters and answers, then **Publish**.

If ChatGPT will not attach an image it generated itself, download the image,
drag it back into the chat and ask it to send the puzzle again.

## The key

`GPT_UPLOAD_KEY` is set on the `jumble_data` function in the Catalyst console
(Development). To cut the GPT off, change or clear it there; it is not in any
file in this repository.
