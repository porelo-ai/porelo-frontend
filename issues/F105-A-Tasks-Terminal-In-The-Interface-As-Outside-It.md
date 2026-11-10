# F105 — A Task's Terminal In The Interface As Outside It

```json
{
  "$schema": "issue-1.json",
  "id": "F105",
  "title": "A Task's Terminal In The Interface As Outside It",
  "state": "Estimated",
  "size": "M",
  "priority": "Medium",
  "rank": 6,
  "blockedBy": [],
  "covers": "A task's terminal in the interface behaves as in a plain terminal."
}
```

**Why this size.** a measurement on the VM, then the session, its view and its key handling, with
unit tests and a scenario against a real task; no contract changes.

**What must be true.** A task's terminal in the interface behaves as the same task in a plain
terminal, now that Porelo has set its tmux up for that: keys, colours, the clipboard and scrolling
reach the task and come back as they do outside the interface.

## Why

Porelo sets a task's tmux up to behave as the terminal
outside it, measured per key in a plain terminal:
- Esc arrives at once.
- Shift+Enter and focus events come through.
- Truecolor and OSC 52 come through.
- Shift+PageUp scrolls back in tmux's copy mode, and Shift+PageDown scrolls down again and leaves it.

Each person can add their own settings in `$XDG_CONFIG_HOME/porelo/tmux.conf`.

The interface is one of those outside terminals, and it was not measured. Its terminal is the `xterm`
library with a scrollback of its own of 10,000 lines (`lib/src/app/session.dart`). What it sends for
these keys, and whether it keeps some of them for itself, is not known. Shift+PageUp, for example,
might scroll its own scrollback instead of reaching tmux, and its own scrollback holds only what
passed through it, not tmux's history.

## The shape

- **Measure first**, through the interface on the VM, for the same keys and capabilities as above:
  Esc, Shift+Enter, Ctrl and Alt with the arrows, truecolor, OSC 52, focus events, the mouse wheel,
  and Shift+PageUp/PageDown. Do it once in a plain terminal and once in the interface, against the
  same task.
- **Then make the interface send what a plain terminal sends**, and decide which scrollback a person
  uses: the interface's own or tmux's. They must not fight over the same keys.

`lib/src/app/session.dart` handles OSC 52 writes through `_copied`, but does not check for a person's
key or mouse action or ask for confirmation with a preview, so it does not meet the clipboard promise below.

## Plan

- **Measure first.** On the VM, against one task, a plain terminal and the interface side by side,
  per key and capability in *The shape*. Write down the bytes each sends, as a table in the issue.
- **Red first: a per-key test**, a new `test/ui/session_keys_test.dart` built as
  `test/ui/session_keys_on_windows_test.dart` is: a `Session` with a fake `OpenTerminal`, a
  `SessionView`, keys sent by `WidgetTester`, and the bytes that reach the channel compared with
  the table. One test per key; each fails where the interface differs today.
- **Keys** go through `Session`'s input handler in `lib/src/app/session.dart`
  (`CascadeInputHandler` of `ModifiedKeys` and `defaultInputHandler`). What differs gets a handler
  beside `ModifiedKeys` in `lib/src/app/modified_keys.dart`, or a new file of its own, asked for by
  the far end where tmux asks for it.
- **Focus events and OSC 52** are output the far end sends: read in `Session`'s `Terminal` set-up
  (`onPrivateOSC = _hyperlink` reads OSC 8, OSC 52 and `5379`). OSC 52 writes this computer's
  clipboard without a word only right after the person's own key or mouse action in that terminal,
  as tmux's copy mode does; any other write asks first, with a preview of what would be written.
  Focus reports go out when the `TerminalView`'s `focusNode` in
  `lib/src/ui/session_view.dart` gains and loses focus.
- **Scrolling: tmux's alone.** For a task the interface gives up its own scrollback. The
  `TerminalView`'s `shortcuts` (`terminalShortcuts`, `lib/src/ui/terminal_copy.dart`) must not
  take Shift+PageUp/PageDown, and the wheel goes to tmux everywhere, as `Session.wheel` does on
  Windows today. `Session.scrollback` and the `leaving-is-safe` line under the terminal follow the
  decision.
- **Against a real task**: a scenario in `integration_test/reaching_a_machine.feature` that sends
  Shift+PageUp and the wheel through the interface and sees tmux's copy mode, and Shift+PageDown
  leave it.

## Acceptance

- **A per-key test** for each key and capability above, through the interface's terminal against a
  real task, each seen to fail first where the interface differs today.
- **Scrolling back and down works** in the interface as in a plain terminal, by the keys and by the
  wheel.

