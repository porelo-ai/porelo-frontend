# F583 — A Move Planning Already Shows Is Not Refused

```json
{
  "$schema": "issue-1.json",
  "id": "F583",
  "title": "A Move Planning Already Shows Is Not Refused",
  "state": "Implementing",
  "size": "XS",
  "priority": "Medium",
  "rank": 62,
  "blockedBy": [],
  "covers": "Story ST362: the window carries porelo-planner's screen at the commit where a move whose save meets a changed planning that already shows it in its target state is said as done, quietly, not refused in red."
}
```

**Why this size.** A pin raise of `porelo_planning` with its lock, no contract change, and a guard for what the
screen now shows.

**What must be true.** A person who moves a story or an issue to a state that planning meanwhile shows it in reads
that it is already there, not that nothing was moved.

## Plan

- porelo-planner `1868e5e` (PL137, on its main at `ebe3ef1`): a move whose save meets a changed planning that already
  shows the item in its target state counts as done, with the notice "Planning already shows <id> in <state>.";
  a changed planning that shows it in a third state keeps the red "Planning changed while <id> was moved; nothing was
  moved. Move it again." No contract change.
- Raise the `porelo_planning` ref in `pubspec.yaml` to porelo-planner's main as it then stands (at least `1868e5e`),
  keeping pubspec's `xterm` override, with `pubspec.lock`; run `test/features` and `test/ui` whole.
- Guard (harm: a move that landed reads as refused, and the person moves it again): a planning scenario beside *A
  stale revision moves nothing and the next move clears its feedback* (`test/features/planning_moves.feature`) where
  the changed planning already shows the story in the target state, saying the notice and no move error; red on the
  old pin. The two scenarios that see the red refusal keep it where the third state applies, or are set to it.

## Acceptance

- The new scenario red on the old pin and green on the new; `test/features` and `test/ui` green.
