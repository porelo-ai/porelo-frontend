# F81 — The Setup Script Checked By Its Signature

**Status:** Estimated; blocked by `sokar` [B99](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b99).
**Size:** M - one module and its scenarios here, but it follows a contract `sokar` [B99](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b99) sets (the
key, the signature's form, the versioned names) and a leg on a leased machine; it waits for [B99](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b99).

**What must be true.** A person preparing a new machine can be sure the setup script that runs as root
is Sokar's, for the version installed; one that cannot be verified is refused and nothing runs.

## Why

The script that runs is already the one shown: fetched once into root's own directory, its SHA-256
said beside what it would do, and nothing run where it differs. A checksum or versioned name from the
same host proves nothing against whoever controls that host. `sokar` [B99](https://github.com/sokar-ai/sokar/blob/main/issues/base/README.md#b99) signs the script and every
package with the packaging key and publishes that key's public half.

## Plan

- **The versioned name:** `MachineSetup.setupScript` in `lib/src/app/machine_setup.dart` names
  `sokar-setup-latest.sh` today. It becomes a name made from the version installed, and the
  signature's name beside it.
- **The check where it is fetched:** `MachineSetup._fetch` fetches the script and its signature
  into root's directory and checks one against the other with the public key this interface
  carries, written into the command, before anything runs the script. `_fetch` comes first in
  `listInstallable` as well as in `show`, and `--list` runs the script too, so both are covered.
- **The refusal:** a check that fails ends with an exit code of its own, as `notTheScriptShown`
  does; `MachineSetup.whatTheScriptSaid` says it in words, and `SetupRun.show` and
  `SetupRun.listPackages` in `lib/src/app/setup_run.dart` throw `MachineSetupFailed` with them.
- **The key:** the public half Sokar publishes is a constant in `lib/src/app/machine_setup.dart`,
  shipped with the interface, never fetched from the host that serves the script.
- **Red first:** a scenario in `test/features/adding_a_machine.feature`, "a setup script with a bad
  signature is refused, and nothing runs": after "a new machine whose root logs in", the machine
  holds a script that fails the check, and the scenario finds `--show` run. Then one where the
  fetched address holds `latest`.

## Acceptance

- The wizard fetches the script for the version it installs, by its versioned name, not the `latest`
  pointer. Seen to fail: a scenario in `adding_a_machine.feature` where `latest` is fetched.
- It checks the script's detached signature against the public key this interface carries, before
  `--show` runs it. Seen to fail: a scenario in `adding_a_machine.feature` where a script with a bad
  signature reaches `--show`.
- A script that fails the check is refused in words that say so, with nothing run on the machine.
  Seen to fail: the same scenario, where the words are missing or a command ran.
- The leased machine's leg runs against a signed script. Seen to fail: that leg, run on a leased
  machine, goes red.

## To be checked

- **The signature's form and the tool that checks it** on a fresh machine: `gpg`, `ssh-keygen -Y
  verify` or `openssl`, and whether that tool is there before Sokar is installed. (Agent Core's)
- **Which version the script is named by:** this interface's own, or the newest the index offers,
  which today is known only after the script has run `--list`. (Agent Core's)
- **Whether the check runs on the machine or here**, fetched by this computer and copied to the
  machine after it passed. (Agent Frontend's)
- **Which leg runs the setup script on a leased machine:** none in this repository's
  `integration_test` does today. (Agent Core's, for `sokar`'s legs)
