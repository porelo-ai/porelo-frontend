# F458 — The Task Terminal Grows With The Window

**Status:** Backlog; Porelo's session sizing after the latest client is on its main (2026-11-10), in its review.
**Size:** XS - the window's resize checked to reach the session, and a test of it once the session follows.

**What must be true.** When the window grows, the agent's screen in a task's terminal grows with it; no filler of
dots stands where the screen should be.
- A resize of the terminal view reaches the session as the new size, and the session takes the size of the latest
  client.

## Plan

- `lib/src/app/session.dart` sends the size on every resize (`_resized` → `resize`); the session's own policy is the
  machine's, so the window's part is a test that a resize is sent once per change, and the walk's check that the screen
  fills the view against a session that follows the latest client.

## How it stands

- The window's part holds today: `test/ui/task_terminal_test.dart` ('a grown window sends the session its new size
  once, and a redraw sends none') shows a redraw at the same size sends nothing and a grown window one new size. It
  passed at once, so it was seen red by making the window send each size twice.
- Porelo's measurement of the session sizing after the latest client (tmux 3.6, `window-size latest`, 2026-11-10): the client that attaches, resizes or is
  typed in takes the size, and the one left gets it back when the other detaches; with today's `smallest` a big
  client never gets more than the small one has. A person's own terminal on the same session takes the size back
  when they type there. No change in the window follows from it.
- Left: the walk's check that the screen fills the view, against a host whose sessions follow the latest client.

## Acceptance

- Against a machine whose session follows the latest client: maximising the window fills the terminal with the
  agent's screen.
