# F201 — The Person's Own Drive Mounted In Their Account

**Status:** Review; parts A (the drive out of the host dialog) and B (the machine setup's drive step) published
2026-10-28 (Build green on `46deaa8`) with the collection at `porelo-host` 0.5.6, which carries
[HO38](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho38); not yet run on a rented host or
against Tresorit's real installer.
**Size:** L - a new step of the machine setup that installs and signs in a third-party client in a user's account,
with a download to verify and a login terminal; no contract of the daemon or of `porelo-host`.

**What must be true.** A person who works on a machine with Porelo - one they set up, or one an administrator set up
for them - can mount their own Tresorit drive in their own account there, as an optional part of the setup the
interface does for a user. It is never in Porelo's account, has nothing to do with renting a host or its `up`, and a
user without one is asked nothing about Tresorit.

## Why

Decided: the drive leaves the host's setup wholly (`porelo-host`
[HO38](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho38)) and belongs to the users' own
accounts, each mounting their own drive.

## Plan

- **Read in today's code:** the machine wizard's `SetupRun` (`lib/src/app/setup_run.dart`) walks `key`, `where`,
  `prepare`, `reach`, `vault` and `harden`, and adding a user to a machine prepared before walks the same steps; the
  work user's steps run over ssh as that user, the vault's in a terminal as that user. Nothing installs a
  third-party client in a user's account today, and the drive's step lives in the host dialog
  (`lib/src/ui/host_dialog.dart`, *The drive*), which this issue takes out of it.
- **The step:** an optional `drive` step after `vault`: none, or a tresor and the folder it syncs into in the user's
  home. With one, the client is installed in the user's account from its verified download, its login runs in a
  terminal as that user (the provider's own login, never a form here), the tresor is synced, and the user gets the
  linger the client's daemon needs.
- **The host dialog:** *The drive* step and its settings (`Settings` tresor and synced folder) leave it; the host's
  files no longer go through a drive ([F197](README.md#f197)).
- **Part A, built:** the host dialog's step *The project* holds the signing key and the vault entries' files only;
  the synced folder, its picker and the tresor's name are gone, and `porelo-host up` takes no `--tresor` (refused
  as an option). A drive folder remembered from an earlier setup is still read for a host key it holds, which the
  secrets file takes over. A kept record without a tresor is valid, and none passes one on.
- **From part A's harm reading (seven findings, five taken):** a drive folder remembered from an earlier setup is
  shown on *The project*, with *Forget it*, so a refusal about a key it holds can be acted on; a test reads such a
  folder again; the walk no longer looks for drive answers, and its rework for the secrets file and a host without a
  drive is [F206](README.md#f206). **The carried collection** (`porelo-host` v0.5.5) still mounts a drive and needs a
  tresor: part A goes out only with a `porelo-host` release carrying [HO38](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho38) and the collection's pin moved to it, in
  the same push. **Declined, with the reason:** a test that `up` writes no tresor into the inventory cannot be made
  to fail by passing one, since `HostPlan` has no such field any more; the command line's refusal of `--tresor` is
  tested.
- **Part B, built:** `SetupStep.drive`, after the vault, optional (Next leaves it with nothing run). *Install
  Tresorit for <user>* fetches the installer here, finds the pinned CA (`TresoritInstaller`), sends the installer,
  its signature and the two certificates into a `0700` folder of the user's home (base64 on standard input), and runs
  the check there (`TresoritInstaller.checkScript`); only then the installer, `--update-v2 ~/.local/share/tresorit`,
  and the daemon as the user's unit. The sign-in is Tresorit's own, in a terminal as that user, with the e-mail
  refused unless plain; who is signed in is asked of the client afterwards, never read from the terminal. *Sync it*
  starts the tresor into `~/Tresorit/<tresor>`. Its decision is in `doc/decisions.md`.
- **From part B's harm reading (seven findings, six taken):** the signature covers the installer from line 3 on, but
  the file runs from line 1, so line 1 may only be `#!/bin/sh` (or `#!/bin/bash`) and line 2 only `SIGNATURE=` with
  hex, checked when it is read here and again on the machine before it runs; the folder sent to goes also where the
  ssh that would run the check fails; the folder is quoted in the check; the drive's state is kept with the run, and
  the sign-in waits for the machine to answer; `systemctl` runs by its path; the decision says what the signature
  covers. Tests now see the user, the order and a resumed run. **Declined, with the reason:** `-no-CAstore` needs
  OpenSSL 3, which every machine Porelo sets up has (Ubuntu 26.04, Fedora); an older one refuses, closed.
- **From the reading of that fix (four findings, three taken):** found nothing that runs an unsigned command, a `\r`,
  a NUL or a longer first line among them; tests now read what the run kept as it went, refuse an absent call that an
  index of -1 let pass, and see the refusal still said before *Forget it* and the start going on after. **Declined,
  with the reason:** the drive's state is kept after every action (`_doing` keeps the run), and a resumed run reaches
  the drive step only after `reach`, which sets the machine again.
- **Red first:** a test of `SetupRun` that a user without a drive is asked nothing about Tresorit and runs no step for
  it, and one that a chosen drive's commands run as that user and never as root or Porelo's account.

## Acceptance

- Rented without anything of Tresorit: the host comes up, and no Tresorit client or login is installed or asked.
- A user set up with a drive on a machine: the tresor syncs in that user's home, and another account cannot list it.
- Seen to fail: the first test red against today's host dialog, which always asks for the drive.

- **The download's check (decided):** Tresorit publishes no
  digest for its Linux installer. The installer carries its own signature instead: line 2 `SIGNATURE=`, RSASSA-PSS
  SHA-512 over everything from line 3 on, and line 3 `CERT_CHAIN=`, the chain. It is taken only when the chain holds
  the pinned CA (SHA-256 `AC:46:31:BC:…:3D:D2:42`), that CA issued the code-signing certificate, the certificate is
  valid now, and the signature covers the rest, as `porelo-host`'s `tresorit_installer` module took it until
  [HO38](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho38). The signature pins more than a
  digest would: every later installer Tresorit signs passes, and nothing else does. The check runs on this desktop
  before any byte of the installer runs anywhere.

## To be checked

- Read in `porelo-host`'s drive role before [HO38](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho38) (348921c), to be seen on a machine: the installer puts the client into
  one account, its daemon that account's user unit `tresorit-daemon.service`, kept up by its linger; the login works in
  a terminal over ssh without a desktop session, `tresorit-cli login --email <e-mail> --password-on-stdin` as the
  account with `XDG_RUNTIME_DIR` set (client 3.5.1300.4870), asking `Password:` without echo and then the one-time
  code.
