# F464 — My Machines Keeps A Machine Being Prepared

```json
{
  "$schema": "issue-1.json",
  "id": "F464",
  "title": "My Machines Keeps A Machine Being Prepared",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 13,
  "blockedBy": [],
  "covers": "*My machines* keeps a machine being prepared in its list and count, the drop caught live first."
}
```

**Why this size.** the moment *My machines* drops a machine being prepared caught live with a picture, its cause found,
and the list kept whole through it.

**What must be true.** *My machines* keeps a machine being prepared in its list and its count throughout; a machine
read twice does not appear, vanish and appear again.
- Split from [F454](README.md#f454) by the operator's decision (2026-11-10): that one keeps the placing's outcome in
  its dialog, this one keeps the list whole.
- Not reproduced in the model: a test counting `machinesPageRows` and `listedMachines` on every notify of a
  preparation stayed green, so the drop does not come from `HostRuns` or `Machines`. Likely from outside them, the
  shell's ready callback or the organization's re-read.

## Plan

- Reproduce live first: prepare a machine through the window against the rented host, with pictures of *My machines*
  taken at a short interval, and the list's reads logged, until the drop is seen; name the read that lacks the
  machine.
- Red first: a test of that read's path, where a machine being prepared is missing from one read; today the count
  drops, and it must not.
- Keep the entry while its preparation runs, rather than replacing the list from a read that does not yet hold it.

## Acceptance

- The live drop is shown with its picture and the read that caused it.
- A preparation keeps *My machines* at its count through its end; seen to fail first.
