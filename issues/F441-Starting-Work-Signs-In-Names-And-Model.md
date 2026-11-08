# F441 — Starting Work Signs In, Names The Task And Its Model

**Status:** Implementing.

**What must be true.** Work starts in the window without a host shell: a missing sign-in of the task's agent is asked
for in the window and waited for, the forge token is handed over when the machine asks, a task is named as the person
named it, and the model the task runs is shown and can be changed before it starts.

## Why

The third move (2026-11-08), findings 7, 10 and 11, decided by the operator that evening. Their machine side (whether
an agent is signed in, one sign-in at a time per machine and agent, task and room names, the default model per
provider in a project's provider settings) is the backend's; the window builds its part against what the backend
offers and says what it waits for.

## Acceptance

- **The sign-in** (finding 7): starting work asks the machine whether the task's agent is signed in there; if not, the
  window shows "Sign in to <agent>" with the agent's own link and waits, then starts. A start of several tasks at once
  gathers the distinct machine and agent pairs first, asks each machine once, signs in the missing ones one after
  another, and only then starts all; a sign-in already running for that machine and agent is waited on, not opened a
  second time.
- **Names** (finding 10): a task is shown by the name given at its start, or short by its repository (`pi`); the
  container's name only in its details.
- **The model** (finding 11): *New work* shows the model the task will run, with the default from the project or the
  repository, and lets it be changed; the task's row and its terminal's header name it ("Claude Code · Opus 5.5 via
  anthropic"); a start of several tasks takes each repository's default without asking.

**Blocked by** the backend's sign-in state and default model (as the room settles them); the window's parts that do
not need them are built first.

## Size

L: M the sign-in and batch, S the names, S the model.
