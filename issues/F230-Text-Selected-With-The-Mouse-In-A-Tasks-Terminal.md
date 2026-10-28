# F230 — Text Selected With The Mouse In A Task's Terminal

**Status:** Analyzed; found in walk 21 after the operator's round of sprints 6 to 6i.
**Size:** S - selecting with the mouse in a task's terminal while the program in it asks for the mouse, Shift+drag
always selecting here, the measurement first, and their tests; about 1.5 hours.

**What must be true.** In a task's terminal in the interface, dragging with the mouse selects text that *Copy* (and
Ctrl+Shift+C) then copies, also while tmux or the agent in it takes mouse reports; **Shift+drag always selects in the
interface**, never reaching the program, as in other terminals. A click without a drag still reaches the program (tmux
panes, Claude Code's own mouse use).

## Why

Seen in walk 21 (20:18 local): in `porelo-sluice-dry-sluice` (tmux inside, Claude Code running) the operator could not
select text with the mouse; they thought it had worked before, but were not sure.

## Read from the code (not yet measured)

- Every task's tmux runs with `set -g mouse on` (porelo's `/etc/porelo/tmux.conf`, since porelo `e55e8f0d`, 9 October),
  so tmux asks the terminal for mouse reports. Nothing changed there today.
- The terminal widget (xterm 4.0.0, `TerminalView`) sends the press of a left button to the program while it asks for
  mouse reports (`_shouldSendTapEvent`), but keeps a drag to itself as a selection (`onDragStart`/`onDragUpdate`)
  without sending the motion or the release. tmux then holds a press that never ends and starts its own selection on
  its next redraw, which can wipe the widget's selection; Claude Code redraws its screen often as well.
- So the likely cause is the mouse-report handover, not a change of the interface; the measurement below decides.

## Plan

1. **Measure first** (the issue's first step, on this laptop): a drag in (a) a plain shell tile, (b) a task with tmux
   and no agent, (c) the task with Claude Code; each with and without Shift; and against an older bundle (`2777507`,
   before today's changes) for (c). The result goes into this issue.
2. `session_view.dart`: a `Listener` before `TerminalView` that, while Shift is held, makes the pointer the widget's
   own (no report to the program) so the drag selects and stays selected; the widget's selection survives the
   program's redraws until the next click.
3. **Red first:** with a terminal whose program turned on mouse reports, a Shift+drag selects the dragged text and
   sends no mouse report; a plain click still sends its press and release.

## Acceptance

- In a task's terminal with Claude Code running, Shift+drag selects text and Copy copies it.
- A plain drag selects as well wherever the measurement shows the program does not take it; where it does, the hint
  below the terminal says Shift+drag selects.
