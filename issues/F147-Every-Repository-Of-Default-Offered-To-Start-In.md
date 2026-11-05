# F147 — Every Repository Of Default Offered To Start In

**Status:** Review.
**Size:** XS - one getter and one line of parsing in `models.dart`, a scenario and a unit test beside the ones it touches.

**What must be true.** Starting work in default offers every repository default has. None is
hidden as the project's own, because default has no own repository: with `utils4j` and `units4j` in
default, both can be chosen.

With Porelo 0.5.1~snapshot.317, the daemon answers `Projects` for default with both repositories
`"own": false`. The dialog *Start work in default* offers only `units4j`, and *Start work on it*
beside `utils4j` opens it with no repository chosen.

## Plan

- `Project.ownRepository` (`lib/src/client/models.dart`) falls back to the first repository even
  when the machine sent `repositoryStates` and none of them is `own`. `workRepositories` then drops
  that first one from every project of two or more. The fallback is kept only where the machine sent
  bare names and no states, as an older one does. Where the states are there and none says `own`,
  there is no own repository, and `workRepositories` is every repository.
- Default is also never given an own repository by name (`defaultProject`), as `machine_tree.dart`
  already treats it.
- `Repository.allIn` read bare names into states with `own: false`, so the getter could not tell an older machine from one saying none is own. It now marks the first bare name `own`, as that shape means, and the getter takes `own` alone wherever states exist.
- Red first: a scenario in `test/features/work_without_a_project.feature` — default with two repositories, neither its own, and *Start work in default* offers both — and unit tests in `test/client/project_test.dart` for states with no `own`, a marked `own`, bare names, and default in both shapes.

## Acceptance

- In the start dialog for default with two repositories, both are offered. The one chosen by
  *Start work on it* is the one chosen in the dialog.
- A followed project whose machine marks one repository `own` still does not offer it. The scenarios *a project that names other repositories never offers its own to work in* and *a project with one repository to work in has it chosen* stay green.

## Decided while building

- **The scenario stands in `work_without_a_project.feature`**, not `task_creation.feature`: its background has default on the machine and the other scenarios of starting in default stand there, where `task_creation`'s would need a new step to read the projects again.
- **The older machine's bare names are marked where they are read**, rather than by a new field on `Project`: a field is lost by every fixture and copy that builds a `Project` from another, and the state's `own` is already what is carried. A machine tree of such a machine therefore no longer draws the own repository as a row of work, as it already does for a machine that marks it.
- **Objects with no `own` at all count as states saying none is own**, as `Repository.from` reads a missing `own` as false: the machine sent states, and none of them marks one.
- **`repositoryOf` follows the getter**: a task in default that names no repository is read as naming none, where it used to be given default's first. *Start again* then sends the machine no repository rather than a guess at one.
- **Checked:** the steps behind the two scenarios above send `own` on the first repository, and the mock machine sends `own: true`, so both stay as worded. `test/app/start_work_test.dart` and `test/app/gate_test.dart` hold bare names, and stay green.
