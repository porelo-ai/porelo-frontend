# F508 — A Task's Clipboard Write Asks First

```json
{
  "$schema": "issue-1.json",
  "id": "F508",
  "title": "A Task's Clipboard Write Asks First",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 22,
  "blockedBy": [],
  "covers": "A task writes this computer's clipboard through OSC 52 without a word only right after the person's own key or mouse action in its terminal; any other write asks first, with a preview of what would be written."
}
```

**Why this size.** M: the person's own actions are caught where they come in (keys, mouse, paste), never from what
the terminal writes back; one silent write per action; an inline question with a preview that shows what it hides;
the held copy dropped with the session; and their tests, with one existing test rewritten.

**What must be true.** A task's terminal in the window writes this computer's clipboard silently only right after
the person's own key, mouse action or paste in that terminal, as tmux's copy mode does, and only once per action. Any
other write, one a task sends by itself, asks first and shows a preview of what would be written; refused, nothing is
written. A query of the clipboard (`?`) is never answered, as today.

Split from the window's terminal behaving as a plain terminal, where it was the one part that is not about keys and
scrolling.

## Why

Today `Session._copied` (`lib/src/app/session.dart`) writes every OSC 52 set at once, with no check and no preview,
whichever selection it names (`p` lands on the clipboard too). An empty write (`52;c;`) clears the person's clipboard;
unpadded base64 is dropped without a word. A task can thus put text on the clipboard that the person pastes into a
shell later, a trailing newline running it.

## Plan

- `lib/src/app/session.dart`: the time of the person's last own action in that terminal, on a monotonic clock
  (a `Stopwatch`, injected): a key down (`KeyDownEvent`, never `KeyRepeatEvent`, so a held key does not keep the gate
  open), a pointer down or up (never hover, move or scroll), a paste. Set in the view's `onKeyEvent`
  (`SessionView.onKey`, which runs first, Ctrl+Shift+V included), not in the input cascade: typed letters go through
  `textInput` straight to `onOutput` and never reach the cascade. Never from `onOutput` or `type()`: the terminal sends
  its own answers there (cursor position, device attributes, size), mouse reports and focus reports, so a task could
  ask for one and count it as typed. IME composing does not count, which fails safe.
- An OSC 52 write within two seconds of that action is copied at once and uses the action up: one action lets one
  write through. Any other is held as the one pending copy, a newer one replacing it, and the session tells its
  listeners. The held copy is dropped when the session is left. An empty write is ignored; unpadded base64 is
  normalized before it is read. Only a write naming the clipboard (`c`) is taken; `p`, `s` and the others are
  ignored. A write is judged once its OSC is complete, so splitting it across chunks gains nothing. A held copy is also
  dropped once the session is over, and is never kept in the settings or logged. A silent write clears a held one.
- What the gate proves is time, not cause: a task that writes in a loop gets one write through after each action of
  the person in its terminal. The issue narrows that to one write per action within two seconds; it does not close it.
- `lib/src/ui/session_view.dart`: the held copy asks in a bar inside that task's view, as `TerminalLinks` does, never
  in a dialog that would cover another task's terminal. The bar shows the number of characters and lines and a preview
  of the decoded text as it would be written, with line breaks, control, bidi, zero-width and invisible characters
  (U+200B, U+2060, U+FEFF, U+00AD, variation selectors, tag characters, no-break spaces) made visible. Where long it is
  shortened in the middle with the size and lines left out said, always showing the last line and whether the text ends
  in a line break. *Copy* and *Don't copy*; *Copy* takes no keyboard focus and no Enter, and copies the very item shown:
  a newer write replaces the bar and a click on the old one does nothing.
- The vault sign-in and the setup's terminals (`new_machine.dart`) build a bare `TerminalView`, and the unlock
  terminal has the bar but no key hook: the hook and the bar go into one widget each of them uses, so no write is held
  with nothing to ask.
- Tests, red first. `test/app/session_clipboard_test.dart`: a write with no own action is held, not copied; a write
  right after the far end asked for the cursor position is held; one key lets one write through and holds the second; an
  empty write leaves the clipboard alone; a held write is dropped when the session is left and when it is over; a write
  right after a typed letter is copied (a guard, through the text-input path); a held key's repeats count once; hover
  and move do not count; a mouse report or a device-attributes answer does not count; just inside and just past two
  seconds on the fake clock; a write split across chunks; `p` is ignored. `test/ui/task_terminal_test.dart`: a held
  write asks with its preview, line breaks shown; zero-width characters and a shortened middle are shown; *Don't copy*
  writes nothing, *Copy* writes it; a replacement while the bar shows ignores the click on the old one; Enter does not
  press *Copy*; the setup's and the unlock terminals ask too; the existing test of a silent write takes a key first; `?`
  stays unanswered.
- After the window's terminal sends what a plain terminal sends (it changes the same input cascade and the view's
  focus handling), so built on top of it.

## Acceptance

- A task's write to the clipboard right after the person's own action is copied without a word, once.
- Any other write asks in that task's view with its preview and is copied only when confirmed.
- An empty write changes nothing; a held write is gone once the task's terminal is closed.

## To be checked

- Whether OSC 52 reaches the window at all through ConPTY on Windows, which redraws the screen.

## Open questions

- Whether a person may let one task write without asking for the rest of its run. Not in this issue: it would widen
  what a task may do to the person's clipboard.
