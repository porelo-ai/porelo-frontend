# F59 — A Project From A Repository, Measured Against GitHub

**Status:** Estimated; blocked by the test organisation, its token and signing key from the operator.
**Size:** S - a measurement against GitHub with the code as it is, and a fix only where one step
fails; it waits for the operator's token and test repositories.

**What must be true.** What is left of making a project from a repository is shown to work against
GitHub itself, not only against stand-ins.

## Why

Already measured against GitHub with two test repositories on a rented machine: a token connected
and its refusals shown in GitHub's words, a `project.yml` written in the form, committed signed and
pushed, the machine bound with a deploy key per repository titled
`sokar <machine> <project>/<repository>`, a task started, and in `default` a task's approved work
forwarded to the repository's `main`.

The token needs *Contents* and *Administration: Read and write* for the test repositories. Neither
the token nor the repositories are ever kept in this repository or the channel.

## Plan

- **Against real GitHub, in a CI leg.** In a test organisation of its own (`sokar-ai-test`), with
  its test repositories made once by a script, and a fine-grained token scoped to that organisation
  only, kept as the Actions secret `SOKAR_TEST_GITHUB_TOKEN` of this repository with the signing
  key `SOKAR_TEST_SIGNING_KEY`. The leg runs in the Build's job against a leased machine, on a push
  to `main` or by hand, never for a pull request, and skips itself while either is missing. The
  operator makes the organisation, the token and the key.
- **No new code is planned:** each criterion is measured on the VM against Sokar's handover, with
  the interface built from this repository and the operator's token and test repositories. A step
  that fails becomes a fix with its test first.
- **Deploy keys:** a machine cleared with `MachineClearing` (`lib/src/app/machine_clearing.dart`) and
  one removed with `MachineBinding.remove` (`lib/src/app/machine_binding.dart`); then the keys are
  listed at GitHub, by its own page and by `GitHub.deployKeys` in `lib/src/app/forge.dart`.
- **A verified commit:** `project.yml` committed by `ProjectWorkspace.commitAndPush` in
  `lib/src/app/project_workspace.dart`, then GitHub's commit page read for "Verified".
- **Branch protection:** a rule set on the test repository's branch; a push through
  `ProjectWorkspace` and a forward through `Gate.approve` (`lib/src/app/gate.dart`) are made against
  it, and the words shown are compared with GitHub's.
- **Past 100 repositories:** `GitHub.repositories` in `lib/src/app/forge.dart` read for the test
  organisation, which holds 104, and compared with GitHub's own list, admin and push rights
  included. Only the fine-grained token: both kinds are listed through the same `/user/repos`, so
  a classic token adds nothing to prove and is not kept.
- **Approved work in a project:** a task started in a project, its push forwarded at the gate, and
  the commit looked for on the repository's branch at GitHub.
- **Red first:** none written ahead; the unit tests in `test/app/forge_test.dart` stand for GitHub's
  answers, and a measurement that differs from them is written there as a failing test first.

## Acceptance

- **Removing a machine, or unbinding it, deletes its deploy keys at GitHub.** Seen to fail: the
  repository's deploy keys listed at GitHub after the removal still hold the machine's key.
- **A `project.yml` committed in the form is shown as verified by GitHub**, signed with the person's
  ssh key. Seen to fail: GitHub's commit page shows it unverified.
- **A push that branch protection refuses** is said in GitHub's words. Seen to fail: a push to a
  protected branch shows anything other than GitHub's refusal.
- **The repository list pages past 100 repositories**, with admin and push rights as GitHub reports
  them. Seen to fail: the test organisation's 104 repositories with one missing or its rights
  differing from GitHub's.
- **Approved work in a project**, not only in `default`, reaches the repository at GitHub. Seen to
  fail: the approved commit is not on the repository's branch at GitHub.

## To be checked

- **Which push branch protection is measured against:** the commit of `project.yml`, the forward
  of approved work, or both. (Agent Frontend's)
