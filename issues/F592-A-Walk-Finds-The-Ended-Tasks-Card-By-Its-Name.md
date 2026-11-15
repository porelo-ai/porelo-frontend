# F592 — A Walk Finds The Ended Task's Card By Its Name

```json
{
  "$schema": "issue-1.json",
  "id": "F592",
  "title": "A Walk Finds The Ended Task's Card By Its Name",
  "state": "Backlog",
  "size": "XS",
  "priority": "Medium",
  "rank": 113,
  "blockedBy": [],
  "covers": "The walk of the planner moving work on reads the card of a task its provider refused under the key the work page gives it, so its last step can pass."
}
```

**Why this size.** XS: two walk steps look a card up under the wrong name; no code of the window changes.

**What must be true.** The walk's last read, that a task refused by its provider keeps its card with a warning and a
*Needs you* entry, passes where the card stands, and fails only where it does not.

## Why

In the walk of 15 November on walk1 the step *13 [failed-card]* waited two minutes for the card and failed while the
card stood on the work page, saying *Waits on you: how it ended has not been seen.*, and its *Needs you* entry was
found. The step looks the tile up by the task's container name (`porelo-e2e-ended_ended`, from `containerOf`), but
the work page keys a tile `tile <machine> <task name>` and its fold `tile-fold <task name>` (here `ended`), as it
has since before ST367. The step never ran before that walk.

## Plan

- `integration_test/step/the_failed_tasks_card_stays_with_a_warning_and_a_needsyou_entry_to_its_result.dart`: find
  the tile by the refused task's name (the `ended` task of its project), not by `refusedTask`; keep the check that its
  `tile-state ended` chip stands inside it.
- `integration_test/step/its_log_shows_what_its_agent_wrote.dart`: the same for its `tile-fold` and `tile` keys.
- A name for the task beside `refusedTask` in
  `integration_test/step/work_on_the_test_machine_was_started_with_a_key_its_provider_refuses.dart`, so both steps
  share it.
- **Red first:** neither step runs in the Build. The step is seen red as it is (the walk of 15 November, report
  `story-st367-1`) and green after the change in a resume of a kept run from that step, on a walk VM.

## Acceptance

- The walk's step 13 reads the card of the refused task and passes where the card stands with its warning and
  *Needs you* entry. Seen to fail: the walk of 15 November, on the container name.
- `its_log_shows_what_its_agent_wrote` finds the same tile. Seen to fail: run against the old key.
