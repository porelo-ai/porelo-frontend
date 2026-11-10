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
  *My machines* (`machines.forget`) and its connection files off the disk before it raised the connection anew, and
  put the new one back only once that raise had ended. The count dropped for the whole raise.
- `CardHostConnections._connect` raises the same connection where it stands: the entry, the machine the organization's
  card describes unchanged, stays listed and watched, its files stay, and no second entry replaces it. A connection
  the organization's card changed (address, port, host key, key of mine) or one marked disconnected is still taken
  down and made anew, as before.
- A refused raise takes the entry off, forgetting it before its files go, so nothing that watched it raises it again.
- A disconnect while *Connect* runs, on the organization's row or the machine's, stands: *Connect* then adds nothing
  and takes nothing off, and takes down only a connection it raised itself. It is counted on a count of its own, not
  on the organization's follow generation, which *Connect* and a down connection's ask also move.
- `Machines.forget` forgets only the entry as it was asked for; one changed meanwhile stays, still watched.
- `Settings.holdsMachine` takes the machine as it is now, so a failed save is not read as kept through an older
  entry of the same name.
- **Red first**, in `organization_connections_test.dart` with the second raise held before it publishes anything:
  *a machine just prepared stays listed, its files and its wait kept, while Connect raises it anew* (red: listed
  while it is raised anew, before the change; its files stay while it is raised anew, after the first round) and
  *a disconnect while Connect raises it anew stands* (red: the entry was no longer disconnected). In
  `machines_test.dart`: *forgetting an entry changed meanwhile leaves the entry as it is, still watched* (red: a null
  check in `Machines.of`) and *the store holds a machine only as it is now* (red: true for the older entry).
  *A machine just prepared whose raise anew is refused is taken off, its files with it* was green before; seen red
  with the files left in place.

## How it stands

- Built and tested in unit tests only; nothing ran against a host.
- The live capture with a picture stays for the operator's test: prepare a machine through the window, then press
  *Give it your token…* or *Connect* while it waits for its follow or its token, and watch *My machines* and its
  count through the raise.
- A raise refused on a machine that was listed still takes it off the list, with the refusal said; that is unchanged.
  A connection the organization's card changed still leaves the list while it is made anew.
- Reading fixed: a disconnect during *Connect* stands; forgetting a changed entry no longer leaves it unwatched; the
  same connection is raised in place, so the old watcher neither races a replacement nor republishes files, and the
  files stay while it is raised; *Connect* keeps the token's wait until its raise has ended; a failed save is no
  longer read as kept; *Connect* notifies once and never after it was disposed. The widget test that never reached
  *Connect* is removed.
- Declined from the reading: the second raise that `Machines.add` starts by itself after a *Connect* that kept a
  first connection not yet up. It predates this work and does not touch the list; the machine's own raise holds pace
  its tries. Also declined: saying the admission wait during the raise on a count of its own, since the kept entry's
  tunnel keeps saying it until the raise starts again.

## Acceptance

- The live drop is shown with its picture and the read that caused it.
- A preparation keeps *My machines* at its count through its end; seen to fail first.
