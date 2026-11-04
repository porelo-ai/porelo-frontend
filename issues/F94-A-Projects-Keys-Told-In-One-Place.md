# F94 — A Project's Keys Told In One Place

**Status:** Estimated.
**Size:** M - a new question to the forge, the binding's survey and its dialog, and scenarios with a
fake branch rule; nothing another repository reads changes.

**What must be true.** A person sees a project's keys in one place, whose each is and what it is for,
and learns whether their own signing key satisfies a branch rule that demands signed commits.

## Why

`ProjectForgeDialog` in `lib/src/ui/project_forge_view.dart` reads the SSH agent's signing keys
through `ProjectWorkspace.signingKeys`, and asks for a choice when needed. It does not list every
project key with its owner and purpose. `lib/src/app/forge.dart` reads no branch rule requiring
signed commits, and `lib/src/ui/project_forge_view.dart` does not check the person's key against
such a rule, so the branch-rule promise is not met.

`test/features/project_from_repository.feature` is not present, and
`test/features/forge_repositories.feature` has no "every Porelo key and signer is listed" scenario.
The planned key-list scenarios below have no current feature to extend as named.

## Plan

- **Today's pieces.** `MachineBinding` in `lib/src/app/machine_binding.dart` handles pending
  configuration changes and has no survey. `ProjectForgeDialog` in
  `lib/src/ui/project_forge_view.dart` reads `ProjectWorkspace.signingKeys`, the SSH agent's keys,
  without querying `Forge.signingKeys`. `Forge` in `lib/src/app/forge.dart` has no deploy-key
  operations, and `lib/src/client/models.dart` has no `Followed.signers`. The dialog has neither
  the two key lists nor their "Remove" rows.
- **One list.** A survey reads the person's signing keys at the forge and what the machine
  pinned, and answers one list of records: the key (title or fingerprint), whose it is (a machine
  by name, or the person), and what it is for (fetching read-only, pushing, signing the person's
  commits, signing a machine's messages). The dialog renders that list in place of the two;
  "Remove" stays on the rows that have it today.
- **The branch rule.** `Forge` in `lib/src/app/forge.dart` gains a question: whether a branch of a
  repository requires signed commits. `GitHub` answers it from the rules that apply to the branch
  (`GET /repos/{owner}/{repo}/rules/branches/{branch}`, a `required_signatures` rule), which a
  token that only reads the repository may call; a classic branch protection needs admin and is
  read only where the token has it.
- **Which branches.** Every branch tasks may push to, as the project's `project.yml` names them
  (read through `ProjectShape.of`), each asked for its rule.
- **The check.** With the rule on, the chosen `SigningKey` is compared by public key with
  `Forge.signingKeys(login)`, the forge's SSH signing keys only; a key not listed there is told in a
  warning beside the rule, with where to add it at the forge. A person whose forge holds only a GPG
  key is told that Porelo signs with SSH and needs an SSH signing key there.
- **The fakes.** `FakeForge` in `test/features/support/world.dart` gets a settable rule per branch;
  its `signing` list already stands for the forge's signing keys.
- **Red first.** In `test/features/project_from_repository.feature`, beside "every Porelo key and
  signer is listed": "a project's keys are listed with whose each is and what it is for", then
  "a signing key the forge does not take is warned about where a branch demands signed commits",
  and its pair with a key the forge does take and no warning. `test/app/forge_test.dart` gets a
  `GitHub` test for the rules reply, through `ForgeHttp`.

## Acceptance

- One view lists every key of a project with its owner and its purpose. Seen to fail: a scenario
  whose project has keys of a machine and of the person and finds one missing, or without its owner
  or purpose.
- When a branch rule demands signed commits, the person's signing key is checked against it and the
  outcome shown. Seen to fail: a scenario with such a rule and a person's key the forge does not take
  for signing that shows no warning, or one that shows a warning for a key it does take.

## To be checked

- Is the one list a survey in `ProjectForgeDialog`, or a view of its own reached from the project's
  page? (Agent Frontend's)
