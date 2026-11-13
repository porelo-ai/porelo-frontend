# F540 — The Default Project's Page Lists Its Repositories

```json
{
  "$schema": "issue-1.json",
  "id": "F540",
  "title": "The Default Project's Page Lists Its Repositories",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 108,
  "blockedBy": [],
  "covers": "The page of the project default lists every repository the machine holds in it, under Repositories, as any other project's page lists its own; nothing the daemon already answers is dropped."
}
```

**Why this size.** S: one condition in the project header that leaves `default` out on purpose, a guard against a
phantom row from an older Porelo, and a test on each of the two ways to the page.

Found on 2026-11-13 with a window of snapshot.512: the page of `default` showed no *Repositories* section, while
`porelo projects` on the same machine said "3 repositories: utils4j, units4j, foo-2".

**What must be true.** The page of `default` lists every repository the machine holds in it, a row each under
*Repositories*, whether it is opened under *My projects* or from the machine.

## Found

Read on `main` (`441a4663`) and on the daemon's `main` (`c1dade058`). The window drops them; the daemon reports them.

- **The daemon reports them.** `Projects` and `WatchProjects` answer each project's `repositories` as `[]Repository`
  (`wire/.../org.fuin.porelo.Tasks1/20-project.varlink` 49-60, type at 433-441: `name`, `own`, `upstream`). For
  `default` the listing always has a row (`ProjectInventory.java` 495-504), its file is the one `DefaultProject` writes
  from the repositories added to it (`ProjectSource.java` 67-70, `DefaultProject.java` 391-407), and
  `repositoriesOf` lists each of them with `own` false, leaving out only the model's phantom repository named
  `default` (`ProjectInventory.java` 931-978, the skip at 950). Nothing is held as "loose" or under another field;
  `DefaultRepositories` (`20-project.varlink` 316) answers the same repositories with their source and remote.
- **The window reads them.** `Project.from` takes `repositories` into `repositoryStates` (`lib/src/client/models.dart`
  2516, `Repository.allIn` 5119-5131). The test backend answers `default` the same way, "measured on 254"
  (`test/features/support/world.dart` 388-402).
- **The window drops them.** `ProjectHeader.build` sets `listed` to an empty list for `default`
  (`lib/src/ui/machine_tree.dart` 397-405). `workRepositories` (406-410) is then only the names of `onTheMachine`,
  and the section is drawn only when it is not empty (527). `onTheMachine` is null on the page opened under *My
  projects* (`lib/src/ui/shell.dart` 6285: `from == null && waits == null`), so that page lists nothing. Opened from
  the machine, `_onTheMachine` (`shell.dart` 6349-6372) builds the names from `repositoryStates` without leaving
  `default` out, so the rows show there - two ways to one page, two answers.

## Plan

- `machine_tree.dart` 400-405: list `default`'s repositories as the daemon names them, every one but a row named
  `default` (an older Porelo's phantom); keep leaving the own repository out of every other project.
- Nothing else changes: the rows reuse `_Repositories` and `_RepositoryLine` (555-700) as they are, the behind line
  at 511 stays as it is for `default`.
- Red first, a scenario in `test/features/work_without_a_project.feature`, with `// Harm:` in its step file or the
  feature's comment: given `default` holds `utils4j`, `units4j` and `foo-2`, when the project `default` is selected
  under *My projects*, the section `project-repositories` lists a row `repository-<name>` for each. It fails today on
  the missing section.
- A second scenario opens the page from the machine and sees the same three rows, so both ways stay alike.

## Acceptance

- Both scenarios fail on `main` and pass after.
- A `default` that holds nothing shows no section and no phantom row named `default`.
- `test/features` and `test/ui` pass whole.

## To be checked

- On the operator's machine, that its Porelo answers the three repositories in `Projects` for `default` (a call of
  `Projects` over the socket); a Porelo older than repositories per project answers none, and the page then rightly
  lists none.
