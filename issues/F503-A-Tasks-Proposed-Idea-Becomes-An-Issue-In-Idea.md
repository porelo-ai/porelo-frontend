# F503 — A Task's Proposed Idea Becomes An Issue In Idea

```json
{
  "$schema": "issue-1.json",
  "id": "F503",
  "title": "A Task's Proposed Idea Becomes An Issue In Idea",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
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

- **Porelo:** each task's row in `List` and `Watch` lists the ideas the task proposed (`ideas`, `[]` when none), oldest
  first, each with its id (`idea-1`, `idea-2`, ... counted per task), its title (one line, at most 120 characters), what
  must be true (at most 1000 characters, line breaks allowed) and when the host kept it; an idea stays on the row until
  the task is removed, and a later start keeps it. A project allows at most 100 ideas per task. The text is the
  agent's own, so the window takes it as untrusted input.
- **The planner:** `POST /projects/{project}/issues` takes the repository, title, what must be true, no size, the
  board's revision it was made against, and the name of the task the issue came from; it saves the issue in Idea,
  answers its id, and refuses a stale revision (`StaleRevision`) or a field at fault in its own words.

## Plan

- `lib/src/client/models.dart`: a `ProposedIdea` with `id`, `title`, `mustBeTrue` and `at`, and `Task.ideas`, read from
  the row, null from a machine that does not list them. A red test first in `test/client/`. The mock machine lists
  `ideas: []` on every row, and an idea only where a test proposes one, so a mock walk never hands one to a real
  planner.
- `lib/src/app/settings.dart`: a kept mark of each idea handed, by machine, the task's run (`Task.run`, the container
  where none), the idea's id and a digest of its title and text, so a later task under the same container name hands
  its own; forgotten with the task's other kept records, the oldest dropped past a bound.
- Before it is handed, an idea is held to the bounds Porelo states (an id `idea-<n>`, a title of one line of at most
  120 characters, at most 1000 characters of what must be true, no control characters but its line breaks); one out
  of them is marked and said, never handed or quoted.
- `WindowTaskReports` (`lib/src/ui/planning_reports.dart`) takes every task on every watched machine, not only those
  it started; `_sweepNow` hands each idea not marked, in order, through a new `_handProposed`. The issue goes to the
  task's project, its repository is the task's (`Project.repositoryOf`), its title and what must be true as the task
  wrote them, no size, the task named by its name in the project. It goes through the provider's source's
  `createIssue` with the revision read just before by `stories`, read again and sent once more on a stale revision.
  The window passes the task's name through a hand-over of its own, as the screen package's `createIssue` takes no
  task yet; until the pinned package carries it, the issue goes in without the task's name.
- An idea saved, or refused for its fields, is marked and not handed again; a refusal is said once where the window
  shows planning problems, with the planner's faults, as an ended discussion's refused idea is today. A planner not
  reached, or a project no watched machine names the repository of yet, is said once and tried at the next sweep, as
  today's reports are.
- The discussions' hand-in (`handIdea`, `_handIdea`) stays as it is: it hands a story from a discussion's result file.
- What the plan's reading asked, and the answers: a voided offer forgets the offer alone, the idea marks only go with
  the task's removal; an id past `idea-100` is out of bounds. Kept as they are: the planner's call takes no key that
  makes a second send of the same idea harmless, so a window that ends between the planner's save and its mark sends
  that idea once more at its next start; the window runs once per account, so no second window writes the marks; a
  watched machine is the person's own choice and the project's `limits.ideas` (0 by default) is what lets its tasks
  propose; a planner's fault words are its own, which by its contract never repeat what was sent; a later sweep comes
  with the next change of a machine or the planner, as today's reports do.
- What the code's reading found, and the answers: only `IssueNotAllowed` naming the title or what must be true is
  final, any other refusal is tried at the next start; an idea not handed in this window's life keeps the task's later
  ideas behind it; `RevisionMoved` is read again later; a handed-in discussion stays while an idea of its own waits,
  and the proposed ideas are handed before the discussions; a removal forgets its records before it writes; an entry
  of `ideas` that is no object is kept empty and refused in words. Kept as they are: the planner's project is bound as
  the board's is, by the machine shown first; past 500 tasks with ideas the oldest marks go; a planner that saved and
  then timed out is asked again; a settings write that fails is not seen, as for every kept record.
- A red test first in `test/ui/window_task_reports_test.dart`: a watched task whose row lists one idea is handed to
  the planner's fake once with the task's repository and name, a second sweep and a new reports instance on the same
  settings hand nothing, and a second idea on the same row is handed on its own.

## Acceptance

- A task that proposes an idea while it works has it on the board as an issue in Idea of its repository, naming the
  task, without a person doing anything.
- Each idea becomes one issue, also when the window restarts or the row is seen many times; two ideas become two.
- An idea the planner refuses is said once with its faults and not sent again; one sent while no planner was reached
  goes once one is.

## To be checked

- Decided (2026-11-13): ideas were handed in first without the task's name, not held back, until the window's pin
  moved to a screen package whose `createIssue` takes the task. The pin has moved: each issue now names its task, the
  name the planner takes (`[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`, matched whole); a name outside it goes without, so its
  idea is not held back at every start.
