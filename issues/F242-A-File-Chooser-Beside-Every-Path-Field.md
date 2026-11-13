# F242 — A File Chooser Beside Every Path Field

```json
{
  "$schema": "issue-1.json",
  "id": "F242",
  "title": "A File Chooser Beside Every Path Field",
  "state": "Idea",
  "size": "S",
  "priority": "Low",
  "rank": 32,
  "blockedBy": [],
  "covers": "A *Choose…* button and the known default beside the KeePassXC database fields."
}
```

**Why this size.** one path field with a *Choose…* button and its default, shared by every wizard that asks for a file on this computer.

**How it stands.** Held: wizard changes wait until the whole flow has been gone through again.

**What must be true.** Every wizard field that names a file on this computer has a *Choose…* button beside it that opens a file chooser in the field's folder. The field keeps typing as a way, and holds the known default where there is one. A chosen file is checked as a typed one is.

## Why

The *Your KeePassXC database* fields in `lib/src/ui/identity_view.dart` are plain text fields in
`FirstStartWizard`, `IdentityDialog` and `ReplaceLostKeyDialog`. They have no chooser or known path default,
so they do not meet the promise above. `pickWithTheDesktop` in `lib/src/ui/pick_a_file.dart` provides a chooser.

These are the fields left that name a file on this computer: `HostDialog` in `lib/src/ui/host_dialog.dart` asks for
none, and the identity's forms take the place of the bring's, the join's and the developers' dialogs.

## Plan

- A shared widget beside `lib/src/ui/pick_a_file.dart`: the text field, *Choose…* opening in the folder of the
  current value through `pickWithTheDesktop`.
- Fields covered: *Your KeePassXC database* in `FirstStartWizard`, `IdentityDialog` and `ReplaceLostKeyDialog`
  (`lib/src/ui/identity_view.dart`), its default the database this computer knows.
- **Red first:** a widget test per dialog that *Choose…* fills the field from a stand-in chooser, and that the field
  shows its default when one is known.

## Test

Only the change: the widget tests above and the dialogs' own tests, with a stand-in chooser. No VM run.
