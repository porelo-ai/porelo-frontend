# F494 — About Names The Planner's Version

```json
{
  "$schema": "issue-1.json",
  "id": "F494",
  "title": "About Names The Planner's Version",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "The window's About names the version of the planner the window runs beside porelo's, so a person can tell which planner build answers the planning."
}
```

**Why this size.** one more line in About, read from the planner's `/health`, with its tests; S. It ships once
porelo-planner answers its version there; until then every planner reads as one that names none.

**What must be true.** A person who opens About sees, beside "this machine: Porelo 0.5.1~snapshot.500", the version of
the planner the window runs, for example "planner: porelo-planner <version>". Where the window reaches no planner, or
the planner says no version, About says so in words instead of leaving the line out. Today About names porelo's
version alone, and "built from source" for the window itself.

Asked by the operator during [F492](README.md#f492)'s walks, where the planner was swapped between builds (daace48,
f9e58ea, f1dbbcd) and nothing in the window told which one answered.

## The planner's contract (agreed 2026-11-12)

`GET /health`, with the token as today, answers `{"status": "UP", "version": "<version>", "commit": "<40 hex>"}`:
`version` is the package's (`x.y.z`, or `x.y.z~snapshot.<run>`, as its .deb and .rpm), `commit` the commit it was
built from or null where the build had no checkout. `status` stays as it is; `planner.json` gets neither field.

## Plan

- The window reads `version` and `commit` from the planner's `/health` as it asks it today; a planner that answers
  `status` alone, or a field of the wrong type, reads as one that names no version, never as a failure to reach it.
- About shows it in its own line beside porelo's, with the commit's first twelve characters where it is given, and
  says "not reached" or "says no version" where that is so.
- Tests, red first: the health read takes version and commit, takes a null commit, and an older answer as no version;
  a widget test opens About with a planner that names a version and commit, one with a null commit, one that names
  none, and none reached.

## Acceptance

- About names the planner's version beside porelo's while a planner answers.
- About says in words that no planner is reached, or that it names no version, where that is so.
