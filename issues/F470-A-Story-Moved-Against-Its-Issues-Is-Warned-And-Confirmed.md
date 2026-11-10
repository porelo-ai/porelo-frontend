# F470 — A Story Moved Against Its Issues Is Warned And Confirmed

**Status:** Backlog; blocked by Porelo's planning keeping a story's explicit state beside its issues and saying where
the issues do not fit it, through the board's save.
**Priority:** Medium (the operator, 2026-11-10); filed, not built now.
**Size:** S - the board's warning before a story is moved into a state its issues do not fit, confirm or cancel, the
explicit state kept on the card after the save, and their tests.

**What must be true.** A person who moves a story on the planning board into a state that its issues do not fit by
the automatic rule is warned before it is saved, naming each issue that does not fit, and confirms or cancels; once
confirmed, the story stands in that state whatever its issues' states are. A move that fits saves as today.
- Serves porelo-project's *A story takes the state the operator gives it* (story ST309): a story put into a state on
  the board or in its head has that state; a mismatch with its issues is a warning, never a refusal; without an
  explicit state the automatic rule (the earliest open state of its issues) stays.
- Today the board moves a story by its least advanced issues and confirms the move only where they fit
  ([F451](README.md#f451)); an explicit state replaces that for a story the person placed.

## Plan

- Before the save: where the destination does not fit the story's issues by the automatic rule, a dialog names the
  issues and their states, with *Move anyway* and *Cancel*; *Cancel* leaves the card where it stood.
- The save carries the explicit state as Porelo's interface will take it; the card keeps it after the reread, and
  says that its issues do not fit.
- A story without an explicit state keeps the automatic rule on the board and in the mock.
- Red first: a move against the issues asks and saves only when confirmed; a fitting move asks nothing; a cancelled
  move leaves the card and sends nothing.

## To be checked

- How Porelo's interface carries an explicit story state and a mismatch, once it is filed there; whether a story move
  then still moves its issues.

## Acceptance

- Against the mock: a story moved against its issues is warned, saved only when confirmed, and stays in its state
  after the reread; a fitting move asks nothing; each test seen red first.
