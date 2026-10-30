# F262 — Lock And Purge Say What They Do

**Status:** Accepted.
**Size:** XS - the server menu's *Lock* and *Purge* are named by what they do and their dialogs say the difference.

**What must be true.** The server menu says *Lock a person out of the server…* and *Delete a person's account from the server…*. The lock dialog says: access is turned off, the account and its home are kept, and admitting the person again undoes it. The delete dialog says: the Linux account, its home and the host's record of the person are deleted for good; the forge name stays blocked so it is never reused; nothing undoes it.

## Why

Operator's walk 23, step 12-4 (2026-10-30): "völlig unklar" what *Lock* and *Purge* do and how they differ.

## Plan

- Labels and dialog texts in `lib/src/ui/host_admin_dialog.dart`; walk and test keys unchanged.
- **Red first:** widget tests for the two labels and the sentences.

## Test

Only the change: the tests above. No VM run.

## Estimate

`F262 size=XS est=10 basis=median XS 10 (8 records)`
