# F547 — The Window Signs Its Own Calls To The Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F547",
  "title": "The Window Signs Its Own Calls To The Planner",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 109,
  "blockedBy": [],
  "covers": "The window's own calls to porelo-planner, handing in an idea and setting the planner's log level, go through the planning screen's signed call, so a planner that refuses bearer tokens still takes them, and a planner that cannot prove itself is named in the window's log, not trusted."
}
```

**Why this size.** S: two calls in the window move to one exported call of the planning package, plus its pin.

Found from porelo-planner's PL113 (2026-11-13): every call to the planner is signed, and a bearer token is refused
with 401.

**How it stands.**
- `handIdea` (`lib/src/app/planner_ideas.dart:71`) and `tellPlannerLevel` (`lib/src/app/planner_log_level.dart:42`)
  send `Authorization: Bearer <token>` themselves.
- The window pins `porelo_planning` at `12aefb2`, which has no signed call.

**What must be true.**
- Both calls go through `callPlanner(...)` of `package:porelo_planning`, which signs each request and checks the
  planner's proof.
- A `PlannerNotProven` answer (`proofFailed` or `signatureRefused`) is not taken as the planner's word: the call
  fails, and the window's log names the failure, the port and the planner's log line.
- No call of the window's own sends `Authorization` to the planner any more.
- The window pins `porelo_planning` at the planner's commit that brings the signed call, once it is on GitHub.
