# F375 — What Down Says Stays On A Machine

**Status:** Review.

**What must be true.** When `down` says a thing stays on a machine, the person taking Porelo off reads it in the window, in full, and can copy the command it gives.

## Why

From collection `0.5.11`, `down` ends with a `note` line: the firewall stays on the machine, in what state, and the command that takes it off. A reader skips a state it does not know, and the window's does, so the sentence stops at `porelo-host`.

## Plan

- `StepState.note`, carried by `HostRun` from the play's line, ending and changing nothing.
- `HostSession.notes`, apart from the steps, each once, as plain text, and only so many.
- The take-down dialog says them above the steps, selectable.

## Acceptance

- A `note` from the play reaches the dialog, whole, and `down` ends as it would have.
- A machine's text cannot arrange a line of it.
- Seen to fail first.

## Decided while building

- **A rental given back says nothing more.** The note speaks of a machine that is no longer the person's, and telling them how to change it would mislead. While the rental is still theirs, and when its return is not confirmed, the note stands.
- **The notes of a try stay through a retry**, and a note after a failed task still goes out: the machine is still there, with what stays on it.
- **On standard error a note is one line**, so a machine's words cannot forge a line of what the command said.

## To be checked

- The note from a real `down`: the pinned collection is `0.5.10`, which does not say it. Only the line's form, as the collection's own test states it, is shown here until the pin moves.
