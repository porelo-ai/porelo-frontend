# F284 — The Subagent Number Chosen When Starting

**Status:** Idea.

**What must be true.** When work is started, the person can set how many subagents the agent may run at the same
time in that task. The field shows the number that applies without a choice, and a number Core refuses is said before
anything is made.

## Idea

- The start dialog gains a field for the number of subagents at the same time: 0 for none, or a whole number of 1 or
  more. It is sent as `Start`'s `subagents`.
- Left alone, nothing is sent. Core then takes the project file's or the repository's `limits.subagents`, else 0. The
  field shows that number and where it came from.
- An agent whose definition says it cannot enforce a number takes only 0. The field then says so and offers no other
  number.
- `CanStart`'s `SUBAGENTS_REFUSED` already reaches the person in Core's words today. With the field, the dialog also
  points to the field or to the project file, wherever the number came from.
- A task brought back keeps its number, and Core refuses another. So a continuation shows the kept number and does not
  offer to change it.

## To be decided

- Whether the field is shown always, or only for an agent that can enforce a number.
- Whether the start-agents list, which starts several at once, takes one number for all.
