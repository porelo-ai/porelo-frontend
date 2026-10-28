# F230 — Text Selected With The Mouse In A Task's Terminal

**Status:** Backlog; found in walk 21, placed in the backlog on the operator's word.
**Size:** S - Shift+drag selecting in the widget whatever the program asks for, tmux's own copy reaching the
clipboard over OSC 52, and their tests; about 2 hours.

**What must be true.** In a task's terminal in the interface, dragging with the mouse selects text that *Copy* (and
Ctrl+Shift+C) then copies, also while tmux or the agent in it takes mouse reports; **Shift+drag always selects in the
interface**, never reaching the program, as in other terminals. What tmux copies in its own copy mode (`set-clipboard
on` sends it as OSC 52) reaches this computer's clipboard. A click without a drag still reaches the program (tmux panes,
Claude Code's own mouse use).

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
- **Measured by the operator (20:21 local): Shift+drag does not select either.** So the widget passes a Shift+drag to
  the program as it does a plain one, and tmux's copy (OSC 52) does not reach the clipboard: the gap is the widget's,
  not porelo's (whose tmux settings are unchanged since 9 October).

## Plan

1. `session_view.dart`: while Shift is held, the pointer is the widget's own (the `TerminalController`'s pointer input
   off for that gesture), so the drag selects, sends no mouse report, and stays selected until the next click.
2. `session.dart`: the terminal's OSC 52 (`ESC ] 52 ; c ; <base64> BEL`) writes the decoded text to the clipboard,
   for the program's own copy; reading the clipboard over OSC 52 (`?`) is never answered.
3. **Red first:** with a terminal whose program turned on mouse reports, a Shift+drag selects the dragged text and
   sends no mouse report; a plain click still sends its press and release; an OSC 52 write puts its text on the
   clipboard and an OSC 52 read gets no answer.

## Acceptance

- In a task's terminal with Claude Code running, Shift+drag selects text and Copy copies it.
- A selection made in tmux's own copy mode is on this computer's clipboard.
- The hint below the terminal says Shift+drag selects.
