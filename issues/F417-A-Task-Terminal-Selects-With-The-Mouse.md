# F417 — A Task's Terminal Selects With The Mouse

**Status:** Backlog.
**Size:** S - the cause found on the operator's setup first, then a drag, and a Shift+drag always, selecting in a
task's terminal as the line under it promises, and a plain drag no longer leaving tmux a press with no release.

**What must be true.** In a task's terminal under Work → Running, Shift+drag selects text in the window whatever the
program asked of the mouse, as the line under it says, and the selection copies with the copy keys; a plain drag
either selects as well or is the program's whole, press, motion and release.

## Why

The operator's walk on the rehearsal VM (2026-11-06): in the sluice task's terminal (tmux in the container), text
could not be selected with the mouse, neither by drag nor by Shift+drag, though the line below says "Select with
Shift+drag · Paste with Ctrl+Shift+V".

## What the code does

- `session_view.dart`: a pointer down with Shift held suspends the terminal's pointer reports
  (`setSuspendPointerInput`), so the gesture goes to the window's own selection and tmux hears nothing.
- The vendored `packages/xterm` (`gesture_handler.dart`) selects on every mouse drag, Shift or not; only taps are
  reported to the program. A plain drag therefore selects too, but reports the press to tmux and never its release
  (the drag wins over the tap), leaving tmux with a button held.
- Nothing differs by machine: a task on this computer or on rehearsal uses the same `SessionView`; only Windows
  differs (the wheel).
- A widget test with tmux's own modes (alternate screen, 1000, 1002, 1006) and a redraw after the drag keeps the
  selection, with and without Shift (`task_terminal_test.dart` holds the Shift case). So the cause is not in these
  paths as tested.

## The operator's answers (2026-11-06)

The window runs on Linux (Ubuntu), with a mouse. A selection now shows, but stops at the terminal's top and bottom
edge and does not scroll on while dragging past it, so nothing longer than a screen can be selected. The screenshot
shows tmux in copy mode (`[56/379]` top right) with the highlight in tmux's colours: tmux selected, not the window.

## Cause

- The scrollback is tmux's, not the window's: tmux draws on the alternate screen, and the window's terminal holds only
  what is on screen. A selection longer than a screen can only be tmux's own, in its copy mode, which scrolls at the
  edges itself.
- The wheel is reported to tmux, as it asked, and puts it in copy mode (`[56/379]`).
- tmux selects by the press, the motion and the release it is told of (mouse modes 1002 and 1006). The vendored xterm
  never reports a drag's motion: it takes every mouse drag for its own selection of the screen, and tells the
  program only of the press. So tmux's selection starts at the press and the window's own stops at the screen's edge.

## Plan

- `packages/xterm` (`gesture_handler.dart`, `render.dart`): where the program asked for motion reports (1002 or
  1003) and Shift is not held, a mouse drag is the program's whole: its press, each motion and its release, and no
  selection of the window's; tmux then selects, scrolls past an edge and copies by OSC 52, which the window already
  passes to the clipboard (with `set-clipboard on` in the task's tmux; Agent Machines' or the image's setting).
- Shift+drag stays the window's selection of the screen, as the line under the terminal says; it says
  "Select with Shift+drag (this screen) · Drag to select in tmux".
- **The test that goes red first:** a terminal whose program asked for 1002 and 1006 sends a press, motions and a
  release for a plain mouse drag, and keeps no selection of its own. It guards a person who cannot select more than a
  screen of what the agent said.
