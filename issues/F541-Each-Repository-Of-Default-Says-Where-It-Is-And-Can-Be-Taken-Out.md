# F541 — Each Repository Of Default Says Where It Is And Can Be Taken Out

```json
{
  "$schema": "issue-1.json",
  "id": "F541",
  "title": "Each Repository Of Default Says Where It Is And Can Be Taken Out",
  "state": "Review",
  "size": "M",
  "priority": "Medium",
  "rank": 109,
  "blockedBy": ["F540"],
  "covers": "Each repository row on the page of default shows its upstream, the checkout's path or the remote's address, and offers to take it out of default as the command line does: its mirror stays, and each deploy key forgotten is said."
}
```

**Why this size.** M: a second read on the page (what `default` holds, with source and remote), a line per row, a
command in each row's menu with its answer and refusals, and tests for both kinds of upstream and for the removal.

**What must be true.**
- Each repository row of `default` says where it is: the checkout's path for one added from a checkout, the remote's
  address for one added by address.
- Each row offers *Take it out of default*, which does what `porelo project default remove <name>` does: the
  repository leaves `default`, its mirror and anything waiting in it stay, and each deploy key the machine forgot is
  said, to be removed at its forge. The row goes once it is out.

## Found

- The daemon's call is `RemoveFromDefault(name) -> (removed: bool, keys: []MachineDeployKey)`
  (`wire/.../org.fuin.porelo.Tasks1/20-project.varlink` 328-334, served at `ProjectMethods.java` 424), the same
  `DefaultProject.remove` the command line makes (`ProjectDefaultCommand.java` 115-124). `LeaveDefault` (348) is the
  same removal but refuses while a task of `default` works on the repository.
- The window has it: `removeFromDefault` (`lib/src/client/porelo_client.dart` 1450-1459,
  `lib/src/app/fleet_backend.dart` 495), used by the dialog *Repositories of the Default project*
  (`lib/src/ui/default_view.dart` 274-282, opened by the command `project.default`, `lib/src/app/commands.dart` 862).
  The dialog already words the answer and draws where each repository comes from (`DefaultRepository.comesFromAndGoes`,
  `lib/src/client/models.dart` 1555), from `DefaultRepositories` (`20-project.varlink` 316, 374-389: `upstream`,
  `checkout`, `source`, `remote`).
- `Projects` answers each repository's `upstream` (the checkout's path or the address) but not its source; the row on
  the page (`_RepositoryLine`, `lib/src/ui/machine_tree.dart` 612-700) shows no upstream and has no removal.

## Decided

- A removal from `default` is refused while a task of `default` works on the repository, as `LeaveDefault` does,
  not as the command line's `RemoveFromDefault`. The page and the dialog both take a
  repository out through `leaveDefault` (`lib/src/client/porelo_client.dart` 1465, which asks `RemoveFromDefault`
  only of a Porelo without `LeaveDefault`), and say `DefaultRepositoryInUse` with the tasks it names, as the claimed
  rows do (`lib/src/ui/claimed_default_rows.dart` 100-106).
- The removal is said in the status line, after the page has read the machine again, as a sync from the row is said.
  The command is offered without a question first, as the dialog's button is: the mirror stays, so nothing is lost.
- One removal at a time per machine, as the dialog's `_busy` holds it: while one runs, *Take it out of default* is
  unavailable on every row, and a second call is ignored, so its "not in default any more" never replaces the first
  one's words and keys.
- A read of what `default` holds that fails is said in the status line; the rows then say their upstream alone, and it
  is read again when the page is opened again or a repository is taken out.
- A gone repository (`NoSuchDefaultRepository`) is said as such and is no refusal; any other refusal is said with the
  machine's words.

## Plan

- On the page of `default`, read `defaultRepositories()` once it is drawn and after each removal, kept beside the
  page's project; each row of `default` (from [F540](README.md#f540)) adds `comesFromAndGoes` of the entry of its
  name to its subtitle, and `Repository.upstream` while that read has not answered.
- `_RepositoryLine` takes an optional `onTakeOut`; for `default` its menu carries a command *Take it out of default*
  (`home: Home.repositoryRow`), unavailable where the machine is not connected.
- The removal and its words move out of `_DefaultDialogState._remove` (`default_view.dart` 274-282) into one function
  both the dialog and the page call, through `leaveDefault` instead of `removeFromDefault`, so the two say the same:
  "<name> is out of default. Its mirror, and anything waiting in it, stay on <machine>." followed by each forgotten
  key's title; a refusal is said as the dialog says it.
- Red first, scenarios in `test/features/work_without_a_project.feature`: with `utils4j` from a checkout and `foo-2`
  from `git@example.org:acme/foo-2.git`, the page's rows say the checkout's path and the address (fails: no upstream
  is drawn); taking `foo-2` out from its row's menu leaves `default` without it, says that its mirror stays, and names
  the forgotten deploy key (fails: no such command); taking out a repository a task of `default` works on says which
  tasks hold it and leaves the row (fails: removed). Each with a `// Harm:` line.

## Acceptance

- The scenarios fail on `main` with [F540](README.md#f540) built and pass after; the dialog's scenarios still pass.
- The page and the dialog word a removal alike.
- `test/features` and `test/ui` pass whole.

## How it was built

- `lib/src/ui/default_view.dart`: `takeOutOfDefault` takes a repository out through `leaveDefault` and words what that
  came to, a refusal included; the dialog's `_remove` and the page call it.
- `lib/src/ui/machine_tree.dart`: `ProjectHeader` takes `inDefault`, `onTakeOut` and `takeOutUnavailable`; a row of
  `default` adds `comesFromAndGoes`, or `Repository.upstream` while not read, to its line, and its menu carries
  *Take it out of default* (`take-out-<name>`).
- `lib/src/ui/shell.dart`: the page of `default` reads `defaultRepositories()` once per place it is opened at, and
  again after a removal, then refreshes the machine and says the answer.
- Tests: six scenarios in `test/features/work_without_a_project.feature` (the rows' upstreams, a removal from the
  row with its forgotten key, a second take-out while the first runs, a failed read of what `default` holds, a
  refusal from the row, a refusal in the dialog); the test backend's `leaveDefault`
  refuses as Porelo does while a task of `default` works on the repository; the steps that put a repository into
  `default` from a checkout or a remote read the machine's projects again.
- Red: on [F540](README.md#f540)'s head all four scenarios failed: the rows drew no upstream, the row's menu had no
  *Take it out of default*, and the dialog took the repository out from under the task.
- Red of the guard and of the failed read: with the guard taken out, the scenario of a second take-out failed, as the
  machine was asked twice; with the failure's words taken out, the scenario of a failed read failed on the missing
  words.
