# F625 — The Window's Token Hand-Ons Moved Out Of Its Dialogs Into A Service

```json
{
  "$schema": "issue-1.json",
  "id": "F625",
  "title": "The Window's Token Hand-Ons Moved Out Of Its Dialogs Into A Service",
  "state": "Analyzed",
  "size": "M",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "Handing a forge token and a host token on runs in a service tested without widgets, the dialogs only asking; the planned tasks' start and report services move from the UI folder to the app's"
}
```

**Why this size.** M: two hand-on flows of about 60 lines each, their rules and refusals moved into one service with
unit tests, the dialogs kept, and two widget-free classes moved between folders; no contract changes.

**What must be true.** A widget's handler only checks what was given, calls one service method and shows its answer;
the dialogs it needs are asked through callbacks the service is given. The use case (what is kept, in which order,
under which rule, what is told the machine or the vault, and what is undone when a step fails) lives in a service under
`lib/src/app/` that knows no `BuildContext`, `setState` or widget, and is tested without them. This is the first of four
parts; the others are [F626](README.md#f626), [F627](README.md#f627) and [F628](README.md#f628).

## Plan

Read in today's code.

- `_handForgeTokenOn` (`lib/src/ui/organization_access_dialogs.dart:264`, behind `prepareOrganizationForge` and
  `prepareForgeForPlanning`) opens the machine, looks at its vault, applies the declaration rules and declares, with
  dialogs between; `_giveHostTokenNow` (`lib/src/ui/shell.dart:6814`) runs a hand-over step that goes on after its
  dialog closes. Both become one service in `lib/src/app/token_hand_on.dart`; the dialogs stay and are passed in as
  callbacks.
- `WindowTaskStarts` (`lib/src/ui/planning_embedding.dart`) and `WindowTaskReports` (`lib/src/ui/planning_reports.dart`)
  use no widget and are tested by plain `test()`; they move to `lib/src/app/` unchanged, `WindowTaskStarts` then
  reaching `prepareForgeForPlanning` through the new service.
- Steps: the service's unit tests first, over `FakeBackend` and recording callbacks, each holding a path the widget
  tests hold today (a malformed origin refused before the vault is touched, a refused declaration, the page closed
  meanwhile), seen red with the logic not yet moved; then the dialogs reduced to the asking, their widget tests passing
  unchanged. Harm guarded: a token declared after the person left, or a hand-on half done.

## Acceptance

- `organization_access_dialogs_test.dart`, `planning_forge_access_test.dart` and the token steps of `test/features`
  pass unchanged; the new unit tests were seen red first.
