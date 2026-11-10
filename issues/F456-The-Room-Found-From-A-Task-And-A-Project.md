# F456 — The Room Found From A Task And A Project

```json
{
  "$schema": "issue-1.json",
  "id": "F456",
  "title": "The Room Found From A Task And A Project",
  "state": "Review",
  "size": "XS",
  "priority": "Medium",
  "rank": 8,
  "blockedBy": [],
  "covers": "The project's room opened in one step from a task tile and the project's page."
}
```

**Why this size.** the existing room action placed where a person looks for it, by its own name.

**What must be true.** A person finds a project's room from the task they work in and from the project's page in one
step, by a name that says it is the room.
- A task's tile and the project's page offer *Open the project's room*, beside the project's other actions, not only
  inside the project's ⋮ menu under *Messages and the project's room*.

## Plan

- `lib/src/app/commands.dart` holds the command (`Messages and the project’s room`); it gets a second home on the
  task tile and the project page with its own label, reaching the same dialog.

## How it stands

- A task's tile menu offers *Open its project’s room* (`work.room` in `lib/src/app/commands.dart`), which opens the
  room dialog of the task's own project, not the selected one; it is unavailable, with the reason, where the task
  names no project, the project is not listed on the machine, or it has no conversation.
- The project's page offers *Open the project’s room* as a button of its own under its title, beside the page's
  other actions, running the project's room command; unavailable, with the reason in its tooltip, where the project
  has no conversation. The menu entry keeps its name, *Messages and the project’s room*, which the feature steps use.
- On the task's tile the room is an entry of the tile's ⋮ menu, where every action on a task is; no tile carries a
  button of its own for any of them.

## Acceptance

- From a task tile and from the project page, one press opens the room dialog of that project.
