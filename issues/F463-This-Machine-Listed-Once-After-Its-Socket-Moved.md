# F463 — This Machine Listed Once After Its Socket Moved

```json
{
  "$schema": "issue-1.json",
  "id": "F463",
  "title": "This Machine Listed Once After Its Socket Moved",
  "state": "Review",
  "size": "XS",
  "priority": "Medium",
  "rank": 3,
  "blockedBy": [],
  "covers": "This machine listed once, at its socket as it is now, whatever socket was saved for it."
}
```

**Why this size.** the saved entry of this machine taken to where its socket is now, when the window loads.

**What must be true.** This machine is listed once, at its socket as it is now, whatever socket was saved for it.
- Seen live (2026-11-09, the move rehearsal against a rented host): the window's settings held *this machine* at a
  socket under an earlier runtime folder. On the next start `listedMachines` added the local daemon again beside it
  under the same name, the side bar keyed its rows by that name twice, and failed to draw ("Duplicate keys found");
  every scenario after it failed.

## Plan

- `lib/src/app/machines.dart` `load`: on Linux, a saved machine named as this machine, not a host and not reached
  through a tunnel, whose socket is not this machine's, is this machine at its socket now, and is saved so.
- Red first: a unit test with such a saved entry, which today lists *this machine* twice.

## How it stands

- `load` in `lib/src/app/machines.dart` takes a saved *this machine* at another socket to the local socket before it
  opens anything, and saves it so: only the entry the window itself names so (a plain socket, no kind, no host, no
  tunnel) and only while `PORELO_SOCKET` names no other daemon. Seen red: `[this machine, this machine]`.
- `listedMachines` adds the local daemon only where no machine of its name is listed already, so no other route lists
  two rows of one name; a tunnelled machine named so keeps its way and is listed once. *Add a machine* refuses a name
  the side bar lists, this machine's included.
- Tests in `test/app/machines_test.dart`: the moved entry listed once at the local socket and saved so (seen red
  without the save), and a tunnelled one kept and listed once (seen red without the name check). One reading by
  another model; its findings (too wide a match, two rows by another route, the stale entry opened first, a test that
  could not fail) are all taken.

## Acceptance

- A saved *this machine* at another socket loads as one *this machine* at the local socket; seen to fail: two.
