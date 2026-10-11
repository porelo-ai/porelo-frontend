# F62 — An Organisation's Policy Is Shown

**Status:** Analyzed; blocked by Sokar's part of `sokar-project` PJ16.
**Size:** M - one contract change read from `sokar` (the policy and its refusals) across the
machine, starting work, the clearance prompt and following, with the mock daemon and the docs; waits
for `sokar`'s part of PJ16.

**What must be true.** A person on a machine whose organisation set a policy sees that it is in
force and what it allows, and is told why when it refuses something, rather than being surprised.

## Why

`sokar-project` PJ16, *An organisation decides which providers its machines use*. Sokar's part is
the policy file, its refusals and `doctor`; the contract carries none of it yet: not the policy, its
refusals, or whether a prompt may be allowed.

## Plan

- **The contract first:** once `sokar` carries it, the policy is read in
  `lib/src/client/sokar_client.dart` into a model in `lib/src/client/models.dart`, answered by
  `lib/src/mock/mock_daemon.dart`, and written into `doc/Backend-API.md` and `doc/Contract-Gaps.md`.
- **With the machine:** under `MachineTitle` in `lib/src/ui/machine_view.dart`; nothing where there
  is none.
- **Starting work:** `StartWork` (`lib/src/app/start_work.dart`) offers only the `providers` the
  policy allows; a start refused for its provider is shown through `RefusalView`
  (`lib/src/ui/refusal.dart`), naming the policy.
- **The clearance prompt:** `TaskTile` in `lib/src/ui/attention_view.dart` offers allow and deny
  through `onDecide`; under a policy with no allow it offers deny only, and says why.
- **Following and `online`:** `ProjectFollowing.follow` (`lib/src/app/project_following.dart`)
  with `Checking.unverified`, and a project whose `securityClass` is `online`, refused in the
  machine's words.
- **Red first:** a scenario in `test/features/task_creation.feature` starting work under a policy
  that allows one provider.

## Acceptance

- **A machine's policy is shown** with the machine: that one is in force, and what it allows — the
  providers, and whether an unverified follow, an allow at a clearance prompt and the `online` class
  are refused. A machine without one shows nothing of it. Seen to fail: widget tests of a machine
  with a policy and one without.
- **Starting work offers only the providers the policy allows**, and a start refused for its
  provider says so in the machine's words, naming the policy. Seen to fail: a scenario starting work
  under a policy that allows one provider, and one refused for its provider.
- **A clearance prompt under a policy with no allow offers only deny**, saying why; it never offers
  an allow the machine would refuse. Seen to fail: a widget test of the prompt under such a policy.
- **Following unverified, and a project of class `online`**, are refused in the machine's words,
  naming the policy. Seen to fail: a scenario for each refusal.

## To be checked

- **How the contract carries the policy**: a method of its own or fields on what a machine says
  about itself, and the error a refusal for it comes as. (Agent Core's)
