# F201 — The Person's Own Drive Mounted In Their Account

**Status:** Backlog; blocked by [F197](README.md#f197), which takes the host's files off the drive.
**Size:** L - a new step of the machine setup that installs and signs in a third-party client in a user's account,
with a download to verify and a login terminal; no contract of the daemon or of `porelo-host`.

**What must be true.** A person who works on a machine with Porelo - one they set up, or one an administrator set up
for them - can mount their own Tresorit drive in their own account there, as an optional part of the setup the
interface does for a user. It is never in Porelo's account, has nothing to do with renting a host or its `up`, and a
user without one is asked nothing about Tresorit.

## Why

The operator's decision (2026-10-27): the drive leaves the host's setup wholly (`porelo-host`
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
- **Red first:** a test of `SetupRun` that a user without a drive is asked nothing about Tresorit and runs no step for
  it, and one that a chosen drive's commands run as that user and never as root or Porelo's account.

## Acceptance

- Rented without anything of Tresorit: the host comes up, and no Tresorit client or login is installed or asked.
- A user set up with a drive on a machine: the tresor syncs in that user's home, and another account cannot list it.
- Seen to fail: the first test red against today's host dialog, which always asks for the drive.

## To be checked

- How Tresorit's Linux client installs into one user's account, and what digest its download publishes; without one,
  the download cannot be checked as the rules ask, and that is said in the channel before anything is built.
- Whether the client's login works in a terminal over ssh without a desktop session.
