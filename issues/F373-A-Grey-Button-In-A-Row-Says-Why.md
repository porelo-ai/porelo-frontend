# F373 — A Grey Button In A Row Says Why

**Status:** Review.

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

## Decided while building

- **A row's reason takes the line under its title**, in `ExpandableListRow`, so its height holds. A long reason is cut there, with a hover; opened, the row has that line back and says the reason whole below it.
- *Push approved main* and *Connect* say why at the end of the row's words in *My projects*, which already wrap.
- *Restart* says why under its button.
- *Join* and *Reset* say why once in the dialog's body, as `Not now: ...`: both give the same reason while the machine answers.
- **The organization's dialogs say nothing more.** Their confirm stays grey until the dialog is filled or while it asks, and each field and the dialog's progress line already say that.

## To be checked

- A column of rows, each saying the same reason: the reason may belong once above them. Not seen in a real column yet.
