# F454 — Placing Says Its Progress In Its Dialog

**Status:** Backlog.
**Size:** S - the placing's progress and end said in the dialog that started it, and one list that does not drop a
machine while it is being prepared.

**What must be true.** A person who puts a project on a machine sees its progress and its end in the dialog they
started it from, and *My machines* never drops a machine for a moment while it is being prepared.
- *Put it on the machine* keeps its dialog open with the placing's steps, and ends with a line that says it succeeded
  or what failed; the project row says the same once the dialog is closed.
- *My machines* keeps a machine being prepared in its list and count throughout; a machine read twice does not
  appear, vanish and appear again.

## Plan

- The placing dialog (`lib/src/ui/host_dialog.dart`) follows the same operation the project row follows today and
  shows its lines and outcome; closing it leaves the row as it is.
- *My machines*' list (`lib/src/app/fleet_model.dart`, the machines it reads) keeps an entry while its preparation
  runs, rather than replacing the list from a read that does not yet hold it.
- Red first: a model test where a machine being prepared is missing from one read of the list; today the count drops,
  and it must not.

## Acceptance

- A placing in the mock ends with its success line in the dialog; seen to fail: a dialog that closes with no outcome.
- A preparation in the mock keeps *My machines* at its count through the end of the preparation.
