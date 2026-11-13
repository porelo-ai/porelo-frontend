# F528 — Attention Reads Only The Machines Being Watched

```json
{
  "$schema": "issue-1.json",
  "id": "F528",
  "title": "Attention Reads Only The Machines Being Watched",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 100,
  "blockedBy": [],
  "covers": "What needs the person's attention is worked out without an error while a machine is still being opened: a machine in the list whose fleet is not watched yet counts as not answering."
}
```

**Why this size.** S: one lookup that may find nothing, its callers and a test that opens a second machine while the
planning boards change.

**What must be true.** While the window opens a machine, a change on the planning boards works out what needs the
person's attention without an exception: a machine in the list whose fleet is not watched yet is taken as not
answering, and nothing reads a fleet that is not there.

## Found

The story test of loading, a timeout and a forgotten connection, played on the local VM, caught it in its first
scenario: `Null check operator used on a null value` in `Machines.of` (`lib/src/app/machines.dart`, `_watching[name]!`),
called from `Attention._changed` (`lib/src/app/attention.dart`) while `PlanningBoards` notified during
`Machines._open` → `FleetModel.connect`. Every step of the scenario held; the error failed it afterwards.

The same error comes at every start of the window whose saved machines list a machine with a host card ahead of
another machine: `Machines._adopt` lists every machine first and then opens them one by one; a card machine skips the
tunnel and its `FleetModel.connect` notifies before its first pause, so `Attention._changed` and `Attention._follow`
walk a machine that is listed and not opened yet. Seen in the story test of an agent working, resting or waiting, on
the VM account's own machines (a rented host's card saved before the e2e machine).

## Plan

- To be read first: which machines `Machines.all` holds that `_watching` does not yet (one listed and not opened,
  one set aside, one opening), and every caller of `Machines.of` that walks `all`.
- A lookup that answers null for a machine not watched, used where the list is walked; `of` keeps its `!` where a
  caller holds a machine it opened itself.
- A test that opens a second machine while the boards change, red against today's `of`.

## Acceptance

- A change of the planning boards while a machine opens raises nothing and leaves attention as it was for the
  machines that answer; seen red first against today's lookup.

## How it was built

- `Attention` reads each machine through `Machines.watching`, which answers null for one listed and not watched yet,
  and takes such a machine as not answering; its listeners follow only the fleets that are watched. Notifications,
  where the person was and the planning read the machines the same way. `Machines.of` keeps its use for a caller
  holding a machine; for one listed and not watched yet it hands the stand-in [F530](README.md#f530) added.
- Tests in `test/app/listed_not_watched_test.dart`: a host card saved before another machine opens without an error
  and the other machine still asks; a change of the planning boards while a machine is listed and not watched yet
  raises nothing and leaves what the answering machine asks as it was. Both seen red against a lookup that throws
  for a machine not watched (`Null check operator used on a null value`).
