# F530 — Every Reader Of A Machine Waits Until It Is Watched

```json
{
  "$schema": "issue-1.json",
  "id": "F530",
  "title": "Every Reader Of A Machine Waits Until It Is Watched",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 102,
  "blockedBy": [],
  "covers": "No page, listener or caller of the window reads the fleet of a machine that is listed and not watched yet: during a reconnect or a host's replacement every one of them draws that machine as not answering, without an error."
}
```

**Why this size.** M: about twenty places in several pages and listeners, each with a widget test of the window in
which a machine is listed and not watched yet.

**What must be true.** While a machine is listed and its fleet is not watched yet - at the start, during a reconnect, or
while a host's card is replaced - no page, listener or call reads that fleet: each draws or answers that machine as not
answering yet, and nothing throws.

## Found

The reading of the fix that made attention, notifications and the planning callers wait for a watched machine
(`Machines.watching`) left these places on `Machines.of` / `fleetOf`, which throw for such a machine:

- Widget builds that walk the list or take a fleet: `attention_view.dart` (`fleetOf` on rows already resolved for that
  machine), the `all.contains` guards in `machines_page.dart`, `projects_page.dart` and `machine_details_page.dart`,
  `work_page.dart`, and many places in `shell.dart`. The reconnect and replacement windows span awaits, so frames run
  inside them.
- The shell's machine listener: `_leaveTheSignInsOfForgottenMachines`.
- `planner.dart` (`machines.fleet` in `chosenProject`) and `organization_connections.dart` (`central`, whose catch
  leaves a TypeError out).
- In `Machines` itself: `_mark` has no way back, so a failed `dropAndUnpublish` leaves a machine listed and never
  watched; the ways back in `_adopt` and `_add` open again without telling the listeners.
- Tests: the reconnect test asserts only that nothing threw, and `plannerProjectOf` passes with a refusal because its
  fixture has no upstream.

## Plan

- Every place above moves to `watching`, drawing or answering the machine as not answering yet.
- A widget test per page that pumps frames while a machine is listed and not watched, red against today's `of`.
- `_mark` gets its way back; `_adopt` and `_add` notify after re-opening.

## Acceptance

- Each page and listener above, pumped while a machine is listed and not watched, raises nothing and shows that
  machine as not answering; each seen red first.

## Decided

2026-11-13: the machine's stand-in, chosen over moving every reader to `watching`. Reading the code found about 250
readers, not twenty: `shell.dart` alone reads `Machines.of` 105 times and its `_fleet` 123 times, which is L or more.
`Machines` instead hands a stand-in while a machine is listed and not watched; moving the readers themselves to
`watching` is built apart, every reader asking whether its machine is watched.

## How it was built

- `Machines.of`, and `fleet` through it, hand a machine listed and not watched yet a stand-in fleet
  (`FleetModel.notWatchedYet`): not answering, never trying by itself, its backend refusing every call as a lost
  connection with the words that the machine is not answering yet. `watching` stays null for it; the stand-in goes
  once the machine is opened, forgotten, or no longer in an adopted list.
- `PoreloBackend` refuses a call before its opening as a lost connection where its backend names why it cannot be
  reached, as `Backend` says of every call.
- `_mark` opens the machine again as it was when its forward does not come down, and tells the listeners; the ways back
  in `_adopt` and `_add` tell them too.
- `organization_connections.dart`'s `central` asks only a watched machine.
- What waits on a machine past a reconnect follows the fleet watching it now (`Machines.follow`): the check once a
  started daemon answers, and the first check once a new machine is shown. A machine's page opened while it is not
  watched yet is read once it is.
- Tests: `test/ui/listed_not_watched_pages_test.dart` draws Work, Needs you, My machines, My projects and the Machine
  page while a machine, and the selected one, reconnects (red: the rail and `_fleet` threw a null check);
  `test/app/listed_not_watched_test.dart` adds the stand-in, the way back, both notifications, `follow` after a
  reconnect and the stand-in's disposal, and the page test a machine page read once the machine is watched, each seen
  red.
