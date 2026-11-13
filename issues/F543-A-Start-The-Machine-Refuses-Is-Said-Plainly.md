# F543 — A Start The Machine Refuses Is Said Plainly

```json
{
  "$schema": "issue-1.json",
  "id": "F543",
  "title": "A Start The Machine Refuses Is Said Plainly",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 110,
  "blockedBy": [],
  "covers": "A Start the planning place asked for, a discussion or a story's task, that the machine refuses or that starts no task is written to the window's log with the machine's words and said where the person sees it at once, never as a quiet line alone."
}
```

**Why this size.** S: one log line on each refusal path of the planned start, one plain notice, and a feature
scenario.

Found when "Discuss an idea… → Discuss" seemed to do nothing (2026-11-13). The planner gave the discussion's order, the
person chose in the Start dialog, and the window sent Start. The machine refused it with exit 78 and said
`porelo: no-homeserver: porelo names no homeserver under 'mail.transports.matrix…'` and
`porelo: nothing was created`.
- The window catches that refusal in `_start` (`lib/src/ui/planning_embedding.dart`) and throws it to the planning
  screen as `PlanningRefusal('StartRefused', …)` with the machine's words.
- The planning screen shows it as one plain line under the board's header, not in the error colour.
- Nothing is written to frontend.log, and no notice is shown. The person took the Discuss for lost, and the log could
  not say what had happened.

**What must be true.**
- Each refusal of a planned Start writes one line to the window's log, naming the machine, the project, what was to
  start (a discussion, or a story's task) and the machine's words, or the exit code when it printed none. Each such
  refusal is a Start that threw, a Varlink refusal, or an answer with no container.
- The same refusal is said where the person sees it at once, as a notice with the machine's words, beside the planning
  screen's own line.
- A planned Start the person declined in the dialog (`NotStarted`) is neither logged as a refusal nor noticed.

## Plan

- `lib/src/ui/planning_embedding.dart`: in `_start`, on each of the three refusal paths, after `_refused`,
  `windowLog.info('Planning: Start of <a discussion|the task …> for <project> on <machine> was refused: <words>')`,
  and hand the words to the window's notice. Put this in one helper, so that all three paths say it alike.
- Red first in the planning feature test: a scenario "A discussion Start the machine refuses is said", where the
  stand-in's `startDiscussion` answers exit 78 with the no-homeserver line. It expects the log line and the notice
  with those words. A second case, declining in the dialog, expects neither.
- The error colour of the planning screen's own line is the planner's screen package's matter, then a re-pin.

`F543 size=S est=15 basis=median S 15 (11 records)`
