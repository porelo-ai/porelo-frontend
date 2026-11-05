# F373 — A Grey Button In A Row Says Why

**Status:** Backlog.
**Size:** S - the same line, in the places a list's head does not reach.

**What must be true.** A grey button says why in words wherever it stands. A list's head does this; what follows does not yet, and has the reason behind a hover or none.

## Where

- A row's primary button, in `ExpandableListRow`.
- *Push approved main* in a row of *My projects*, and *Connect* where the row's words do not already say why.
- *Restart* in the operations pane.
- *Join* and *Reset* in the messages dialog.
- The confirm button of the organization's dialogs, greyed until the dialog is filled, where the reason may be plain enough to say nothing: to be decided for each.

## Acceptance

- Each grey button above says why in text, with no hover. Seen to fail first.
- A row's height does not jump as its command changes state.

## To be checked

- A column of rows, each saying the same reason: the reason may belong once above them.
