# F379 — Add A Project In One Step From The Window

**Status:** Backlog.
**Size:** S - one choice in the dialog, and the refusal's words.

**What must be true.** A person naming themselves Project Admin adds a project in the window in one step, as `porelo org project add PROJECT --admin LOGIN --create-repository` does. A person who names someone else keeps the two steps.

## Plan

- The window's *Add a project* takes the same shortcut, in the organization's read and write.
- It is two steps and not atomic: when the forge says no after the project was added, the refusal says the project stands, and what is left to do.

## Acceptance

- Each of the two ends in a test, seen to fail first.
