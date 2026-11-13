# F533 — The Idea Walk Tells A Builder Out Of Time From A Window Fault

```json
{
  "$schema": "issue-1.json",
  "id": "F533",
  "title": "The Idea Walk Tells A Builder Out Of Time From A Window Fault",
  "state": "Backlog",
  "size": "XS",
  "priority": "Low",
  "rank": 104,
  "blockedBy": [],
  "covers": "A walk of an idea to a finished story says, at the builder's own step, when a builder task ended unfinished, with its reason, rather than failing later at the window's report of that end."
}
```

**Why this size.** XS: one check in the walk's step where the builder works until its task ends, and its words.

Found in a walk of an idea to a finished story on a test machine (2026-11-13, run 29, step 8).
- The builder agent (pi, model z-ai/glm-5.3-flash) pushed its work within seconds; the gate took it.
- It then waited 30 minutes for a build report, which no task gets while its work sits only at the gate.
- Its time limit ended it unfinished. The window reported that end to the planner as it was, and the planner marked
  the issue FAILED.

The step "the builder agent works until its task ends" took that end as a success. The next step, "the window posts
the end of the builder task", then failed as if the window had reported wrongly.

**What must be true.**
- The builder's step fails when a builder task ended unfinished, naming the task and why it ended (for instance its
  time limit). It does not pass on to the window's step.
- Its words say that the agent ended unfinished, not that the window reported wrongly.
