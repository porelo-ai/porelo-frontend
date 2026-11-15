# F601 — A Read-Only Task Says Nothing Of A Gate

```json
{
  "$schema": "issue-1.json",
  "id": "F601",
  "title": "A Read-Only Task Says Nothing Of A Gate",
  "state": "Backlog",
  "size": "XS",
  "priority": "High",
  "rank": 121,
  "blockedBy": [],
  "covers": "A task the machine lists as read only, or a planned stage that writes no code, shows no Commits at the gate fact and no build line on its tile and row, as it has no gate and pushes nothing."
}
```

**Why this size.** XS: `Task` reads the list's `readOnly`, and the tile's facts and build line leave out what assumes
a push where it is true or the planned offer writes no code; tests of each case.

**What must be true.** A person looking at a task that only reads sees nothing that speaks of a gate or a build,
which such a task cannot have.

## Found

The operator's read-only runs of 15 November (PI68 *In analysis* and *Under estimation*, tasks `pi` and `pi-2` on a
host, both with a result file): the tile said *Commits at the gate: nothing is reviewed in an online project*.

## Plan

- **Today**, read in the code: `_WorkFacts` (`lib/src/ui/attention_view.dart`) always shows the fact *Commits at the
  gate*, from `Task.atTheGate` (`lib/src/client/models.dart`) for an online task. `Task` does not read the list's
  `readOnly`, which porelo's contract gives (`15-task.varlink`: *made with Start's readOnly or allRepositories … no
  gate and nothing it can push*; an older daemon omits it, read as false). The build line already stays away for a
  planned stage that writes no code (`BuildsSaid.onTheTile` with `PlannedOffer.writesCode`).
- **Steps.**
  - `Task.readOnly`, read from the list, false where absent.
  - The *Commits at the gate* fact left out where `readOnly`, or where the tile's planned offer writes no code.
  - `BuildsSaid.onTheTile` takes `writesCode: false` for a `readOnly` task too, so no build line assumes a push.
- **Red first:** a widget test of a tile for a listed task with `readOnly: true`, red today on the gate fact.

## Acceptance

- A `readOnly` task's tile shows no *Commits at the gate* and no build line. Seen to fail: today's tile.
- A planned stage with a result file and no `readOnly` from an older daemon shows neither.
- A task that may push shows both as today.
