# F514 — Small Points Of The Leftover Forwards Reading

```json
{
  "$schema": "issue-1.json",
  "id": "F514",
  "title": "Small Points Of The Leftover Forwards Reading",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 87,
  "blockedBy": [],
  "covers": "The small points a reading by another model found in the window's ending of leftover forwards: a lookup error taken for an ended process, a late connect left running, a directory descriptor kept on a failed allocation, tunnels stopped one after another, and the test gaps it named."
}
```

**Why this size.** S: four guards in the forward records and the tunnel, each with its red test, and the tests the
reading found missing.

**What must be true.** A forward's record is dropped only on proof that its process ended; every probe the window
gives up on is closed; no descriptor is kept on any failure path; and every tunnel gets its SIGKILL within the window's
five seconds of ending.

## Why

A reading of the final changes that leave no forward behind found, beside the grave points filed as [F513](README.md#f513):
- `isGone()` (`lib/src/app/forward_records.dart`) uses `typeSync()`, which answers `notFound` for a lookup error as
  well as for absence. A failed lookup of `/proc/<pid>` then drops a live forward's record.
- A probe whose `ConnectionTask` arrives after its timeout (`lib/src/app/tunnel.dart`) is neither cancelled nor
  consumed; the test hands the task over at once and so misses this.
- The directory chain of the forward records keeps its current descriptor when `arena.string(part)` throws: no
  `finally` closes it.
- `letGoTogether` starts the tunnel and forward groups at once, but the tunnels within their group stop one after
  another: three that ignore SIGTERM use up the five seconds before the third is killed.
- Test gaps:
  - replacement sockets
  - a bare `OSError` from the probe, and probe errors at the orphan clean-up and at start
  - the directory-owner checks
  - arguments that cannot be read
  - the record write's allocation order
  - the shell's call to `letGoTogether`
  - error swallowing in the helper, masked by its own timeout

## Plan

- `isGone()` reads `/proc/<pid>` with `stat` through FFI and takes only ENOENT or ESRCH as ended; any other error
  keeps the record.
- The probe keeps the pending future of its `ConnectionTask` and cancels the task when it arrives late.
- The directory chain closes its descriptor in a `finally` around each step.
- Tunnels stop together within their group, each with its own SIGTERM and SIGKILL inside the bound.
- Red first: one test per point above, and the missing ones listed.

## Estimate

`F514 size=S est=15 basis=median S 15 (11 records)`

## Decided

- Not guarded, each for its reason:
  - Replacement sockets, and what follows the probe at a card master's orphan clean-up, belong to the socket removal
    that [F513](README.md#f513) rebuilds: there a probe that fails only ends the bounded wait, and what is removed
    after it is decided by that removal, whose tests take them.
  - A probe error at the start is held already: a probe that fails for a reason of its own never removes the
    endpoint (`test/app/tunnel_test.dart`).
  - The shell's call to `letGoTogether` is one line in a widget of the whole window. `letGoTogether` is held, and a
    test of the window's close would hold the window's wiring rather than a harm.
  - The error swallowing in `letGoTogether` changes nothing anyone sees: `Future.wait` waits for every clean-up
    whether one throws or not, and the result is ignored either way. A test cannot tell it from its absence.

## How it was built

- `LinuxProcessTable.isGone` (`lib/src/app/forward_records.dart`) asks `statx` for `/proc/<pid>` and takes only
  ENOENT or ESRCH, where `/proc/self` can be read, as a process gone; any other failure keeps the record.
- `probeSocket` (`lib/src/app/tunnel.dart`) keeps the pending connection and cancels it once it arrives after the
  probe gave up, its socket's failure on that cancel handled.
- The directory chain closes its descriptor whatever the step's allocation does, and a record's temporary file is
  removed on any failure before its rename; a removal that fails there is left, never thrown over what failed first,
  as a temporary is never read.
- `Tunnels.dropEverything` stops every tunnel at once, a `Future.wait` of each tunnel's drop rather than one after
  another, so each gets its SIGTERM and, two seconds later, its SIGKILL inside the five seconds `letGoTogether` gives
  the window's end, which bounds the caller and not the drop itself.
- Tests in `test/app/tunnel_test.dart`. Each guard's test was seen red with its fix taken out: a record kept on EACCES
  and removed once the process is gone; only ENOENT or ESRCH say gone; a late connection cancelled, its socket
  failing as the SDK's does; every allocation of a record's write made to fail in turn with no descriptor and no
  temporary file kept; a temporary that cannot be removed throwing nothing; three tunnels that ignore SIGTERM all
  killed within five seconds. The gap tests hold code this issue did not change, so they pass before it as after; each
  was seen red with the code it holds broken on purpose: a bare `OSError` from a probe; records in a directory another
  account owns; a recorded pid whose arguments cannot be read.
