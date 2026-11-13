# F262 — Lock And Purge Say What They Do

```json
{
  "$schema": "issue-1.json",
  "id": "F262",
  "title": "Lock And Purge Say What They Do",
  "state": "Idea",
  "size": "XS",
  "priority": "Low",
  "rank": 34,
  "blockedBy": [],
  "covers": "A project member's *Lock* says what it does."
}
```

**Why this size.** a project member's *Lock* says what it does.

**How it stands.** Held: GUI changes wait until the whole flow has been gone through again.

**What must be true.** A project member's *Lock* says what it does: access is turned off, the account and its home are kept until the deletion day the machine names, and *Unlock* undoes it.

## Why

A project member's menu in
`lib/src/ui/organization_project_pages.dart` says *Lock* or *Unlock*. `_MemberRowState._lock` writes the change
immediately, with no dialog explaining a lock. The explanation beside *Remove…* concerns removal, not locking.
The lock explanation promised above is not provided by this file. An account is not deleted by a person: a machine
deletes a locked person's account on its day, and `lib/src/ui/organization_host_pages.dart` names that day.

## Plan

- Label and words in `lib/src/ui/organization_project_pages.dart`; walk and test keys unchanged.
- **Red first:** a widget test for the sentence.

## Test

Only the change: the tests above. No VM run.

## Estimate

`F262 size=XS est=10 basis=median XS 10 (8 records)`
