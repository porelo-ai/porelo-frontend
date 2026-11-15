# F601 — A Read-Only Task Says Nothing Of A Gate

```json
{
  "$schema": "issue-1.json",
  "id": "F601",
  "title": "A Read-Only Task Says Nothing Of A Gate",
  "state": "Review",
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

## Built

- **Model:** `Task.readOnly` (`lib/src/client/models.dart`), read from the list's `readOnly`, true only for a JSON
  `true`, false where absent.
- **Tile:** `Tile.writesCode` (`lib/src/app/attention.dart`), false where the task is `readOnly` or its planned offer
  writes no code; `_WorkFacts` (`lib/src/ui/attention_view.dart`) leaves out *Commits at the gate* where it is false,
  and both build lines pass it to `BuildsSaid.onTheTile`.
- **Details:** the task pane (`lib/src/ui/panes.dart`) leaves out *At the gate* for a `readOnly` task, beyond the
  plan, as the same fact in another place.
- **Tests:** `test/ui/planned_task_line_test.dart`: *a task the machine lists as read only says nothing of a gate or a
  build*, *a planned stage handing back a result says nothing of a gate, read only said or not*, *work that may push
  says its gate as before*; `test/client/task_read_only_test.dart` for the reading. The stand-in's `wire` and
  `withHandIn` carry `readOnly`.
- **Red:** the read-only tile `Found 1 widget with text "No build yet"` on its row; the planned stage `Found 1 widget
  with key [<'tile-fact gate'>]`.
- **Runs:** `dart analyze lib test integration_test tool` No issues found. `planned_task_line_test.dart`: 8 passed;
  with `task_read_only_test`, `online_class_test`, `work_as_designed_test`, `work_page_faults_test`,
  `test/features/builds_test.dart`, `test/client/builds_test.dart`: 74 passed.
- **Box:** the build box's Maven `test` phase (format check, `dart analyze --fatal-infos`, `porelo_host`'s tests and the
  whole `flutter test` suite) at `5f5c3e7`: BUILD SUCCESS, 4634 passed, 37 skipped, 0 failed. The same at `aea0709`,
  with every issue of the branch: BUILD SUCCESS, 4640 passed, 37 skipped, 0 failed.
