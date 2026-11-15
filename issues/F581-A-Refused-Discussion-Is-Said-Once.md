# F581 — A Refused Discussion Is Said Once

```json
{
  "$schema": "issue-1.json",
  "id": "F581",
  "title": "A Refused Discussion Is Said Once",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 61,
  "blockedBy": [],
  "covers": "Story ST361: a refused start of Discuss an idea is said in one place, its reason first and readable, the machine's detail table folded or kept in its lines, instead of twice at once."
}
```

**Why this size.** One refusal path in one file, and the words it hands on; the board's own line is the planner's.

**What must be true.** A person whose discussion is refused reads why once, where they pressed, and can read the
machine's details when they want them.

## Plan

- Today `_sayRefused` in `lib/src/ui/planning_embedding.dart` both tells the window (`onStartRefused`, the panel
  across the window's bottom) and throws the same words as a `PlanningRefusal` to the planner, which shows them as a
  line under the board's filters: every refused start is said twice, and porelo's whole output, its detail table
  included, is the message of both.
- One place: a start the person pressed on the board is said by the board alone, through the refusal; the window's
  panel stays only for a start nobody pressed (one the planner moves on by itself), where no board line stands.
- Readable: the words handed on lead with porelo's last line (`the task cannot …: <reason>`); the detail table
  follows below it, its lines kept, or folded where the board offers a fold.
- It only reads wrong: no test.

## Acceptance

- In the debug build a refused discussion shows one line under the filters, its reason first, and no panel.

## To be checked

- With Agent Planner: how the board's line renders a message of several lines, and whether it offers a fold for a
  refusal's details.
- Which starts reach `_sayRefused` without a press on the board, so the panel stays for them.
