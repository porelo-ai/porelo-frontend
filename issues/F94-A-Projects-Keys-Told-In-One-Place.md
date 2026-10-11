# F94 — A Project's Keys Told In One Place

**Status:** Analyzed.
**Size:** M - a new question to the forge, the binding's survey and its dialog, and scenarios with a
fake branch rule; nothing another repository reads changes.

**What must be true.** A person sees a project's keys in one place, whose each is and what it is for,
and learns whether their own signing key satisfies a branch rule that demands signed commits.

## Why

The forge's signing keys are already found for the person and all pinned at binding, so binding asks
for no key again; what each key is for is not yet told together.

## Plan

- **Today's pieces.** `MachineBinding.survey` in `lib/src/app/machine_binding.dart` already
  gathers the Sokar deploy keys at the forge (`keys`) and the `machine-signers` lines (`signers`);
  `ProjectForgeDialog` in `lib/src/ui/project_forge_view.dart` shows them as two lists behind
  "Machines that have keys to it". The person's keys come from `ProjectWorkspace.signingKeys` and
  `Forge.signingKeys`; the keys a machine pinned are `Followed.signers` in
  `lib/src/client/models.dart`.
- **One list.** `survey` also reads the person's signing keys at the forge and what the machine
  pinned, and answers one list of records: the key (title or fingerprint), whose it is (a machine
  by name, or the person), and what it is for (fetching read-only, pushing, signing the person's
  commits, signing a machine's messages). The dialog renders that list in place of the two;
  "Remove" stays on the rows that have it today.
- **The branch rule.** `Forge` in `lib/src/app/forge.dart` gains a question: whether a branch of a
  repository requires signed commits. `GitHub` answers it from the rules that apply to the branch
  (`GET /repos/{owner}/{repo}/rules/branches/{branch}`, a `required_signatures` rule), which a
  token that only reads the repository may call; a classic branch protection needs admin and is
  read only where the token has it.
- **The check.** With the rule on, the chosen `SigningKey` is compared by public key with
  `Forge.signingKeys(login)`; a key not listed there is told in a warning beside the rule, with
  where to add it at the forge.
- **The fakes.** `FakeForge` in `test/features/support/world.dart` gets a settable rule per branch;
  its `signing` list already stands for the forge's signing keys.
- **Red first.** In `test/features/project_from_repository.feature`, beside "every Sokar key and
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

- Which branch is checked: the default branch only, or every branch a task may push to, as the
  project's `project.yml` names them? (the operator's)
- Does "signed" accept GPG keys too? The forge's GPG keys are another listing, and nothing here
  signs with GPG today. (the operator's)
- Is the one list the survey in today's dialog, or a view of its own reached from the project's
  page? (Agent Frontend's)
