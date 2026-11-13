# F546 — The Window Reads Task Containers In Both Name Shapes

```json
{
  "$schema": "issue-1.json",
  "id": "F546",
  "title": "The Window Reads Task Containers In Both Name Shapes",
  "state": "Review",
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

## Plan

- One helper, `lib/src/app/container_names.dart`: `newContainerName(project, task)`, the name porelod gives a new task
  (`porelo_<task>` in project `porelo`, `porelo-<project>_<task>` in any other), and `withoutContainerPrefix(name)`:
  what follows `porelo_` or `porelo-<project>_` (neither a project's nor a task's name holds `_`), else what follows
  `porelo-`, else the name itself. It is given no project, so it never cuts a prefix guessed from one.
- `shortName` (`lib/src/ui/running_view.dart:593`) calls `withoutContainerPrefix`. Unit test, plain `test()`, in
  `test/app/container_names_test.dart`: both new shapes, both shapes from before, a name of neither, a prefix with
  nothing after it. Harm: the walk's forward step and the stand-in take a task from it; a cut that leaves part of the
  prefix or takes part of the task names a task that does not exist, so a command acts on none or on the wrong one.
  Red first: the helper starts as today's cut of `porelo-` alone.
- `taskNameProblem` (`lib/src/app/task_names.dart:35`) measures `newContainerName(project, name)`. Unit test, plain
  `test()`, in `test/app/task_names_test.dart`: in project `porelo` a name whose `porelo_<name>` just fits passes and
  one character more is refused; in project `checkout` the same at its own edge. Harm: the window refusing a name
  porelod takes, so no work can start under it. Red first: today the fitting name in project `porelo` is refused,
  measured as `porelo-porelo-<name>`.
- The stand-in machine (`lib/src/mock/machine.dart:2328`, `:2340`, `:2341`): `_task` takes the task by
  `withoutContainerPrefix` from a name of the new shape, else by porelod's own rule for a name from before
  (`porelo-<project>-`, or `porelo-` in project `porelo`); the stand-in plays porelod and knows the project, so this is
  no guess. A Start given a bare task name lists its container as `newContainerName`; a name that already is a
  container's is kept. Test in `test/client/mock_machine_test.dart`, the client against `MockDaemon` over a socket,
  seconds: tasks named in both new shapes and one from before list their task, `branch` and `forgeBranch`; a Start of a
  bare task lists `porelo-checkout_<task>`. Harm: a stand-in answering a task porelod would not, so the window's tests
  over it pass on a fixture no real machine produces. Red first: today the task of `porelo-checkout_fix` is the whole
  name.
- The walks: `containerOf` (`integration_test/support/remote.dart:99`) gives `newContainerName`, and `containersOf`
  adds the name from before (`porelo-<task>` in project `porelo`, `porelo-<project>-<task>` in any other) for what must
  be gone. The forge step takes the task the host lists, else `withoutContainerPrefix`; the removal step checks that
  neither shape is left. Walk code: no unit test, made correct and analyze-clean; nothing runs on a VM.

## How it was built

- `lib/src/app/container_names.dart` holds `newContainerName` and `withoutContainerPrefix`. The second cuts `porelo_`
  or `porelo-<project>_` and keeps everything after it, else only `porelo-` from a name from before, and keeps whole a
  name of neither shape or with nothing after its prefix; it is given no project.
- `RunningView`'s tab name calls `withoutContainerPrefix`. Test: `test/app/container_names_test.dart` (red: the helper
  as the old cut of `porelo-` kept `porelo_fix-rounding` whole and cut `porelo-checkout_` to `checkout_`).
- `taskNameProblem` measures `newContainerName(project, name)`. Test: `test/app/task_names_test.dart` (red: in project
  `porelo` a 58-character name, whose `porelo_<name>` is 65 long, was refused as `porelo-porelo-<name>`, 72; the edge
  in project `checkout` passed before, so it was seen red by measuring with `>=` and put back). porelod's own length
  check still measures `porelo-<project>-<task>` against 64, so in project `porelo` a name of 51 to 58 characters now
  passes here and is refused by Start, which stays the authority.
- `longestContainerName` is 64, not 65: Core answered (18:55Z, core-stack-next 3edc9f71f) that a container name has at
  most 64 characters (`ContainerName.MAX_LENGTH`), so the ssh-agent socket path fits. Test:
  `test/app/task_names_test.dart` (red: at 65 a 58-character name in project `porelo`, whose `porelo_<name>` is 65
  long, was taken).
- The stand-in takes a task from either prefix it gives a new task, else from the one it gave before, with its own rule
  rather than the window's helper, so a fault in one is not mirrored by the other. Its Start keeps a name given in a
  shape it gives the project's containers, new or from before, and lists any other, also a task's own name that begins
  `porelo-`, under `porelo-<project>_<task>`. Tests in `test/client/mock_machine_test.dart` (red:
  `porelo-checkout_fix-rounding` listed itself as its task, a start of `fix-rounding` listed a container named
  `fix-rounding`, and a start of `porelo-fix` one named `porelo-fix`). The stand-in's Start knows only the projects
  `billing` and `checkout`, so its rule for `porelo_` is reached only by a task added in project `porelo` directly.
- The walks: `containerOf` gives `newContainerName`, `containersOf` adds the name from before; the forge step takes the
  task the host lists, else `withoutContainerPrefix`; the conversation's setup and its removal step stop and remove
  `write` under both names, each tolerating the one no task has, and the removal step then checks both are gone,
  beside its check that nothing names the project. The other callers of `containerOf` name test projects other than
  `porelo`, whose tasks porelod names alike before and after its change, and stay as they are. Analyze-clean; no walk
  ran.
