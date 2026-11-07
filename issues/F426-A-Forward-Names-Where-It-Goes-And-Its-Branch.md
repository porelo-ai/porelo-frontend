# F426 — A Forward Names Where It Goes And Its Branch

**Status:** Review.
**Size:** S - the forward dialog (`askWhichBranch` in `lib/src/ui/gate_view.dart`), its caller `_approve` in
`lib/src/ui/shell.dart`, one new optional `Task` field, one stored setting, and their tests.

**What must be true.** Forwarding a waiting push says which forge and which repository it goes to, and starts with
the branch filled in that this task's work goes to: the task's own branch at the forge, or else the branch this
task's work was last forwarded to. The branch stays visible and changeable, and nothing is sent before the person
presses *Forward it*.

## Why

In the trial move of 2026-11-07, *Forward it upstream* showed only the commit's subject. It named no forge and no
repository. Its empty field showed `fix-rounding` as a hint that read like a value already given. It did not offer
the task's own branch (`porelo/sluice`), since the list holds only the branches the forge has, and it asked again
on every forward of the same task. The operator decided: prefill the task's branch, or the one last used for this
task, visible and changeable.

## Plan

- The contract: `Task.forgeBranch` (`org.fuin.porelo.Tasks1`, `Task`) is the branch a task's work carries beyond the
  gate, `""` where it has none; a daemon before that field does not send it. `PendingPush.name` is the task's name
  (the ref under `refs/porelo/incoming/`). `Task` in `lib/src/client/models.dart` reads `forgeBranch` as an
  optional string, empty when absent, checked rather than cast.
- The branch last forwarded to is kept per machine, project, repository and task in the settings file (written
  beside itself and renamed over, every field checked), and only after the daemon confirmed the forward.
- `_approve` passes the destination and the prefilled branch: the task's `forgeBranch` where it is not empty, else
  the last one forwarded to, else none. The default branch's preselection stays only when nothing is prefilled.
- `askWhichBranch` shows, under the title, "To <forge host> <owner/repository>" from the repository's upstream
  (the project's repository state), or "To the repository's origin" in Default. A prefilled branch that the forge
  does not list yet is offered as *A new branch…* with its name filled in. Where it came from is said beside it:
  "this task's branch" or "last used for this task". The hint becomes `e.g. fix-rounding`, shown only while the
  field is empty and never as its value.
- Red first: a widget test whose task has `forgeBranch: porelo/sluice` opens the dialog and expects `porelo/sluice`
  chosen and the destination named. A second test forwards to `fix-2`, opens the next push of the same task, and
  expects `fix-2`.

## Acceptance

- The dialog names the forge and the repository the push goes to.
- With a task branch, it is filled in and marked as the task's; without one, the branch last forwarded to for that
  task is filled in and marked so; with neither, nothing is filled in and the hint reads `e.g. fix-rounding`.
- The filled-in branch can be changed or replaced before *Forward it*; the branch sent is the one shown.
- A refused or cancelled forward does not change the stored last branch.
- A `Task` reply without `forgeBranch` parses, with the field empty.

## Reading

- The prefill tests now press *Forward it* and check the branch sent; the test of the hint's wording went, as a
  wording is fixed, not guarded.
- A push, project or machine that changed while the forge listed its branches now opens no dialog, by the same check
  as after it. It has no test of its own: no stand-in reaches a forge's branch list from the review today
  (`FakeForge.branchesOf` is used by no test), and building one is larger than the check.
- The destination is not read with `fullNameOf`: that takes `owner/name` alone, so a repository in a subgroup would
  read as not reported. The destination's own reading now refuses an empty part, such as `acme/.git`.
- A stored branch with space around it is refused on load, as a hand-edited file could hold one.

