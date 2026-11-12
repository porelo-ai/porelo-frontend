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

**Why this size.** one more line in About, read from the planner the window reaches, with its test; S, once the
planner says its version. It waits on porelo-planner's PL89, which gives the version.

**What must be true.** A person who opens About sees, beside "this machine: Porelo 0.5.1~snapshot.500", the version of
the planner the window runs, for example "planner: porelo-planner <version>". Where the window reaches no planner, or
the planner says no version, About says so in words instead of leaving the line out. Today About names porelo's
version alone, and "built from source" for the window itself.

Asked by the operator during F492's walks, where the planner was swapped between builds (daace48, f9e58ea, f1dbbcd)
and nothing in the window told which one answered.

## To be checked

- The planner's contract has no version to read today: `/health` answers its status alone, and the address file
  `planner.json` holds its port, token and log. The planner's part is PL89 "The Planner Names Its Version To The
  Window"; where the version is read (`/health`, `planner.json` or both) follows its plan.

## Plan

- The window reads the planner's version where the planner gives it, from the planner it reaches as it reaches it now.
- About shows it in its own line beside porelo's, and says "not reached" or "says no version" where that is so.
- A widget test opens About with a planner that names a version, one that names none, and none reached.

## Acceptance

- About names the planner's version beside porelo's while a planner answers.
- About says in words that no planner is reached, or that it names no version, where that is so.
