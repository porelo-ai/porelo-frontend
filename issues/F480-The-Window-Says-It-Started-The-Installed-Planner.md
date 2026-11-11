# F480 — The Window Says It Started The Installed Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F480",
  "title": "The Window Says It Started The Installed Planner",
  "state": "Idea",
  "size": "S",
  "priority": "Medium",
  "rank": 2,
  "blockedBy": [],
  "covers": "Where no planner was serving and the window started one itself, the planning place says so, with the program it started, so a person expecting their own planner sees that another one answers."
}
```

**Why this size.** one line of the planning place, worded from what `LocalPlanner` knows, and its widget test.

**What must be true.** A person who expected a planner of their own, such as one built from source, sees at once that
the window found none serving and started the installed one, and which program that was.

## Why

During a measurement, the window found no planner serving and started the installed `/usr/libexec/porelo/planner`,
an older build; the board then failed on an answer the current planner no longer gives. Nothing on screen said that
the window had started a planner of its own, so the failure read as one of the planner being measured.

## To be checked

- Whether the planner answers its own version, so the line can name it beside the program.
