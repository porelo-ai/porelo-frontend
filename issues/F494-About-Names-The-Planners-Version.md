# F494 — About Names The Planner's Version

```json
{
  "$schema": "issue-1.json",
  "id": "F494",
  "title": "About Names The Planner's Version",
  "state": "Rework",
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

Asked by the operator during the walks of a real idea to Finished, where the planner was swapped between builds (daace48,
f9e58ea, f1dbbcd) and nothing in the window told which one answered.

## The planner's contract (agreed 2026-11-12)

`GET /health`, with the token as today, answers `{"status": "UP", "version": "<version>", "commit": "<40 hex>"}`:
`version` is the package's (`x.y.z`, or `x.y.z~snapshot.<run>`, as its .deb and .rpm), `commit` the commit it was
built from or null where the build had no checkout. `status` stays as it is; `planner.json` gets neither field.

## Rework

Its code never reached `main`: it lies on the local branch `f494-on-f523`, its first commit there brought onto the
window's code as it stood after the planner's calls were made safe. Taken as it is, it undoes that:

- `askPlannerBuild` (`lib/src/app/planner_build.dart`) reads the planner's `/health` with `Authorization: Bearer
  <the planner's token>`, while the window's own calls to the planner go through `callOwnPlanner`, signed and only to a
  listener that proved it holds the token, so the token itself is never sent. About would send it again to whatever
  listens on the port the address file names.
- Its second commit (a byte cap on the planner's answers, a version kept beside a commit of the wrong shape) conflicts
  with that call path in `lib/src/app/planner_log_level.dart`, which already reads through `callOwnPlanner` with a
  64 KiB bound.

What the rework takes: `askPlannerBuild` moved onto `callOwnPlanner('GET', ['health'], maxBody: 64 * 1024)`; red first,
a test whose listener sees no `Authorization` header on the health call; the second commit's version handling folded in
where it still applies; the whole suite; and one reading by another model, since it touches the token's trust boundary.

## Plan

- The window asks the planner's `/health` (a new request, with the token and the loopback-only rules of the log
  level's), following no redirect and reading at most 64 KiB. Any answer counts as reached; only no answer is "not
  reached". A missing or malformed `version` (or a redirect, or a body past the limit) reads as one that names no
  version; a missing or malformed `commit` drops the commit alone.
- About shows it in its own line beside porelo's, with the commit's first twelve characters where it is given, and
  says "not reached" or "says no version" where that is so.
- Tests, red first: the health read takes version and commit, takes a null commit, and an older answer as no version;
  a widget test opens About with a planner that names a version and commit, one with a null commit, one that names
  none, and none reached.

## Acceptance

- About names the planner's version beside porelo's while a planner answers.
- About says in words that no planner is reached, or that it names no version, where that is so.
