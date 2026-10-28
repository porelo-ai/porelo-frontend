# F207 — A Task's Branch At The Forge Named By The Project's Scheme

**Status:** Idea.

**What must be true.** In a project whose `project.yml` has a `branch` block, the interface shows each task's branch
at the forge, lets the person name it at the start where the scheme's template would not, and approves to it by
default; a refused or taken branch is said in the start's words, with what to do. A project without a block looks
and acts as before (`porelo/<task>`).

## Why

`porelo` [B190](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b190) names a task's branch at
the forge from the project's scheme (`branch.template`, `branch.pattern`), and its contract reaches the interface.
Read for the interface, it breaks nothing: `StartOutcome` is an open class, so `BRANCH_REFUSED` is read; the new
`Task.forgeBranch` is a field the client does not read yet; and the interface still names a branch on `Approve`.
Until this is built, a project with a block shows no task its branch, and the approval asks for a branch the daemon
would have chosen.

## Plan

- **Shown:** `Task.forgeBranch` on the work's tile and in its detail, where it is not `porelo/<task>`; "" for a task
  without a gate shows nothing.
- **At the start:** an optional field for the branch, passed as `branch` to `CanStart` and `Start`; `BRANCH_REFUSED`
  shown with its `detail` (the branch and the pattern), and `BranchTaken` with its `detail`, each with naming another
  branch as the way on.
- **The approval:** in a project with a block, the branch field starts empty and means the task's own branch;
  `BranchRefused` and `BranchRequired` said in their own words. Without a block, the branch stays required as today.
- **The mock:** `MockDaemon` and `FakeBackend` take `branch`, answer `forgeBranch`, and the three refusals.
- **Red first:** a widget test that a task's branch from a scheme is shown and approved to with the field left empty,
  and that a project without a block sends the branch as today.
