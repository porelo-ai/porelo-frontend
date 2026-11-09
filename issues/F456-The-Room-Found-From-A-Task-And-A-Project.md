# F456 — The Room Found From A Task And A Project

**Status:** Backlog.
**Size:** XS - the existing room action placed where a person looks for it, by its own name.

**What must be true.** A person finds a project's room from the task they work in and from the project's page in one
step, by a name that says it is the room.
- A task's tile and the project's page offer *Open the project's room*, beside the project's other actions, not only
  inside the project's ⋮ menu under *Messages and the project's room*.

## Plan

- `lib/src/app/commands.dart` holds the command (`Messages and the project’s room`); it gets a second home on the
  task tile and the project page with its own label, reaching the same dialog.

## Acceptance

- From a task tile and from the project page, one press opens the room dialog of that project.
