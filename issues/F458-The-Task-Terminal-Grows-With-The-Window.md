# F458 — The Task Terminal Grows With The Window

**Status:** Backlog; blocked by the task session's sizing on the machine, which today keeps the smallest attached
client's size.
**Size:** XS - the window's resize checked to reach the session, and a test of it once the session follows.

**What must be true.** When the window grows, the agent's screen in a task's terminal grows with it; no filler of
dots stands where the screen should be.
- A resize of the terminal view reaches the session as the new size, and the session takes the size of the latest
  client.

## Plan

- `lib/src/app/session.dart` sends the size on every resize (`_resized` → `resize`); the session's own policy is the
  machine's, so the window's part is a test that a resize is sent once per change, and the walk's check that the screen
  fills the view against a session that follows the latest client.

## Acceptance

- Against a machine whose session follows the latest client: maximising the window fills the terminal with the
  agent's screen.
