# F458 — The Task Terminal Grows With The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F458",
  "title": "The Task Terminal Grows With The Window",
  "state": "Implementing",
  "size": "XS",
  "priority": "Medium",
  "rank": 10,
  "blockedBy": [],
  "covers": "The agent's screen grows with the window."
}
```

**Why this size.** the window's resize checked to reach the session, and a test of it once the session follows.

**What must be true.** When the window grows, the agent's screen in a task's terminal grows with it; no filler of
dots stands where the screen should be.
- A resize of the terminal view reaches the session as the new size, and the session takes the size of the latest
  client.

## Plan

- The size travels without a call of the daemon: the contract has no resize, and the session is
  `porelo task attach` run in a pty here (over `ssh -t` for a machine elsewhere), which the contract allows.
  `lib/src/app/session.dart` hands every new size of the terminal view to the pty (`_resized` → `resize`),
  `lib/src/app/pty.dart` sets it on the terminal (`TIOCSWINSZ`), the kernel signals it (`SIGWINCH`) to what runs
  there, and ssh, `porelo task attach` and tmux follow from that signal.
- Two tests hold the window's part: `test/ui/task_terminal_test.dart` that a grown window sends the session its new
  size once, and `test/app/pty_test.dart` that a new size is signalled to what runs there, against the real kernel.
- The session's own policy is the machine's (`window-size latest` in the task image's tmux configuration); the walk
  checks that the screen fills the view against a host whose image has it.

## How it stands

Porelo's session sizing after the latest client is on its main (2026-11-10), in its review.

- The window's part holds today: `test/ui/task_terminal_test.dart` ('a grown window sends the session its new size
  once, and a redraw sends none') shows a redraw at the same size sends nothing and a grown window one new size. It
  passed at once, so it was seen red by making the window send each size twice.
- `test/app/pty_test.dart` ('a new size is signalled to what runs there') starts a shell that waits for `SIGWINCH`
  alone and reads the size when it comes. It passed at once; with the terminal opened `O_NOCTTY`, so it is no
  controlling terminal, it went red (the shell never heard the size and was ended at its bound) while the test that
  reads the size on a line typed stayed green: that one cannot see a size nobody is told about.
- The contract offers no resize and needs none: the size reaches the session inside the terminal that attaches.
- Porelo's measurement of the session sizing after the latest client (tmux 3.6, `window-size latest`, 2026-11-10): the client that attaches, resizes or is
  typed in takes the size, and the one left gets it back when the other detaches; with today's `smallest` a big
  client never gets more than the small one has. A person's own terminal on the same session takes the size back
  when they type there. No change in the window follows from it.
- Left, live: that `ssh -t` passes the size on as a window change and `porelo task attach` into the container, and the
  walk's check that the screen fills the view, against a host whose sessions follow the latest client.

## Acceptance

- Against a machine whose session follows the latest client: maximising the window fills the terminal with the
  agent's screen.
