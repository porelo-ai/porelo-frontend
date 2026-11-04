# F242 — A File Chooser Beside Every Path Field

**Status:** Idea. Held: wizard changes wait until the whole flow has been gone through again.
**Size:** S - one path field with a *Choose…* button and its default, shared by every wizard that asks for a file on this computer.

**What must be true.** Every wizard field that names a file on this computer has a *Choose…* button beside it that opens a file chooser in the field's folder. The field keeps typing as a way, and holds the known default where there is one. A chosen file is checked as a typed one is.

## Why

The *Your KeePassXC database* fields in `lib/src/ui/identity_view.dart` are plain text fields in
`FirstStartWizard`, `IdentityDialog` and `ReplaceLostKeyDialog`. They have no chooser or known path default,
so they do not meet the promise above. `pickWithTheDesktop` in `lib/src/ui/pick_a_file.dart` provides a chooser.

`HostDialog` in `lib/src/ui/host_dialog.dart` has no file path field or `_pathField` helper. The Bring, Join and
Developers dialog files named in the plan have no file in this checkout; their field sets have no matching form.
The plan's widget move and those field-specific requirements need a scope decision; they stay below unchanged.

## Plan

- `_pathField` moves from `host_dialog.dart` into a shared widget (beside `lib/src/ui/pick_a_file.dart`): the text field, *Choose…* opening in the folder of the current value, and the last folder remembered for the dialog.
- Fields covered, each with its default:
  - Bring (`project_bring_dialog.dart`):
    - *Project signing public key file* (Step 1 of 7): the followed project's pinned key per [F239](README.md#f239), else the default SSH public key.
    - *Your SSH identity file*: the default SSH private key.
    - *Secrets file path* (Step 5 of 7): the kept secrets file, else `~/Porelo/secrets.kdbx`.
  - Join (`project_join_dialog.dart`): *Project signing public key file*, as in the bring; *Secrets file path*, as in the bring.
  - Developers (`project_developers_dialog.dart`): *Project signing public key file* and *Your SSH identity file*, as in the bring.
  - *Prepare a server…* (`host_dialog.dart`): *Your private ssh key* with its `.pub` brought along, *Public key for signing commits (.pub)*, *Your secrets file (.kdbx)* (`~/Porelo/secrets.kdbx`), *Test collection (.tar.gz)*: already with *Choose…*, moved onto the shared widget.
- The separate "Choose the public key file…" buttons of the bring and the join go; the field's own *Choose…* takes their place.
- **Red first:** a widget test per dialog that *Choose…* beside the secrets file fills the field from a stand-in chooser, and that the field shows its default when nothing is kept.

## Test

Only the change: the widget tests above and the dialogs' own tests, with a stand-in chooser. No VM run.
