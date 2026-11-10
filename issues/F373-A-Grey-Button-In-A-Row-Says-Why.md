# F373 — A Grey Button In A Row Says Why

```json
{
  "$schema": "issue-1.json",
  "id": "F373",
  "title": "A Grey Button In A Row Says Why",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 35,
  "blockedBy": [],
  "covers": "A grey button in a row, a pane or a dialog says why in words."
}
```

**Why this size.** the same line, in the places a list's head does not reach.

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
- **The organization's dialogs:** a confirm grey until a field is filled says nothing more. Two did not read plain, and now say: the role's dialog, already filled, asks for a role other than the current one; creating the repository says it is reading the organization.
- **Left as read:** *Join*'s `the machine is still answering` also covers the forward to the homeserver, a machine's work too. An opened row of a silent machine says its reason beside the notice's retry, as before this issue.

## To be checked

- A column of rows, each saying the same reason: the reason may belong once above them. Not seen in a real column yet.
