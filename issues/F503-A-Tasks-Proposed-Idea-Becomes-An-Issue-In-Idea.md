# F503 — A Task's Proposed Idea Becomes An Issue In Idea

```json
{
  "$schema": "issue-1.json",
  "id": "F503",
  "title": "A Task's Proposed Idea Becomes An Issue In Idea",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 19,
  "blockedBy": [],
  "covers": "Each idea a task on a watched machine proposes is handed once to the planner as a new issue in Idea of the task's repository, naming the task it came from, also across restarts of the window; a refusal is said once, a planner not reached is tried again."
}
```

**Why this size.** S: one more record read from the task's row, one more hand-in in the report's sweep beside the
discussions' and its kept mark, with their tests; no contract another repository reads from the window. It waits on
two changes elsewhere: Porelo keeping each idea a task proposes on the task's row in `List` and `Watch`, and the
planner's new issue taking the name of the task it came from.

**What must be true.** An idea a task has while it works becomes an issue in Idea on the board, in the task's
repository, without anyone copying it there. The task proposes it to Porelo, which keeps it on the task's row; the
planner talks to no Porelo, so the window, which watches the tasks, hands it in. Each idea is handed once, however
often the row is seen and whether the window restarted meanwhile, so ideas become issues the normal way.

The contracts it builds against:

- **Porelo:** each task's row in `List` and `Watch` lists the ideas the task proposed, each with its title (one line)
  and what must be true (one or two sentences), in the order proposed; an idea stays on the row once listed.
- **The planner:** `POST /projects/{project}/issues` takes the repository, title, what must be true, no size, the
  board's revision it was made against, and the name of the task the issue came from; it saves the issue in Idea,
  answers its id, and refuses a stale revision (`StaleRevision`) or a field at fault in its own words.

## Plan

- `lib/src/client/models.dart`: a `ProposedIdea` with `title` and `mustBeTrue`, and `Task.ideas`, read from the row,
  null from a machine that does not list them. A red test first in `test/client/`.
- `lib/src/app/settings.dart`: a kept mark of each idea handed, by machine, the task's run (`Task.run`, the container
  where none) and the idea's title and text, so a later task under the same container name hands its own; forgotten
  with the task's other kept records.
- `WindowTaskReports` (`lib/src/ui/planning_reports.dart`) takes every task on every watched machine, not only those
  it started; `_sweepNow` hands each idea not marked, in order, through a new `_handProposed`. The issue goes to the
  task's project, its repository is the task's (`Project.repositoryOf`), its title and what must be true as the task
  wrote them, no size, the task named by its name in the project. It goes through the provider's source's
  `createIssue` with the revision read just before by `stories`, read again and sent once more on a stale revision.
- An idea saved, or refused for its fields, is marked and not handed again; a refusal is said once where the window
  shows planning problems, with the planner's faults, as an ended discussion's refused idea is today. A planner not
  reached, or a project no watched machine names the repository of yet, is said once and tried at the next sweep, as
  today's reports are.
- The discussions' hand-in (`handIdea`, `_handIdea`) stays as it is: it hands a story from a discussion's result file.
- A red test first in `test/ui/window_task_reports_test.dart`: a watched task whose row lists one idea is handed to
  the planner's fake once with the task's repository and name, a second sweep and a new reports instance on the same
  settings hand nothing, and a second idea on the same row is handed on its own.

## Acceptance

- A task that proposes an idea while it works has it on the board as an issue in Idea of its repository, naming the
  task, without a person doing anything.
- Each idea becomes one issue, also when the window restarts or the row is seen many times; two ideas become two.
- An idea the planner refuses is said once with its faults and not sent again; one sent while no planner was reached
  goes once one is.
