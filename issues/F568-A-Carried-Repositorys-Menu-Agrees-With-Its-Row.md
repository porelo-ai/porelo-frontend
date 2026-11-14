# F568 — A Carried Repository's Menu Agrees With Its Row

```json
{
  "$schema": "issue-1.json",
  "id": "F568",
  "title": "A Carried Repository's Menu Agrees With Its Row",
  "state": "Backlog",
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
