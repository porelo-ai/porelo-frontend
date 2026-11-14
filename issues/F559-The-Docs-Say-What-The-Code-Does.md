# F559 — The Docs Say What The Code Does

```json
{
  "$schema": "issue-1.json",
  "id": "F559",
  "title": "The Docs Say What The Code Does",
  "state": "Backlog",
  "size": "M",
  "priority": "Highest",
  "rank": 9,
  "blockedBy": [],
  "covers": "Story ST361: every sentence of this repository's user-facing documents is borne out by the code on main: no command, flag, path, default, state, message or behavior that is gone, renamed or never was."
}
```

**Why this size.** README.md, the pages under `doc/` and the CHANGELOG's latest section, read page by page against
the code; each finding checked in the code before anything changes. No behavior changes.

**What must be true.** A person who follows the documents finds the window, its pages, its words and its tools as they
read.

## Plan

- **The reading.** A Claude sub-agent on Sonnet reads README.md, `doc/` and the CHANGELOG's latest section (not
  `issues/`, not the history in `doc/decisions.md`) against the code and lists every sentence the code does not bear
  out, each with file:line, the claim, and the code that contradicts it (file:line). It runs no test suite and no
  machine.
- **The check.** Each finding is checked in the code here; only a confirmed one changes anything.
- **The change.** Where the code is right, the document is fixed; where the document is right and the code wrong, a
  bug of its own is filed (Backlog, estimated) and the document stays.

## Acceptance

- The count of claims checked, confirmed, fixed and filed as bugs is given with the push; one commit, documents tests,
  check-commits, check-citations and local traces green.
