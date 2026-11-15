# F606 — Start Work Shown As The Window's Wizard

```json
{
  "$schema": "issue-1.json",
  "id": "F606",
  "title": "Start Work Shown As The Window's Wizard",
  "state": "Implementing",
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

## To be checked

- PL156's, PL157's and PL158's built commits, cited here once handed over.
