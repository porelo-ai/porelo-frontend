# F559 — The Docs Say What The Code Does

```json
{
  "$schema": "issue-1.json",
  "id": "F559",
  "title": "The Docs Say What The Code Does",
  "state": "Review",
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

## Built

The reading checked about 330 concrete claims and reported 24 findings; each was checked in the code here, and a
Gemini reading of the change checked the new sentences.

- **Confirmed and fixed, 18.** In `doc/design.md`: Windows as a working target and its ssh relay, the build's
  profiles, the dependencies beside `xterm`, the lint exceptions, the pin, the drift check (a skipped live-daemon test,
  no CI job), the mock's scenario name and states, and a reference to a question no longer there. In `doc/index.md`:
  the app's name in the Start menu and among the desktop's applications. The CLI rule in `doc/Contract-Gaps.md` (the
  `--json` answer where there is one, the words shown as said where there is none). In the CHANGELOG: three labels
  renamed since, and two entries for a package requirement and an action that no longer exist.
- **Not borne out, 3.** The host refresh in `doc/Backend-API.md` is porelo-host's `org refresh`, as written (now named
  in full); a story's *Start again…* comes from the planning screen with its ellipsis; *Start work in default* is the
  start dialog's own title.
- **Left as written, 3.** CHANGELOG entries for startup roles, the page of all projects on your machines and some 20
  labels of the project menu, registry and server setup. Each is the history of a change that a later entry of the
  same section says is gone.
- **Filed as bugs, 0.** No document was right where the code was wrong.
