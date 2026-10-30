# F242 — A File Chooser Beside Every Path Field

**Status:** Idea. Held as an Idea (operator, 2026-10-30, after walk 23): wizard changes wait until he has gone through the whole flow again.
**Size:** S - one path field with a *Choose…* button and its default, shared by every wizard that asks for a file on this computer.

**What must be true.** Every wizard field that names a file on this computer has a *Choose…* button beside it that opens a file chooser in the field's folder. The field keeps typing as a way, and holds the known default where there is one. A chosen file is checked as a typed one is.

## Why

Operator's finding in walk 23, step 6-7 on VM A (2026-10-30), in *Put walk6-demo on a server*, Step 5 of 7 — *Your secrets file*: the secrets file needs a button that opens a file chooser, instead of typing the path.

The fields differ today:
- *Prepare a server…* has *Choose…* beside each path (`_pathField` in `lib/src/ui/host_dialog.dart`).
- The bring has a separate button for its signing key, and the join one for its signing key.
- The bring's *Secrets file path* and *Your SSH identity file*, the join's *Secrets file path* and the Developers dialog's two files have none.

## Plan

- `_pathField` moves from `host_dialog.dart` into a shared widget (beside `lib/src/ui/pick_a_file.dart`): the text field, *Choose…* opening in the folder of the current value, and the last folder remembered for the dialog.
- Fields covered, each with its default:
  - Bring (`project_bring_dialog.dart`):
    - *Project signing public key file* (Step 1 of 7): the followed project's pinned key per [F239](README.md#f239), else `~/.ssh/id_ed25519.pub`.
    - *Your SSH identity file*: `~/.ssh/id_ed25519`.
    - *Secrets file path* (Step 5 of 7): the kept secrets file, else `~/Porelo/secrets.kdbx`.
  - Join (`project_join_dialog.dart`): *Project signing public key file*, as in the bring; *Secrets file path*, as in the bring.
  - Developers (`project_developers_dialog.dart`): *Project signing public key file* and *Your SSH identity file*, as in the bring.
  - *Prepare a server…* (`host_dialog.dart`): *Your private ssh key* with its `.pub` brought along, *Public key for signing commits (.pub)*, *Your secrets file (.kdbx)* (`~/Porelo/secrets.kdbx`), *Test collection (.tar.gz)*: already with *Choose…*, moved onto the shared widget.
- The separate "Choose the public key file…" buttons of the bring and the join go; the field's own *Choose…* takes their place.
- **Red first:** a widget test per dialog that *Choose…* beside the secrets file fills the field from a stand-in chooser, and that the field shows its default when nothing is kept.

## Test

Only the change: the widget tests above and the dialogs' own tests, with a stand-in chooser. No VM run.
