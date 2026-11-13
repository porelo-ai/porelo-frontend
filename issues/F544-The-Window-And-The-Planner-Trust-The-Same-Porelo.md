# F544 — The Window And The Planner Trust The Same Porelo

```json
{
  "$schema": "issue-1.json",
  "id": "F544",
  "title": "The Window And The Planner Trust The Same Porelo",
  "state": "Backlog",
  "size": "XS",
  "priority": "Medium",
  "rank": 111,
  "blockedBy": [],
  "covers": "The window hands the planner it starts only a Porelo executable the planner also accepts, so a person whose the account's own program folder is group-writable by their own group is never left with a planner that reads no repository."
}
```

**Why this size.** XS: one rule in `_whyNot`, the words of a refusal, and a test case, once the rule both sides keep is
decided.

Found on the test machine, where the account's own program folder is `drwxrwxr-x` with the person's own primary group (umask 002).
- `findPoreloExecutable` (`lib/src/app/porelo_executable.dart`) takes the account's own install before `/usr/bin/porelo`.
  Its `_whyNot` lets a folder through that only the person's own primary group may write, and the window passes that
  path as `PORELO_EXECUTABLE`.
- The planner refuses that same path because its folder is group-writable without the sticky bit, and lends no login.
  Every repository read then fails with `Unreadable`, the window never hands the project over, and the board stays
  empty.

**What must be true.**
- A Porelo executable the window passes as `PORELO_EXECUTABLE` is one the planner accepts. The two checks name the same
  rule for a folder that only the person's own group may write.
- Where the window refuses the account's own install, it goes on to `/usr/bin/porelo`, as it does for a missing file.
- A refusal is said in the window with the folder's name, as today.

**To be decided.** Either the window takes the planner's stricter rule, so that any group-writable folder without
the sticky bit is refused, or the planner takes the window's rule, allowing the person's own primary group.

## Plan

- Once the rule is decided:
  - If the window takes the planner's rule, drop the own-group allowance in `_whyNot`.
  - If the planner takes the window's rule, nothing changes here; a test pins the shared rule.
- `findPoreloExecutable` goes on to the next place after a refused one, instead of returning the refusal.
- Red first in `test/app/porelo_executable_test.dart`: a 0775 folder with the person's own group, under the decided
  rule, and the fall-through to `/usr/bin/porelo`.

`F544 size=XS est=10 basis=median XS 10 (8 records)`
