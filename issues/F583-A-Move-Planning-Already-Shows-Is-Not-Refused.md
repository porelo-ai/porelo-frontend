# F583 — A Move Planning Already Shows Is Not Refused

```json
{
  "$schema": "issue-1.json",
  "id": "F583",
  "title": "A Move Planning Already Shows Is Not Refused",
  "state": "Review",
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

- porelo-planner `1868e5e` (PL137, pushed to its main in this round after `ebe3ef1`): a move whose save meets a
  changed planning that already shows the item in its target state counts as done, with the notice "Planning already
  shows <id> in <state>."; a changed planning that shows it in a third state keeps the red "Planning changed while
  <id> was moved; nothing was moved. Move it again." No contract change.
- Raise the `porelo_planning` ref in `pubspec.yaml` to `1868e5e` itself (PL137, porelo-planner's main once pushed this
  round), keeping pubspec's `xterm` override, with `pubspec.lock`; run `test/features` and `test/ui` whole.
- Guard (harm: a move that landed reads as refused, and the person moves it again): a planning scenario beside *A
  stale revision moves nothing and the next move clears its feedback* (`test/features/planning_moves.feature`) where
  the changed planning already shows the story in the target state, saying the notice and no move error; red on the
  old pin. The two scenarios that see the red refusal keep it where the third state applies, or are set to it.

## Acceptance

- The new scenario red on the old pin and green on the new; `test/features` and `test/ui` green.

## Built

- **Pin:** `porelo_planning` at `ref: 1868e5e3fdf95e4844c8b24651c99059e606d8a4`, porelo-planner's main (url and
  `path: screen` unchanged, the `xterm` override kept); `pubspec.lock` resolves it from the forge, no override. The
  red and green below were first seen through a temporary local override while the commit was not yet on the forge.
- **Scenario:** *A save that meets planning already showing the target state counts as done* in
  `test/features/planning_moves.feature`, with the step *the planning save meets a changed planning showing story
  {id} in {state}*: the preview answers on the board the person saw, the save is refused `StaleRevision`, and the board
  read again shows ST293 and its issues in Review. It says "Planning already shows ST293 in Review.", no move error,
  nothing saving, the story in Review.
- **Red on the old pin** (`8dce2dc`, from GitHub, no override): no `planning-move-notice` at all (by its code the old
  screen says the red "Planning changed: ST293 now stands in Review; it was not moved."). Green on `1868e5e`.
- **The two scenarios with the red refusal** (*A stale revision moves nothing…* here and its issue twin in
  `planning_story.feature`) are refused at the preview, where the stale board shows the item in its source state;
  1868e5e changes only the save's branch, so they keep their words unchanged.
- **Runs:** `dart analyze` No issues found. `test/features` 981 passed, `test/ui` 1411 passed,
  both whole, on the pin from the forge.
- **Not checked:** the rest of the suite beyond `test/features` and `test/ui`; the window itself was not run.
- **Reading** by another model (Claude Sonnet): nothing red. Left as yellows, all in porelo-planner's screen and not
  reached by the window's tests: the new branch for an issue's move, for a `PreviewChanged` refusal, and the third
  state after a refusal at the save.
