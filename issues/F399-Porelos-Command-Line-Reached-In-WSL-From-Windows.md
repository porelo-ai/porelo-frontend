# F399 — Porelo's Command Line Reached In WSL From Windows

**Status:** Estimated.
**Size:** M - one way to run Porelo's command line that knows the WSL distribution, taken by the six places that run
it, with Windows paths handed over as the distribution reads them, and their tests.

**What must be true.** On Windows every part of the window that asks Porelo's command line - the organization pages,
the person's identity and key recovery, a forge's key check, the vault's forge tokens and certifying a task again -
asks it in the person's WSL distribution, through `wsl.exe`, and says so plainly where no distribution is connected.

## Why

The window reaches a daemon in WSL through `wsl.exe`, but six places start `porelo` on the computer itself with
`runHere` (`Process.start('porelo', ...)`). Windows has no `porelo`, so each fails before it asks anything, and the
organization source says "Porelo's command line could not be started here, so nothing was asked." on *My projects*.

## Plan

- The places, each starting `porelo` here today:
  - `lib/src/app/porelo_organization_source.dart` (`PoreloOrganizationSource`, made in `lib/main.dart`): *My
    projects*, the organization and project pages and every change made there.
  - `lib/src/app/core_credentials.dart` (`CoreCredentials`): forge tokens put into the vault
    (`forge_connection.dart`, `organization_access_dialogs.dart`).
  - `lib/src/app/identity.dart` (`Identity`, behind `IdentityModel`, `CoreHostAdminProof`): the person's identity,
    rotation and key recovery (`identity_view.dart`, `key_recovery_dialog.dart`, `host_access_adapters.dart`).
  - `lib/src/app/forge_key_check.dart` (`ForgeKeyCheckCli`): whether a forge holds the person's key.
  - `lib/src/app/task_certifying.dart` (`certifyAgainRunner`, run from `shell.dart`): certifying a task again.
  - `lib/src/app/fleet_backend.dart` (`_startCore`, `porelo host unlock`): opening a host card's vault; host cards are
    refused on Windows already (`Machine.whyNotReachableOn`), so this one is said, not routed.
- `lib/src/app/run_porelo.dart`: a `RunHere` for `porelo` that on Linux is `runHere`, and on Windows runs
  `Wsl.runIn(distribution, ['porelo', ...arguments])` in the WSL machine the window watches (the one chosen where
  there are several), standard input passed through; with none it refuses with words that name *Add a machine*,
  *WSL*. The six places take it instead of `runHere`.
- A Windows path the command line is given (a KeePassXC database, a key file to write or read in key recovery) goes as
  the distribution names it, by `wslpath -a`, run there; one that cannot be named is refused, never guessed.
- **The test that goes red first:** `test/app/run_porelo_test.dart` with a Windows `Desk` and a stand-in for running
  `wsl.exe`: `porelo org show --json` is run as `wsl.exe -d Ubuntu -- porelo org show --json` with its standard input,
  never as `porelo` here; with no WSL machine it refuses by name and runs nothing. It guards a person's organization
  change sent nowhere, or to another distribution than the one they watch.

## Acceptance

- On Windows with a WSL machine connected, *My projects* lists the organization's projects, and identity, key
  recovery, a forge's key check, the vault's tokens and certifying run in that distribution.
- With none connected, each says to add the WSL machine, and runs nothing.
- Linux runs as before.

## To be checked

- Whether KeePassXC and the ssh agent the identity commands use are reachable inside the distribution as on Linux, in
  the operator's walk on Windows.
