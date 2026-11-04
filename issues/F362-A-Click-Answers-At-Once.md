# F362 — A Click Answers At Once

**Status:** Idea. Nothing is built before the foo test.

**What must be true.** Whatever a click starts, a person sees at once that it arrived: on a row that opens a page, the page with its "Reading…" line. In the foo test, clicking a row under *Projects*, for a moment nothing happens and then the page comes.

## What is measured

- **It is not the wait for a double tap.** Nothing in `lib/src/ui` asks for one, and in a test the row's action runs at the pointer's release, with no time passing.
- **It is not the read of the project, as far as the code goes.** The page is drawn without waiting for it: with the read held open, the first frame already shows the page and its "Reading…" line.
- **The whole window in a test** takes one frame of about 32 ms from the release to that line, a debug build with made-up data on the laptop, one run.
- **So the delay seen is not found.** The test holds no real `porelo`, no real organization and no real display. `porelo --version` takes 0.03 s here, so its start alone does not explain it either; `porelo project show` itself was not timed, and need not delay the page.

An earlier issue, *A Server Dialog Opens At Once*, settled one dialog, not this row, and *A Long Change Shows That It Runs* covers a change, not a page.

## What to measure next

- In the operator's window: does the row's press effect show at once? If it does, the wait is between the click and the page; if it does not, the window itself is busy or drawing late.
- A window of the published package on a hidden display, with a real organization, measuring from the click to the frame. Not while the operator's test runs, since one computer holds one window of its account.

## Acceptance

- From the click to the page's first frame is measured on a real window before and after, and stays below what a person notices.
- A row's press effect shows at once on any click.
