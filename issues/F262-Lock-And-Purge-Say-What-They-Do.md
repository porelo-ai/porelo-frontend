# F262 — Lock And Purge Say What They Do

**Status:** Idea. Held: GUI changes wait until the whole flow has been gone through again.
**Size:** XS - the server menu's *Lock* and *Purge* are named by what they do and their dialogs say the difference.

**What must be true.** The server menu says *Lock a person out of the server…* and *Delete a person's account from the server…*. The lock dialog says: access is turned off, the account and its home are kept, and admitting the person again undoes it. The delete dialog says: the Linux account, its home and the host's record of the person are deleted for good; the forge name stays blocked so it is never reused; nothing undoes it.

## Why

`lib/src/ui/organization_host_pages.dart` has no server *Lock* or *Purge* menu. A project member's menu in
`lib/src/ui/organization_project_pages.dart` says *Lock* or *Unlock*. `_MemberRowState._lock` writes the change
immediately, with no dialog explaining a lock. The explanation beside *Remove…* concerns removal, not locking.
The lock explanation promised above is not provided by this file; the server account deletion dialog has no
matching control here.

## Plan

- Labels and dialog texts in `lib/src/ui/organization_project_pages.dart` and
  `lib/src/ui/organization_host_pages.dart`; walk and test keys unchanged.
- **Red first:** widget tests for the two labels and the sentences.

## Test

Only the change: the tests above. No VM run.

## Estimate

`F262 size=XS est=10 basis=median XS 10 (8 records)`
