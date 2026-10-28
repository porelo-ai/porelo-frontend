# F221 — A Host's Vault Unlocked From The Secrets File

**Status:** Analyzed; placed with the bug fixes after the operator's tests of sprints 6 to 6i.
**Size:** S - Unlock the vault for a rented server fed from the secrets file as the stop is, and its tests.

**What must be true.** For a rented server, *Unlock the vault on <server>* asks the secrets file's master password
once in its terminal, as the stop's *Complete setup* does, and feeds the vault passphrase from the file's entry
`hosts/<project>/vault-passphrase` on a pipe into `porelo vault unlock --passphrase-stdin` on the server. The person
never sees, copies or types the vault passphrase; this program never holds it. A machine that is not a rented server
keeps today's terminal, where its passphrase is typed.

## Why

Seen in the operator's round (6e, after the reboot): Needs you showed *Messages wait · Vault locked*; *Unlock the vault
on sprint5 server* ran `porelo vault unlock` over ssh and asked *Vault passphrase:*. That passphrase was made by this
interface's stop and kept in the secrets file, where the person had never looked; the unlock dialog did not say where
it is. The operator: the interface made it, so the interface should take it from the file with the master password
typed once.

## Plan

- `unlockCommandFor` (`lib/src/app/vault_unlock.dart`), for a machine of kind `host`: the line
  `hostStopFeedCommand` builds for the stop, with the one need `vault` and the remote command
  `porelo vault unlock --passphrase-stdin` instead of `porelo-host-stop --stdin`; the secrets file and keepassxc-cli as
  the stop takes them (`SecretsFile`, the check for keepassxc-cli first).
- The terminal says before it starts: the master password of `~/Porelo/secrets.kdbx`, once; the vault passphrase
  comes from it.
- **Red first:** for a rented server the unlock line reads the passphrase from the file's entry and pipes it, and no
  argument holds a secret.

## Acceptance

- After a server's reboot, Unlock the vault asks the master password once and the vault opens.
- A machine that is not a rented server unlocks as today.
