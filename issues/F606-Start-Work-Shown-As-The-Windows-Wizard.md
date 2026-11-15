# F606 — Start Work Shown As The Window's Wizard

```json
{
  "$schema": "issue-1.json",
  "id": "F606",
  "title": "Start Work Shown As The Window's Wizard",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 126,
  "blockedBy": [],
  "covers": "Start work on the Planning board runs as the window's own wizard, through porelo-planner's PlanningWizards hook: a step per question with room to read each field, a review where every step's answers can be changed, the machine the task goes to named with why another cannot be used, ready agents, and models and efforts per agent once porelo lists them."
}
```

**Why this size.** M: a hook mapping the screen's step types onto `Wizard` (`lib/src/ui/wizard.dart`) with its
handle's `goBackTo`, a *Change* beside each step in every wizard's review, the machine step's answers, and the pin
raised to PL157's screen; scenarios through the whole wizard and the window's other wizards' reviews.

**What must be true.** A person starting work from the board goes through the same kind of wizard as when adding a
machine or a project: one question at a time, fields that read, and a last step listing every answer with *Change*
beside each, before *Start*; while the start runs the wizard may close, its operation carrying it on.

## Found

The operator asked in ST369's live test (15 November) for *Start work* as a wizard like the window's own, with a last
step where every part is checked and can be changed, and found the lower fields too small to read (the Comment
field's *Optional* over the *Most reading rounds* label, porelo-planner's `story_work_dialog.dart`).

## Plan

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
  - The machine step's answers: which machine the task goes to (`machineFor` and `planningMachineOf` today, kept one
    with [F603](README.md#f603)), and why one cannot be used (not watched, not answering, not carrying the project), in
    the window's words.
  - The agents: the readiness member, [F605](README.md#f605) (PL155), for the machine the step chose.
  - Models and efforts per agent, machine and the task's provider: the window passes what porelo lists, once its
    definitions carry them (Agent Smith's answer); until then the step keeps what the agents call answers today.
  - Raise the pin of `porelo_planning` to PL157's screen with its lock, the `xterm` override kept.
- **Red first:** a scenario through *Start work* reaching the review with *Change* on each step, red on the old pin
  (a dialog with no steps); a test of the window's server setup review with *Change*, red today.

## Acceptance

- *Start work* runs as the window's wizard, one step at a time, ending in a review with *Change* beside every step.
  Seen to fail: today's dialog.
- The machine step names the machine the task goes to, and why another cannot be used.
- An agent not signed in on that machine is named so; models and efforts are those porelo lists for it.
- The wizard may close once the start runs on; its operation stands in front ([F597](README.md#f597)).
- The window's other wizards show *Change* in their review too.

## To be checked

- PL156's and PL157's pushed commits, cited here once pushed.
- Agent Smith's answer on which models and efforts porelo's definitions list per agent and provider.
