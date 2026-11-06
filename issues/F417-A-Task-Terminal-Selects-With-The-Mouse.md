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

## To be checked first, on the operator's setup

- Whether this window ran on Windows or Linux, and whether the drag was a mouse or a touchpad (a touchpad's drag may
  arrive as another pointer kind, which the terminal answers with a word selection or a scroll).
- Whether a selection showed and was lost (at the next redraw, or at the release), or never showed.

## Plan

- The cause named from the two checks, then the fix where it lies; with it, a plain drag sends tmux its release, or
  sends it nothing.
- **The test that goes red first:** the gesture as it arrives on the operator's setup (its pointer kind, its keys)
  selects in a terminal whose program asked for mouse reports. It guards a person who cannot copy what the agent said.
