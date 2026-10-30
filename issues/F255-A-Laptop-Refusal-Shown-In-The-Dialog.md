# F255 — A Laptop Refusal Shown In The Dialog

**Status:** Accepted.
**Size:** XS - *Keep laptop and add another* shows its refusal inside the dialog, as *Next* does.

**What must be true.** When *Keep laptop and add another* refuses the pasted keys or the address, the refusal stands in the dialog, in the same place and style as a refusal of *Next*, and stays until the fields change. No refusal of the developer dialog goes to a SnackBar behind the modal.

## Why

Operator's walk 23 on VM A (2026-10-30): the button's refusal went to `ScaffoldMessenger.showSnackBar` (`lib/src/ui/project_developers_dialog.dart`), behind the modal dialog, so the operator saw nothing happen.

## Plan

- The button sets the dialog's own refusal text, which *Next* already uses, instead of the SnackBar.
- **Red first:** a widget test that a refused keep shows the refusal text inside the dialog and no SnackBar.

## Test

Only the change: the test above and the dialog's own tests. No VM run.

## Estimate

`F255 size=XS est=10 basis=median XS 10 (8 records)`
