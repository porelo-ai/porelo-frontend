# F464 — My Machines Keeps A Machine Being Prepared

```json
{
  "$schema": "issue-1.json",
  "id": "F464",
  "title": "My Machines Keeps A Machine Being Prepared",
  "state": "Implementing",
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

- Caught in code, not live: a machine just prepared waits for its first follow or its first token, so its connection
  is not up. *Connect* asked again then, by the token's step or the organization's page, took the kept entry off
  *My machines* (`machines.forget`) before it raised the connection anew, and put the new one back only once that
  raise had ended; a refused raise left it off. The count dropped for the whole raise, and for good after a refusal.
- `CardHostConnections._connect` keeps the entry listed while it raises the connection anew; the new entry takes its
  place through `Machines.add`, and only a refused raise takes it off, as before.
- `Machines.add`, given the same host machine again, keeps the connection raised for it instead of taking it down,
  since *Connect* raises it before the entry takes the place.
- **Red first:** `organization_connections_test.dart`, *a machine just prepared stays listed while Connect raises it
  anew*, reading the list on every change while the second raise is held: it read the machine missing.
- A widget test, *My machines counts a machine being prepared on every frame until it stands*, reads the side bar's
  count and the row on every frame from the start of a preparation through its end; green on the code before, seen
  red with the machine added only after its preparation ended.

## How it stands

- Built and tested in unit and widget tests only; nothing ran against a host.
- The live capture with a picture stays for the operator's test: prepare a machine through the window, then press
  *Give it your token…* or *Connect* while it waits for its follow or its token, and watch *My machines* and its
  count through the raise.
- A raise refused on a machine that was listed still takes it off the list, with the refusal said; that is unchanged.

## Acceptance

- The live drop is shown with its picture and the read that caused it.
- A preparation keeps *My machines* at its count through its end; seen to fail first.
