# F147 — Every Repository Of Default Offered To Start In

**Status:** Backlog.
**Size:** XS - one getter in `models.dart`, a scenario and a unit test beside the ones it touches.

**What must be true.** Starting work in default offers every repository default has. None is
hidden as the project's own, because default has no own repository: with `utils4j` and `units4j` in
default, both can be chosen.

Found on 2026-10-22 on the operator's computer with Porelo 0.5.1~snapshot.317. The daemon answers
`Projects` for default with both repositories `"own": false`. The dialog *Start work in default*
offered only `units4j`, and *Start work on it* beside `utils4j` opened it with no repository chosen.

## Plan

- `Project.ownRepository` (`lib/src/client/models.dart`) falls back to the first repository even
  when the machine sent `repositoryStates` and none of them is `own`. `workRepositories` then drops
  that first one from every project of two or more. The fallback is kept only where the machine sent
  bare names and no states, as an older one does. Where the states are there and none says `own`,
  there is no own repository, and `workRepositories` is every repository.
- Default is also never given an own repository by name (`defaultProject`), as `machine_tree.dart`
  already treats it.
- Red first: a scenario in `test/features/task_creation.feature` — default with two repositories,
  neither its own, and *Start work in default* offers both — and a unit test of `workRepositories`
  for states with no `own`.

## Acceptance

- In the start dialog for default with two repositories, both are offered. The one chosen by
  *Start work on it* is the one chosen in the dialog.
- A followed project whose machine marks one repository `own` still does not offer it. The
  scenarios at `task_creation.feature:446` and `:452` stay green.

## To be checked

- Whether the mock daemon and the steps behind `task_creation.feature:446` send `own: true` or bare
  names, so the narrowed fallback keeps them green without a change to their wording.
