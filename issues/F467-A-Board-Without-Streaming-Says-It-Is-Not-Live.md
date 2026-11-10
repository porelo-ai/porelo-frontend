# F467 — A Board Without Streaming Says It Is Not Live

```json
{
  "$schema": "issue-1.json",
  "id": "F467",
  "title": "A Board Without Streaming Says It Is Not Live",
  "state": "Backlog",
  "size": "XS",
  "priority": "Medium",
  "rank": 15,
  "blockedBy": [],
  "covers": "A planning board read without streaming, or with its stream broken, says it is not live and offers a reload."
}
```

**Why this size.** one line on the planning board where the planner does not stream it.

**What must be true.** A planning board read from a planner that does not stream it, or whose stream broke, says it is
not live, and that a reload shows the current state; it never stands as if it followed the planner.
- Placed by the operator (2026-11-10) from [F451](README.md#f451), point 3: today the board keeps showing what it
  read, with no word that it no longer follows.

## How it stands

- The board and whether it is live are porelo-planner's package now, so nothing of this is left in the window.
  Since the package's event stream, a lost connection ends after 45 seconds and shows its words with *Retry* and
  *Reload*. What is left (a board that closes after one answer, a reconnect in progress, and the "not live: Reload
  shows the current state" line) is filed in the planner's package. This issue waits to be rejected as moved there.

## Plan

- Where the board's read comes without a stream (`lib/src/app/planning*`, the board's source), the board says so in
  one line with a reload beside it.
- Red first: a widget test with a source that answers once and does not stream; the line is shown.

## Acceptance

- Against a mock that does not stream, the board says it is not live and offers a reload; the test seen red first.
