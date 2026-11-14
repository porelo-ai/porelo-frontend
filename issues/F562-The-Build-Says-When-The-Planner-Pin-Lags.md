# F562 — The Build Says When The Planner Pin Lags

```json
{
  "$schema": "issue-1.json",
  "id": "F562",
  "title": "The Build Says When The Planner Pin Lags",
  "state": "Review",
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

## Built

`tool/planner_pin.sh` reads the `porelo_planning` url and ref from `pubspec.yaml` and the url's main with
`git ls-remote`, and writes a `::warning` naming both when they differ. A main it cannot read is a warning that the pin
is unchecked. It always exits 0. The Linux job runs it as *Say whether the planning screen's pin is porelo-planner's
main*, after the other checks. `test/tool/planner_pin_test.dart` holds it against a stand-in `git`: a pin behind
main warns, a pin at main says nothing, and an unreadable main warns. Each was seen red on a script broken for it.
Run against the real forge on this head, it warns: the pin is `6bdad25`, and porelo-planner's main is already at
`fa6bbe3` (its README change for `PlanningTaskEnded`).
