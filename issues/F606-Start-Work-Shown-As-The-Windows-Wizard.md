# F606 — Start Work Shown As The Window's Wizard

```json
{
  "$schema": "issue-1.json",
  "id": "F606",
  "title": "Start Work Shown As The Window's Wizard",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 126,
  "blockedBy": [],
  "covers": "Start work on the Planning board runs as the window's own wizard, through porelo-planner's PlanningWizards hook: a step per question with room to read each field, a review where every step's answers can be changed, ready agents, and the models and efforts porelo lists per agent."
}
```

**Why this size.** S, as the operator set it: the window's `Wizard` exists and the screen splits its own panels
(PL157). The window's part is the `PlanningWizards.show` hook onto `Wizard` (`lib/src/ui/wizard.dart`) with its
handle's `goBackTo`, a *Change* beside each step in every wizard's review, and the agent list's members PL157 asks
(readiness, [F605](README.md#f605); models and efforts as porelo lists them); the pin raised to PL157's screen.

**What must be true.** A person starting work from the board goes through the same kind of wizard as when adding a
machine or a project: one question at a time, fields that read, and a last step listing every answer with *Change*
beside each, before *Start*; while the start runs the wizard may close, its operation carrying it on.

## Found

The operator asked in ST369's live test (15 November) for *Start work* as a wizard like the window's own, with a last
step where every part is checked and can be changed, and found the lower fields too small to read (the Comment
field's *Optional* over the *Most reading rounds* label, porelo-planner's `story_work_dialog.dart`).

## Plan

- **Scope**, as the operator set it (Coordinator, room 2026-11-15 16:06Z): the hook, *Change* per step and the agent
  list's members; the machine step stays the screen's own (`StoryWork.changeMachine`), with nothing new from the
  window.
- **Contract**, as Agent Planner named it (room, 2026-11-15 15:52Z; PL156's design in porelo-planner `604ee70`, the
  screen's build PL157): `PlanningWizards.show(context, title:, steps:, action:)`, a hook the window passes into the
  boards beside `startTask` and `agents`. A `PlanningWizardStep` has `title`, `words`, `panel` (a builder of its own
  fields only), `check` (null or why it cannot go on), `beforeNext` (async, while the step shows) and `summary` (its
  review lines in words, never a code); a `PlanningWizardActionStep` runs the start after the review with *running*,
  *waiting*, *done* or *refused*, and `goesOnWhenLeft`. `show` answers a handle with `goBackTo(step)`. Without the
  window the screen shows the same steps in a plain frame of its own.
- **Steps.**
  - The hook: maps the screen's steps onto `WizardStep` and `WizardActionStep`, its handle's `goBackTo` onto the
    wizard's `goBackTo`, and shows it as the window's other wizards are shown.
  - The review: a *Change* beside each step's title in `Wizard`'s review, going to that step and back to the review
    with Next; every wizard of the window gains it.
  - The agents (`MachinePlanningAgents`, `lib/src/ui/planning_embedding.dart`), for the machine the screen's *Where*
    step chose: the readiness member, [F605](README.md#f605) (PL155), and per agent the models (id, label) and
    effort levels PL157's `PlanningAgents` asks, as porelo lists them.
  - Models: the operator's answer to PL156 (Agent Planner, room 2026-11-15 16:02Z): a person may start an agent the
    rule offers with any model. The model choice is a list of the chosen agent's models on that machine, the rule's
    marked proposed, filling a text field that can also be typed by hand; a model the agent or provider refuses fails
    at the start with its reason, said in the start's operation. porelo-planner's side is PL158: it checks only that
    the agent is offered, for the main task and the sub-agents.
  - Efforts: from Agent Core's B795 (handed over locally as porelo `5328c5df4`, branch `core-b795`): no effort passes
    nothing; a proposed effort is marked only where the agent lists it.
  - Raise the pin of `porelo_planning` to PL157's screen with its lock, the `xterm` override kept.
- **Red first:** a scenario through *Start work* reaching the review with *Change* on each step, red on the old pin
  (a dialog with no steps); a test of the window's server setup review with *Change*, red today.

## Acceptance

- *Start work* runs as the window's wizard, one step at a time, ending in a review with *Change* beside every step.
  Seen to fail: today's dialog.
- An agent not signed in on that machine is named so; the model list is that agent's models on that machine, the
  rule's marked proposed, and a model typed by hand is started with; efforts are those B795 lists.
- The wizard may close once the start runs on; its operation stands in front ([F597](README.md#f597)).
- The window's other wizards show *Change* in their review too.

## Built

- **The hook:** `WindowPlanningWizards` (`lib/src/ui/planning_wizards.dart`) implements the screen's
  `PlanningWizards.show(context, title:, steps:, changes:, startLabel:, start:, canCancel:)` as built in PL157, which
  is simpler than the Plan's design: no action steps and no handle. Each `PlanningWizardStep` (`title`, `words`,
  `panel`, `check`, `summary`, `shown`) becomes a `WizardStep`. The review's button runs `start` and closes when it
  answers true. Its words are read on each redraw (`Wizard.actionWords`), so it says the screen's live
  *Start <state>*. *Leave* is offered while `canCancel` says so.
  `shell.dart` hands `wizards: const WindowPlanningWizards()` to `PlanningBoards` and `PlanningScreen`, so both
  opening paths (a card's menu and a *Needs you* row) show it.
- **The wizard:** `Wizard` (`lib/src/ui/wizard.dart`) gains `WizardStep.shown` (a step with nothing to choose is
  passed over, its lines kept on the review), `start` and `canLeave`. The review has *Change* beside each step
  (`wizard-change-<i>`), and *Next* after a *Change* returns to the review. Every wizard of the window has it.
- **Agents, models, efforts:** see [F605](README.md#f605)'s *Built*.
- **After the reading** (Claude Sonnet): a start that throws now says *The start failed: <why>* on the review and
  may be pressed again; *Leave* is not offered while the review's start runs, so its answer cannot be lost behind
  a confirmation. Test *a start that fails says so and may be pressed again, and Leave waits while it runs*, red
  first (nothing said).
- **Planner:** porelo-planner `6ac9894` (PL157 on PL146), with the fix `dc08f22` for a duplicate effort key, which
  this window's scenario found (two choices on one agent in one step). Built through an uncommitted local override
  until it was pushed; the pin is now porelo-planner's main `cb9d13a` (PL146, PL157, PL149 and the fix), raised in
  the first commit of this work with its lock, the `xterm` override kept, no override else.
- **Build box** at `e6ecbbed`, against the pin alone: Maven `test` BUILD SUCCESS, dart format and
  `dart analyze --fatal-infos` clean, `flutter test` 4635 passed, 37 skipped, 0 failed. Its first run found
  *A working state requests a start and moves nothing* still looking for the dialog's key; fixed in `e6ecbbed`.
  Because PL146 lies under PL157, [F597](README.md#f597) is built in the same commit.
- **Tests:**
  - `test/ui/wizard_test.dart` (14), with *the review offers Change beside each step, and Next goes back to the
    review* and *an answer emptied through Change holds Next on its step*. Seen red before *Change*
    existed.
  - `test/ui/planning_wizards_test.dart`: the screen's steps in the window's wizard and the live start words.
    Seen red by breaking `start`'s answer.
  - `test/features/story_work.feature` walks the wizard (`workSee` in `test/features/support/story_work.dart` goes
    Next or Back to the step that holds a field, in the window's wizard and in the screen's plain frame of a narrow
    host).
  - A single mode is no step of its own and is said on the review.
  - Another agent asks for its own model: the agent's models are its own (PL157).
  - Runs: `story_work_test.dart` and `planning_placeholder_test.dart`, 35 passed three times. The other planning and
    wizard suites (`planning_*`, `wizard_test`, `window_task_starts_test`): passed.
- **Not checked:** the window itself was not run.

## To be checked

- After a *Change*, the review runs each step's synchronous check again, not a later step's `beforeNext` (a server
  setup's connection check): a changed host is checked again only when its own step is walked. `goBackTo` exists
  for this; not built here.
- *Sub-agent Change … requires a difference*: in the wizard the comment lies on a later step that an unchanged
  *Change* cannot reach, so the old *comment, then still disabled* proof has no place; *start disabled* holds on the
  *Who* step, whose own check names the missing difference.

- PL156's, PL157's and PL158's built commits, cited here once handed over.
- `planning_placeholder_test.dart`, *a window that reaches its planner shows the planning screen*, failed twice
  in runs during the build (no `PlanningScreen` found) and passed in every run since. Watch it in the suite.
