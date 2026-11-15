# F599 — Needs You Says A Planner's Reason In Words Only

```json
{
  "$schema": "issue-1.json",
  "id": "F599",
  "title": "Needs You Says A Planner's Reason In Words Only",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 119,
  "blockedBy": [],
  "covers": "A planning row under Needs you says why it needs the person in a sentence only, never the planner's code in capitals (SAVE_REFUSED, STOPPED) as a line of its own; the window carries porelo-planner's screen at the commit that drops it, the code kept for the log."
}
```

**Why this size.** XS: the line is drawn by porelo-planner's screen; the window raises the pin with its lock and holds
the row's words in a scenario. The window's log keeps the code, as today.

**What must be true.** A person reading a planning row under *Needs you* reads a sentence of why, such as *saving its
findings was refused* or *its work was stopped*, and no code meant for programs.

## Found

The operator's live test (15 November, after stopping the ST366 run): the planning row under *Needs you* showed
*SAVE_REFUSED*, later *STOPPED*, as a line of its own above the sentence that says it.

## Plan

- **Today**, read in the code: porelo-planner's `StoryWorkAttentionView` (pinned `c8796c6`,
  `screen/lib/src/ui/story_work_attention.dart`) draws `Text(planningShown(row.reason))` for every reason
  `planReasonNeedsAttention` takes, and then, for an issue's row, `_taskEnd` with `planningReasonWords(reason)`. So an
  issue's row says the code and the sentence; a story's row with a reason and no issue says the code alone. The other
  lines of the row are words already: the ended task's `why` and answer, its time, the story's id and title, a
  finding's severity and text. The window draws none of these (`lib/src/ui/attention_view.dart` embeds the view); its
  own log line (`Attention._wordsOf`) keeps the code, which stays.
- **Needs of Agent Planner** (an issue of porelo-planner): the reason line says `planningReasonWords(reason)` where no
  `_taskEnd` says it, and nothing where one does; the code, if kept, only in a tooltip. To be checked by Agent
  Planner: whether a finding's severity or an ended task's `why` can be a code in capitals too.
- **Steps** (window), once that commit is pinned: raise the pin of `porelo_planning` with its lock, the `xterm`
  override kept; a scenario in `test/features` with a stand-in planner row for an issue whose reason is
  `SAVE_REFUSED` and one for a story whose reason is `STOPPED`, asserting the sentence and no code.
- **Red first:** that scenario on the old pin: the code stands as text.

## Acceptance

- An issue's planning row with `SAVE_REFUSED` says its sentence once and no `SAVE_REFUSED`. Seen to fail: today's
  row.
- A story's row with `STOPPED` says *its work was stopped* in words, and no `STOPPED`.
- The window's log still names the code.

## Built

- **Pin:** `porelo_planning` at `ref: c77f5a76e1860da9366ae23f7e0ae05803ddc276`, porelo-planner's main with the reason
  in words (url and `path: screen` unchanged, the `xterm` override kept); `pubspec.lock` resolves it from the forge,
  no override.
- **Scenarios** in `test/features/planning_board.feature`: *A planning row whose findings were not saved says so in
  words, never its code* (`SAVE_REFUSED`) and *A stopped planning row says so in words, never its code*
  (`STOPPED`), with the steps *the machine reports a run of {story} whose issue needs you for {reason}* (the stopped
  run's step now goes through it) and *what needs you says {reason} in words only*, which asks the screen's own
  `planningReasonWords` once and no line with the code.
- **A story's row:** the window makes no story row that carries a reason: `PlanningBoards.storyAttention` gives one
  only to an issue's row, and a story's own row only for an ended task. So `STOPPED` is held on the issue row of a
  stopped run; a story row with a reason is porelo-planner's own test.
- **Red on the old pin** (`c8796c6`, from GitHub, no override): `Expected: no matching candidates Actual:
  _TextWidgetFinder:<Found 1 widget with text "SAVE_REFUSED"`, and the same for `"STOPPED"`. Green on `c77f5a7`.
- **The log:** the window's own log line of a planning row (`Attention._wordsOf`) still names the reason's code;
  unchanged.
- **Runs:** `dart analyze lib test integration_test tool` No issues found. On the new pin: `test/ui` 1450
  passed; `test/features` 986 passed and 1 failed: *Review anyway sends the current reading decision* held the
  findings' severity as the old screen wrote it, *BLOCKING:* and *NOTE:*, which the new screen says *Blocking:* and
  *Note:*; its two expected lines (`test/features/support/story_work.dart`) take the new words, and
  `test/features/story_work_test.dart` reran 27 passed. `test/app` 1707 passed, 5 skipped; `test/client` 365
  passed, 25 skipped (the skipped ones need a running porelod, Windows sockets or `PORELO_PUBLISHED_KEY=1`).
- **Not checked:** the window itself was not run; no live planner row was read.
