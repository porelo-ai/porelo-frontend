# F624 — A Local Project's Planning Directory Chosen In The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F624",
  "title": "A Local Project's Planning Directory Chosen In The Window",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 1,
  "blockedBy": [],
  "covers": "For a project whose stories and issues are kept locally, the person sees the directory the planner uses and may choose another, kept in the window's settings and handed to the planner with the project"
}
```

**What must be true.** For a project whose planning is kept locally (no forge's tracker), the person sees where the
planner keeps its stories and issues and may choose another directory for it. The choice is kept in the window's own
settings, never in the project's files. A chosen directory the planner refuses is said with its path, and the person
picks again; the planner never falls back to its default meanwhile.

## The contract it builds on

- The planner's project answer carries `tracker.kind` (`github` or `local`) and, for a local project, `items`: the
  directory it uses, the default included.
- The screen's `PlannerProject` takes an optional `items`, an absolute path of one line and at most 4096 characters,
  sent with the project (`PUT /projects/{project}`) only when set.
- A set directory that is missing, a link or not the account's own is refused as `ItemsDirectoryRefused` with
  `parameters.items` naming it; `items` sent for a project that is not local is refused as `ProjectRefused`.

## To be checked

- The planner commit carrying this contract, for the pin.
