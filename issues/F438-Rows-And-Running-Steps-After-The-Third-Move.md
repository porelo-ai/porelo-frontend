# F438 — Rows And Running Steps After The Third Move

**Status:** Implementing.

**What must be true.** A row keeps its chip and buttons inside itself, a running step says that it runs and how it
ended, a machine not yet admitting the person says that it waits instead of showing a refusal, and every output that
grows (the Prepare protocol, a task's terminal) follows its last line until the person scrolls back, and lets them go
back to the latest.

## Why

The third move (2026-11-08) showed each of these; the operator decided them that evening and gave the word to build,
with the design *Third move findings, before and after* (pairs 1 and 2-4).

## Acceptance

- **The organization's Machines row** (finding 1): the state chip sits in the row's line before the name, never above
  the row's edge; the row's buttons (*Set up this machine…*, *Connect*, …) stand right-aligned in one line inside the
  row and wrap together when narrow, never past the row's bottom. At 1280, 840 and 390 wide.
- **The Prepare protocol** (finding 2): while the person has not scrolled up, the last line is always at the bottom;
  scrolling up stops following and shows *Following* off; scrolling to the end, or *Following* on, follows again.
- **Right after Prepare** (finding 3): while the machine has not yet made the person's account (its first follow runs
  within five minutes), the side bar and the machine's row say "Waiting for the machine to admit you (its first
  follow, up to 5 min)" in a neutral mark, not a refusal in red; a refusal is shown only once that time has passed or
  the machine says it refuses the key.
- **Giving the token while putting a project on a machine** (finding 4): the button turns into a running state
  "Handing the token over…" with a spinner, never turns active again while it ends, and is replaced by "Done ·
  <machine> carries <project>." or by the refusal in words.
- **A task's terminal** (finding 12): the mouse wheel up goes into the history while the agent writes; new output does
  not pull the view down while the person reads; a *Jump to latest* button shows while scrolled back and goes to the
  end; scrolling to the end follows again. If this needs the task's tmux to pass the wheel (its mouse setting), that
  is the machine's side, said in the room, and the window's part is built and tested against a terminal that scrolls.

## Size

M: S the row, S the follow mode shared by the protocol and the terminal, XS the waiting words, XS the token's state.
