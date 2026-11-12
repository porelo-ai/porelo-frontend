# F514 — Small Points Of The Leftover Forwards Reading

```json
{
  "$schema": "issue-1.json",
  "id": "F514",
  "title": "Small Points Of The Leftover Forwards Reading",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
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

A reading of [F219](README.md#f219)'s final changes found, beside the grave points filed as [F513](README.md#f513):
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
