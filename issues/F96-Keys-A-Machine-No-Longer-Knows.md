# F96 — Keys A Machine No Longer Knows, Found By Their Title

**Status:** Analyzed.
**Size:** M - one module and its scenario, plus a measurement on the VM against Sokar's handover;
no contract changes on this side.

**What must be true.** Clearing a machine also removes, at the forge, the keys the machine no longer
knows itself, found by their title, so none stay behind.

## Why

Clearing a machine or a project already takes its keys at the forge and its line in
`machine-signers` in one step, said thing by thing; it finds only the keys the machine still names.

## Plan

- **Where it is today.** `MachineClearing.clearIt` in `lib/src/app/machine_clearing.dart` calls the
  machine's `clear`, then `removeAtTheForge` in `lib/src/app/machine_binding.dart` for each
  `MachineDeployKey` in `Cleared.keys`, matched at the forge by public key; `_takeOutTheSigner`
  takes the `machine-signers` line out. A key the machine forgot is never asked for.
- **Which repositories.** The repositories named by `Cleared.keys`, plus, for each project the
  preview lists as followed, its own repository and its work repositories as `ProjectShape.of`
  reads them (`MachineBinding.survey` walks the same set). Each is asked `Forge.deployKeys`.
- **Which keys.** A `ForgeDeployKey` whose title is `sokar <machine> <project>/<repository>` with
  this machine's name, and that was not already removed by public key, is removed with
  `Forge.removeDeployKey` and said as "Removed <title> from <repository>, which <machine> no longer
  named." For a project clearing, only titles with that project.
- **The machine's name in titles.** Read off the titles of `Cleared.keys` where there are any; a
  machine that names no key leaves nothing to match by, and the report says so.
- **The preview.** `look` lists the found keys too, so what goes is shown before it goes, as today.
- **Red first.** In `test/features/project_from_repository.feature`, beside "a machine is cleared
  in one step": "a key at the forge the machine no longer names is found by its title and
  cleared" - `FakeForge` holds `sokar vm api/api` that the fake's `clear` does not name; after
  clearing it is gone and the report names it. The existing step "the forge holds the key ... from
  a machine that is gone" sets such a key up already.
- **On the VM.** Then a scenario in `integration_test/reaching_a_machine.feature`, run against
  Sokar's handover: bind, make the machine forget a key, clear, and find neither the key nor the
  `machine-signers` line.

## Acceptance

- Keys at the forge whose title names the machine are found and cleared with it, though the machine
  does not name them. Seen to fail: a scenario with such a key at the forge that is still there after
  clearing, or not listed among what was cleared.
- The clearing is measured on a machine against Sokar's handover. Seen to fail: on the VM, a key of
  the cleared machine still at the forge, or its line still in `machine-signers`.

## Open questions

- Is the VM measured against real GitHub with test repositories, which waits for the operator's
  token as [F59](README.md#f59) does, or against a stand-in forge beside the real daemon? (the operator's)
- Should keys titled for this machine in repositories outside its projects (all the token reaches)
  be looked for too, at one request per repository? (the operator's)

## To be checked

- The title carries the machine's own name, which may differ from what the person calls it here;
  could `Clear`'s answer carry that name, so a machine that names no key can still be matched?
  (Agent Core's)
