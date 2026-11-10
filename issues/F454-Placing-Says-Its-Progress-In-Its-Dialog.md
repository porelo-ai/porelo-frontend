# F454 — Placing Says Its Progress In Its Dialog

**Status:** Review.
**Size:** S - the placing's progress and end said in the dialog that started it.

**What must be true.** A person who puts a project on a machine sees its progress and its end in the dialog they
started it from.
- *Put it on the machine* keeps its dialog open with the placing's steps, and ends with a line that says it succeeded
  or what failed; the project row says the same once the dialog is closed.
- *My machines* keeping a machine being prepared went to [F464](README.md#f464).

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
- While the store is asked, the choice's body takes no pointer and no focus, so no list or token dialog opens over
  it; the answer closes the choice dialog itself, past anything lying over it. The placing dialog starts following
  after its first build, never inside it. Seen red: a list opened over a running write stayed, and the choice dialog
  with it. Cancel after a refusal follows nothing (seen red with the `taken` check removed).
- One code reading by another model: one must-fix (a write answered while a list or the token dialog lay over the
  choice popped that and left the choice stuck) and two may-fix (Cancel after a refusal untested; the placing dialog
  starting inside its build), all taken.
- *My machines* dropping a machine being prepared is its own issue, [F464](README.md#f464),
  by the operator's decision; it did not reproduce in the model and is to be caught live.

## Acceptance

- A placing in the mock ends with its success line in the dialog; seen to fail: a dialog that closes with no outcome.
- *My machines* through a preparation: see [F464](README.md#f464).
