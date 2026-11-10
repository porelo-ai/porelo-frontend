# F454 — Placing Says Its Progress In Its Dialog

**Status:** Review.
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

## How it stands

- *Put it on the machine* now stays open until the store answers (`waitsForItsWrite` on `OrganizationChangeDialog`
  and `OrganizationPersonDialog` in `lib/src/ui/organization_dialogs.dart`). A refusal is said in that dialog beside
  the choice; a placing that was taken always goes on in the placing dialog, which follows the machine to its done
  line or its stop. Before, the choice closed at once onto a provisional row, and the placing dialog opened only
  where the organization's re-read already showed the machine carrying more, so a lagging read ended with nothing
  said. Seen red: both new tests in `test/ui/organization_carry_choice_test.dart`.
- The test fixture's `connect` now tells its listeners after an await, as `CardHostConnections` does; told inside
  the asking call, it marked the choice dialog's list dirty while the placing dialog was being built.
- *My machines* dropping a machine for a moment did not reproduce: a model test counting `machinesPageRows` and
  `listedMachines` on every notify of a preparation stayed green, so it was not kept (never red). The cause is
  outside `HostRuns` and `Machines`, likely the shell's ready callback or the organization's re-read; it needs a
  live run that shows it, with a picture, before it can be fixed. The coordinator decides whether that half stays
  here or goes to its own issue.

## Acceptance

- A placing in the mock ends with its success line in the dialog; seen to fail: a dialog that closes with no outcome.
- A preparation in the mock keeps *My machines* at its count through the end of the preparation.
