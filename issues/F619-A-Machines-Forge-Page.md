# F619 — A Machine's Forge Page

```json
{
  "$schema": "issue-1.json",
  "id": "F619",
  "title": "A Machine's Forge Page",
  "state": "Analyzed",
  "size": "M",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "Under each machine a Forge page: its state, Open in browser, Uninstall…, tiles and lists of what waits for central, reviews waiting, builds and gate refusals today, and the central forge it brings work to"
}
```

**Why this size.** M: a new page over several sources the window already reads per project (repositories ahead of
central, pull requests, builds), summed per machine, plus one source the daemon does not give yet (gate refusals).

**What must be true.** On a machine's Forge page the person sees how the forge stands, opens it in the browser, and
sees what waits for them: the repositories to bring to central, the pull requests waiting for their review, today's
builds and today's gate refusals, each with what to do next. The page names the central forge the work goes to.

## Plan

- New `lib/src/ui/forge_part_page.dart`, routed from `MachineSection.forge`. Head: state, *Open in browser*
  (`openHostForge` on a host; this computer's own forge from its local address), *Uninstall…* ([F621](README.md#f621)).
  Not installed: what installing it brings and *Install…* ([F621](README.md#f621)), nothing else.
- Tiles and lists, each read from what the window has today, summed over the machine's projects:
  - to bring to central: `Repository.central`, `ahead`, `aheadMeasured` from `Projects`; each row offers
    *Bring to central…* (`PushToCentral`, as the project page does) or *Take central first…* where central moved on;
  - waiting for your review: `PullRequests` / `WatchPullRequests` (as `app/host_pull_requests.dart` gathers them for
    *Needs you*); a row opens the pull request in the browser;
  - builds today: from each task's `builds` in `List`/`Watch`, counted from local midnight;
  - gate refusals today: no daemon call gives them (`Pending` lists only what waits) — a contract gap, written into
    `doc/Contract-Gaps.md` and asked of the daemon's owner; until it stands the tile says it cannot be read, never 0.
- The page names its central forge (the project's `central`); the tree's count ([F618](README.md#f618)) is the
  sum of what waits for central and for review.
- The lists move here from the machine page ([F622](README.md#f622)) and the project pages keep theirs.
- Tests, unit level first, red first: the per-machine summary over `FakeBackend` projects (ahead, unmeasured, behind,
  none), pull requests refused or missing a token, and the unknown gate count (harm: work reads as at central while
  it is not, or a refusal reads as none). Widget: the not-installed page offers only *Install…*.

## Open questions

- Builds today and gate refusals today: are they the forge's (all builds and refusals the machine's forge saw) or
  only the person's own? The design says "today"; the person's own work is what the window can read now.

## To be checked

- Which daemon call can give gate refusals since local midnight, with the daemon's owner.
- How this computer's own forge is addressed once installed (port and address), from the install contract of
  [F621](README.md#f621).
