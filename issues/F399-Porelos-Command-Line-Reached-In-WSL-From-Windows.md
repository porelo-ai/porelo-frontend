# F399 — Porelo's Command Line Reached In WSL From Windows

**Status:** Review.
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
- `lib/src/app/run_porelo.dart`: `runPorelo`, a `RunHere` for `porelo` that on Linux is `runHere`, and on Windows
  runs `Wsl.runIn(distribution, ['porelo', ...arguments])` in the WSL distribution that is this computer
  (`Machine.thisComputersDistribution`, [F398](README.md#f398)), standard input passed through and its output read as
  UTF-8 (`runHere` takes an `encoding`); with none it refuses with words that name *Add a machine*, *WSL*, and runs
  nothing. The five places take it instead of `runHere`.
- A Windows path the command line is given (a drive path or a share, such as a KeePassXC database or a key file in
  key recovery) goes as the distribution names it, by `wslpath -a`, run there; one it cannot name is refused, and
  Porelo is not run.
- `certifyHere` still runs `ssh-add` and `ssh-keygen` of this computer: certifying on this computer signs with the
  key in the person's own agent, which is not Porelo's command line.
- **The test that goes red first:** `test/app/run_porelo_test.dart` with a Windows `Desk` and a stand-in for running
  `wsl.exe`: `porelo org show --json` is run as `wsl.exe -d Ubuntu --exec porelo org show --json` with its standard
  input, read as UTF-8, never as `porelo` here; a drive path goes as `wslpath -a` names it and a share it cannot name
  runs nothing; with no distribution it refuses by name and runs nothing. It guards a person's organization
  change sent nowhere, or to another distribution than the one they watch.

## Found in the reading

- A refusal before Porelo was started (no distribution, a path it cannot reach) was taken by the organization pages
  for a run whose outcome is unknown, kept a change waiting for an answer, and was reworded by the credentials and the
  identity as "could not be run" or an unconfirmed result: it is `PoreloNotStarted` now, said with its words, a
  refusal that made nothing (`answered`, exit 127 for the identity).
- The identity's KeePassXC commands and key recovery run Porelo in a terminal the person sees, and still started it on
  Windows itself: `poreloCommandHere` runs them in the distribution too, with their paths named there.
- The forge token's hand-over to the vault asked a Linux socket on Windows: it asks this computer, the distribution.
- A forge address such as `g:/owner/repository.git` was taken for a drive path: only a drive with a backslash, or a
  share, is a path.
- A directory or environment given for a run in WSL would have been dropped quietly: it is refused.
- Declined: the five-minute limit's words name `wsl.exe -d` rather than `porelo` on Windows; it still says the command
  gave no answer and was ended.

## Acceptance

- On Windows with a WSL machine connected, *My projects* lists the organization's projects, and identity, key
  recovery, a forge's key check, the vault's tokens and certifying run in that distribution, the identity's and key recovery's terminals too, and the forge token reaches its vault.
- With none connected, each says to add the WSL machine, and runs nothing.
- Linux runs as before.

## To be checked

- Whether KeePassXC and the ssh agent the identity commands use are reachable inside the distribution as on Linux, in
  the operator's walk on Windows: the window passes no environment to the distribution, so an agent there is the
  distribution's own.
