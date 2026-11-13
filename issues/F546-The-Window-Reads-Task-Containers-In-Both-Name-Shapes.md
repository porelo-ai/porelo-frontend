# F546 — The Window Reads Task Containers In Both Name Shapes

```json
{
  "$schema": "issue-1.json",
  "id": "F546",
  "title": "The Window Reads Task Containers In Both Name Shapes",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 108,
  "blockedBy": [],
  "covers": "The window, its stand-in machine and the walk steps take a task container's name in both of porelod's shapes, `porelo_<task>` for project porelo and `porelo-<project>_<task>` for every other project, and judge a new task's name against the shape it will get."
}
```

**Why this size.** S: four places in the window's code and two walk steps, each with a test of both shapes.

Found from porelo's B246 (2026-11-13), which lands with Core's next round.

**How it stands.**
- With B246, a new task of project porelo is named `porelo_<task>`, and every other project's task
  `porelo-<project or short>_<task>`. Tasks made before keep their names.
- `RunningView.shortName` (`lib/src/ui/running_view.dart:593`) cuts `porelo-` alone, so a new task of project porelo
  shows as `porelo_<task>`.
- `taskNameProblem` (`lib/src/app/task_names.dart:35`) measures a new task's length against `porelo-$project-$name`,
  a shape porelod no longer makes.
- The stand-in machine (`lib/src/mock/machine.dart:2328`, `:2340`, `:2341`) cuts `porelo-$project-` from a name to
  get its task.
- The walks' `containerOf` (`integration_test/support/remote.dart:99`) names project porelo's tasks `porelo-<task>`.
  Two steps match `porelo-<project>_`
  (`integration_test/step/i_forward_it_to_the_tasks_own_branch_on_the_hosts_forge.dart:12`,
  `integration_test/step/the_project_and_its_task_are_removed_again.dart:29`).

**What must be true.**
- A task's short name drops the prefix of either shape, and only that prefix.
- A new task's name is measured against the container name porelod will give it.
- Where the window needs a container's task, it takes the task porelod names, else the name without its prefix in
  either shape. It never cuts a prefix it guessed from the project.
- The walks name and match containers in both shapes, so a walk against a porelo from before B246 and one from after
  both hold.
