# F568 — A Carried Repository's Menu Agrees With Its Row

```json
{
  "$schema": "issue-1.json",
  "id": "F568",
  "title": "A Carried Repository's Menu Agrees With Its Row",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 14,
  "blockedBy": [],
  "covers": "Story ST361: a repository a machine carries offers its work in its menu, as its row and the page say, instead of calling it not on this machine."
}
```

**Why this size.** One menu on a machine's project page and the facts it is built from. The cause may be the window's model or porelo's answer.

**What must be true.** A row and its menu never contradict each other about where a repository is.

## Plan

Found live on porelo on a test machine after a restart:

- *claude*, *omp* and *pi* say "carried here alone · at central", and the page says "carried by this machine;
  starting work takes it here".
- Yet *claude*'s menu says "Start work in claude — Unavailable: work cannot start in this project", and every other
  entry says "Unavailable: This repository is not on this machine".

The work:

- Find which side is wrong: where the menu reads whether a repository is on the machine, or the row's fact. If
  porelo's answer says not on the machine, Agent Core checks the field named.
- The menu takes the same fact as the row.

## Acceptance

- A guard with a carried repository whose menu offers its work entries, red first. The project page tests green.

## Built

- **Cause: the window's.** The row and the page read the machine's answer that it carries the project for this person
  and the repository here (`carried`, `carriedHere`); the menu read only whether the project has a file on the machine,
  which a carried project has not until it is taken. So *Start work in …* had no way to start and said *work cannot
  start in this project*, and the entries that read the project's file said *This repository is not on this machine*.
  Porelo's answer was right; nothing is needed of it.
- A repository row's *Start work in …* on a project the machine carries and this person has not taken yet now starts,
  as the project's own *Start work* does: the start takes the project first. The entries that read its file (upstream,
  backups, what work would open, what it may reach) say that it is carried and not taken yet, and that starting work
  takes it, in place of *not on this machine*.
- Test: `test/ui/project_header_test.dart` *a carried repository's menu offers its work, as its row and the page say*,
  red before the fix (the menu said *not on this machine*).
- `test/ui/carried_project_test.dart` *a repository's Start work takes it once, and says a refused take*: through the
  shell, a refused take says the machine's words, starts nothing and takes once, and upstream, backups, what work would
  open and what it may reach stay disabled. Seen red with the row's start taken away again, and with upstream offered
  on a carried project.
