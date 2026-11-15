# F599 — Needs You Says A Planner's Reason In Words Only

```json
{
  "$schema": "issue-1.json",
  "id": "F599",
  "title": "Needs You Says A Planner's Reason In Words Only",
  "state": "Backlog",
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

## To be checked

- The porelo-planner issue and its commit, cited here once filed.
