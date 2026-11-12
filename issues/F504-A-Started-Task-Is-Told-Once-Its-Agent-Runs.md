# F504 — A Started Task Is Told Once Its Agent Runs

```json
{
  "$schema": "issue-1.json",
  "id": "F504",
  "title": "A Started Task Is Told Once Its Agent Runs",
  "state": "Backlog",
  "size": "S",
  "priority": "Highest",
  "rank": 3,
  "blockedBy": [],
  "covers": "A task the window starts for a planner's offer is told to the planner as started once Start says its agent runs, not when Start's final reply comes at the end of the agent's run, so the next offer of the story starts at once."
}
```

**Why this size.** S: the ordered and discussion starts stop reading Start once its agent runs and find the container
the start made, with their tests; the reports stay as they are.

**What must be true.** Start with a prompt gives its final reply only when the agent's run ends. While the run goes it
streams the step `AGENT` in state `STARTED` once the task stands and its agent runs. The window takes the start from
that step: it tells the planner the task started and starts the story's next offer right away. Today it waits for the
final reply, so a builder that works for half an hour holds every other task of the story and its STARTED for that long.

Found in [F492](README.md#f492)'s run 27, step 6: foo-1's agent worked and pushed, but the window waited on Start for
ten minutes, never told the planner and never started foo-2. The same cause explains run 26's late STARTED of foo-2.

## Plan

- `_startAnswered` (`lib/src/app/fleet_backend.dart`) answers on the step `AGENT`/`STARTED` for an ordered or
  discussion start, and stops reading Start; the run goes on in its container.
- The container is taken from the step where Start names it; until then from `List` after the step: the task of the
  project and repository that was not listed, or listed with another run, before the start.
- A red test first, in `test/app/start_ordered_test.dart`: a Start that streams the step and never gives its final
  reply answers with the container the list shows.

## Acceptance

- A builder whose agent runs on is reported as started within seconds of its agent's start, and the story's next offer
  is started without waiting for it.
- A start refused before its agent runs is still a refusal in the machine's words.
