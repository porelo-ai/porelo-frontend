# F463 — This Machine Listed Once After Its Socket Moved

**Status:** Implementing.
**Size:** XS - the saved entry of this machine taken to where its socket is now, when the window loads.

**What must be true.** This machine is listed once, at its socket as it is now, whatever socket was saved for it.
- Seen live (2026-11-09, the move rehearsal against a rented host): the window's settings held *this machine* at a
  socket under an earlier runtime folder. On the next start `listedMachines` added the local daemon again beside it
  under the same name, the side bar keyed its rows by that name twice, and failed to draw ("Duplicate keys found");
  every scenario after it failed.

## Plan

- `lib/src/app/machines.dart` `load`: on Linux, a saved machine named as this machine, not a host and not reached
  through a tunnel, whose socket is not this machine's, is this machine at its socket now, and is saved so.
- Red first: a unit test with such a saved entry, which today lists *this machine* twice.

## Acceptance

- A saved *this machine* at another socket loads as one *this machine* at the local socket; seen to fail: two.
