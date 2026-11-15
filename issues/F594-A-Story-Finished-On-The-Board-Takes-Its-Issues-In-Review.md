# F594 — A Story Finished On The Board Takes Its Issues In Review

```json
{
  "$schema": "issue-1.json",
  "id": "F594",
  "title": "A Story Finished On The Board Takes Its Issues In Review",
  "state": "Review",
  "size": "XS",
  "priority": "Medium",
  "rank": 115,
  "blockedBy": [],
  "covers": "Story ST365: the window carries porelo-planner's screen at the commit where a story moved to Finished on the board carries its issues in the last done state along, the board shows them and the story in Finished, and the move's warning says their files are deleted."
}
```

**Why this size.** XS: a pin raise of `porelo_planning` with its lock, no contract change, and a scenario for what
the screen now shows.

**What must be true.** A person who moves a story whose issues stand in *Review* to *Finished* on the *Planning*
board is told before it that those issues go along and their files are deleted, and after one confirmation sees the
story and those issues in *Finished*.

## Plan

- porelo-planner `c8796c6` (PL139's screen part, porelo-planner's main since 15 November): a story moved to a closed
  state other than *Rejected* carries its issues in the state the last of the work rules leads to; the board expects
  exactly them as moved and shows the story in the target state with no state of its own; the warning for a closed
  target says the carried issues' files are deleted. No contract change of the window.
- Raise the `porelo_planning` ref in `pubspec.yaml` from `8beecc3` to `c8796c6` with `pubspec.lock`, keeping pubspec's
  `xterm` override; run `test/features` and `test/ui` whole.
- Guard (harm: a story finished on the board leaves its issues in *Review*, or the person is not told their files
  go): a scenario in `test/features/planning_moves.feature` beside *A closed destination accepts a drop*, moving the
  stand-in's ST10 (three issues in *Review*) to *Finished*; red on the old pin.
- ST365's other part, the first board after a planner start reading every repository at one moment (PL138), is the
  planner's alone: the window starts the planner and reads the board as before.

## Acceptance

- The new scenario red on the old pin and green on the new; `test/features` and `test/ui` green.

## Built

- **Pin:** `porelo_planning` at `ref: c8796c6e94ecbba46fef5f09825908a392777c27`, porelo-planner's main (url and
  `path: screen` unchanged, the `xterm` override kept); `pubspec.lock` resolves it from the forge, no override.
- **Scenario:** *A story finished takes its issues in Review along, said with their files deleted* in
  `test/features/planning_moves.feature`, with the steps *planning warns that {id} carries issues along whose files
  are deleted* and *planning issues {ids} of {story} are in {state}*: ST10 dragged to *Finished* warns with its
  issues along and the deleted files, and after *Confirm* the story and HO12, BT24 and BT25 stand in *Finished*.
- **Red on the old pin** (`8beecc3`, from GitHub, no override): `Found 0 widgets with key
  [<'planning-move-warning-item ISSUES_ALONG ST10'>]`: the old screen finishes the story with no issues along and asks
  nothing. Green on `c8796c6`; pubspec and lock restored from a copy.
- **Runs:** `dart analyze lib test` No issues found. `test/features` and `test/ui` whole on the new pin before the
  scenario: 2430 passed; `test/features/planning_moves_test.dart` with it: 24 passed.
- **Not checked:** the window itself was not run; the move against a live planner was not walked.

## To be checked

- The reading by another model (Claude Sonnet) found nothing red; no use of `leastAdvancedIssues` or the changed
  warning text in the window's own code. Left as yellows: on the old pin the scenario stops at the warning, so the
  issues left in *Review* are not seen red alone (the later step guards them); the step checks the screen's exact new
  sentence, so a rewording there breaks it; the CHANGELOG and this issue say *Review* where the screen takes the
  last work rule's done state, which is *Review* in the shipped workflow.
