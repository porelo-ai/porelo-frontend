# F59 — A Project From A Repository, Measured Against GitHub

```json
{
  "$schema": "issue-1.json",
  "id": "F59",
  "title": "A Project From A Repository, Measured Against GitHub",
  "state": "Estimated",
  "size": "S",
  "priority": "Low",
  "rank": 7,
  "blockedBy": [],
  "covers": "Making a project from a repository measured against GitHub."
}
```

**Why this size.** a measurement against GitHub with the code as it is, and a fix only where one step
fails; it waits for the operator's token and test repositories.

**Blocked by** the test organization, its token and signing key from the operator.

**What must be true.** What is left of making a project from a repository is shown to work against
GitHub itself, not only against stand-ins.

## Why

`GitHub` in `lib/src/app/forge.dart` lists repositories and their permissions and reports refusals
in words. `ProjectWorkspace` in `lib/src/app/project_workspace.dart` can commit and push signed
changes; `Gate.approve` in `lib/src/app/gate.dart` forwards approved work.

The promise on a host's read-only keys is not met: `Forge` in `lib/src/app/forge.dart` has no deploy-key operations,
and taking a project off and `down` remove nothing at the forge. `test/ui/forge_credentials_test.dart` expects
clearing a machine to leave deploy keys at the forge. The host's side of this is Agent Machines'.

`project.yml` comes from *Fill it from a checkout…*, under *Organization*.

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
- **A host's read-only keys:** taking a project off and `down` delete them at the central forge, with the forge's token
  asked once and kept nowhere. Where that is impossible, they are named with a link to where they are removed by
  hand. Then the keys are listed at GitHub, by its own page and API.
- **A verified commit:** `project.yml` from the entry *Fill it from a checkout…* shows, committed signed by the project's
  admin, then GitHub's commit page read for "Verified".
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

- **Taking a project off a host, and `down`, delete the host's read-only keys at the central forge,** the token asked
  once and kept nowhere; where that is impossible, the keys are named with a link. Seen to fail: the repository's
  deploy keys listed at GitHub afterwards still hold the host's key, and nothing named it.
- **A `project.yml` signed into a project is shown as verified by GitHub**, signed with the person's
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
