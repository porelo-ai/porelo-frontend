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

- `lib/src/app/session.dart`: the time of the person's last own action in that terminal, set where it comes in: the
  key handlers of the input cascade, the terminal's mouse `Listener` in `session_view.dart`, and a paste. Never from
  `onOutput` or `type()`: the terminal sends its own answers there (cursor position, device attributes, size) and focus
  reports, so a task could ask for one and count it as typed. The time comes from an injected clock.
- An OSC 52 write within two seconds of that action is copied at once and uses the action up: one action lets one
  write through. Any other is held as the one pending copy, a newer one replacing it, and the session tells its
  listeners. The held copy is dropped when the session is left. An empty write is ignored; unpadded base64 is
  normalized before it is read.
- `lib/src/ui/session_view.dart`: the held copy asks in a bar inside that task's view, as `TerminalLinks` does, never
  in a dialog that would cover another task's terminal. The bar shows the number of characters and lines and a preview
  with line breaks, control and bidi characters made visible, shortened at both ends where long; *Copy* and *Don't
  copy*.
- The vault sign-in and the setup's terminal use the same `Session`, so they get the same gate.
- Tests, red first. `test/app/session_clipboard_test.dart`: a write with no own action is held, not copied; a write
  right after the far end asked for the cursor position is held; one key lets one write through and holds the second;
  an empty write leaves the clipboard alone; a held write is dropped when the session is left; a write right after a
  typed key is copied (a guard). `test/ui/task_terminal_test.dart`: a held write asks with its preview, line breaks
  shown; *Don't copy* writes nothing, *Copy* writes it; the existing test of a silent write takes a key first; `?`
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
