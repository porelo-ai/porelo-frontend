# F562 — The Build Says When The Planner Pin Lags

```json
{
  "$schema": "issue-1.json",
  "id": "F562",
  "title": "The Build Says When The Planner Pin Lags",
  "state": "Backlog",
  "size": "XS",
  "priority": "Highest",
  "rank": 10,
  "blockedBy": [],
  "covers": "Story ST361: every build of this repository warns when the planning screen it pins is not porelo-planner's main, so a planner change does not wait unseen until a live test finds it."
}
```

**Why this size.** One step in the build, reading one ref from the network and comparing it with `pubspec.yaml`.

**What must be true.** A planner change the window does not carry yet shows on the next build, where somebody reads it.

## Plan

- A build step reads porelo-planner's `main` with `git ls-remote` and the `porelo_planning` ref in `pubspec.yaml`, and
  writes a `::warning` naming both when they differ. It fails nothing: a pin may stand behind on purpose for a day.
- The rule beside it holds already: a porelo-planner push that changes `screen/` names its commit, and the next push
  here raises the pin with a guard for what the change shows.
- The next pin move takes porelo-planner's main as it then stands (its README change for `PlanningTaskEnded` included,
  once that is on main).

## Acceptance

- The step warns on a pin behind main and says nothing on a pin at main, both seen in a run; check-actions green.
