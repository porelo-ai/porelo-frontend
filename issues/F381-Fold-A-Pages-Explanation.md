# F381 — Fold A Page's Explanation

**Status:** Backlog.
**Size:** S - one shared block, one kept state, one text a page.

**What must be true.** *Work*, *Needs you*, *My machines*, *My forges*, *My projects* and *Organization* each have an explanation. Closing it folds it, and never removes it: a small block stays, a little larger than the `i` icon, with the words "What is ...", and opens it again at any time. A folded explanation stays folded across a restart, kept locally in `frontend.json`.

## Plan

- Take `_Explanation` out of the *Organization* page into a shared block, above each page's card.
- Keep what is folded in `frontend.json`, one entry a page, in place of the state in memory.
- The words, to be read over; the first three start from the sentences the pages once had:
  - *My machines*: "Where work runs. Its projects are under *My projects*, and its work under *Work*."
  - *My forges*: "Where your repositories are, each reached with a token kept in this computer's keychain."
  - *My projects*: "How work runs: its repositories, who reviews what it pushes, whom it may talk to."
  - *Work*: "All work on your machines: what is running, what has stopped, and the way to its terminal."
  - *Needs you*: "What waits for a person: questions, reviews and work that stopped. Nothing else asks for your attention."

## Acceptance

- Each page shows its explanation until it is folded, and the block opens it again.
- A folded explanation is still folded after a restart, and the others are not.

## Decided while building

## Open questions

## To be checked
