# F59 — A Project From A Repository, Measured Against GitHub

**Status:** Estimated; blocked by the test organisation, its token and signing key from the operator.
**Size:** S - a measurement against GitHub with the code as it is, and a fix only where one step
fails; it waits for the operator's token and test repositories.

**What must be true.** What is left of making a project from a repository is shown to work against
GitHub itself, not only against stand-ins.

## Why

`GitHub` in `lib/src/app/forge.dart` lists repositories and their permissions and reports refusals
in words. `ProjectWorkspace` in `lib/src/app/project_workspace.dart` can commit and push signed
changes; `Gate.approve` in `lib/src/app/gate.dart` forwards approved work.

The deploy-key deletion promise is not met: `MachineClearing.clearIt` in
`lib/src/app/machine_clearing.dart` only clears through the daemon, `MachineBinding` in
`lib/src/app/machine_binding.dart` has no unbinding operation, and `Forge` in `lib/src/app/forge.dart`
has no deploy-key operations. `test/ui/forge_credentials_test.dart` expects clearing to leave
deploy keys at the forge. `lib/src/ui/forges_page.dart` offers no form to create `project.yml`, so
the verified-commit criterion cannot be exercised through that form.

The token needs *Contents* and *Administration: Read and write* for the test repositories. Neither
the token nor the repositories are ever kept in this repository or the channel.

## Plan

- **Against real GitHub, in a CI leg.** In a test organization of its own, with
  its test repositories made once by a script, and a fine-grained token scoped to that organisation
  only, kept as the Actions secret `PORELO_TEST_GITHUB_TOKEN` of this repository with the signing
  key `PORELO_TEST_SIGNING_KEY`. The leg runs in the Build's job against a leased machine, on a push
  to `main` or by hand, never for a pull request, and skips itself while either is missing. The
  operator makes the organisation, the token and the key.
- **No new code is planned:** each criterion is measured on the VM against Porelo's handover, with
  the interface built from this repository and the operator's token and test repositories. A step
  that fails becomes a fix with its test first.
- **Deploy keys:** a machine cleared with `MachineClearing` (`lib/src/app/machine_clearing.dart`) and
  one unbound from the project; then the keys are listed at GitHub, by its own page and API.
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
