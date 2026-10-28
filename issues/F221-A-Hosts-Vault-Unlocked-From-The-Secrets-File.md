# F221 — A Host's Vault Unlocked From The Secrets File

**Status:** Implementing; built, not yet published.
**Size:** S - Unlock the vault for a rented server fed from the secrets file as the stop is, the vault's Make refused
on a rented server, and their tests; about 2 hours.

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

## Every place a value of the secrets file reaches a rented server

What the person types for each, read from the code:

| Place | What is typed | State |
|---|---|---|
| Put it on a server, step Your secrets file: Open it now / Make it now (`host_dialog.dart` `_openTheSecretsFile`, `SecretsFile.prepareHost`) | the file's master password | master password only |
| Complete setup at a stop, with the secrets file set (`host_stop_dialog.dart`, `hostStopFeedCommand`): `vault`, `vault-new`, `wireguard`, `keys`, `forge-certificate` (signed with the CA key in the file), `forge-central-token` | the file's master password, once | master password only |
| Complete setup at a stop **without** a secrets file in the settings | the vault passphrase, typed in the host's own terminal | only for a setup that names no secrets file, which Put it on a server no longer makes; stays as the way for such a setup |
| Bring the VPN up / take it down (`host_vpn_dialog.dart`) | the laptop's sudo password; the VPN key comes from the system's secret store, never typed | no value of the file typed |
| **Unlock the vault on <server>** from Needs you, and **Open it with its passphrase** in the server's vault view (both `unlockCommandFor`) | the vault passphrase, `hosts/<project>/vault-passphrase`, copied by hand | **needs a change: this issue** |
| **Make one** in the vault view of a rented server without a vault (`makeCommandFor`) | a new vault passphrase the file never learns | **needs a change: this issue**; a server's vault is made by its setup from the file |

Values the person brings from outside and keeps in the file themselves once (the central forge's token in
`shared/forge-central-token`) are put there in KeePassXC, never typed into this interface. Tokens and agent logins
typed for a machine's own vault (`porelo vault put`, `porelo vault login`) are not values of the secrets file.

## Plan

- `unlockCommandFor` (`lib/src/app/vault_unlock.dart`), for a machine of kind `host`: the line
  `hostStopFeedCommand` builds for the stop, with the one need `vault` and the remote command
  `porelo vault unlock --passphrase-stdin` instead of `porelo-host-stop --stdin`; the secrets file and keepassxc-cli as
  the stop takes them (`SecretsFile`, the check for keepassxc-cli first).
- `makeCommandFor`, for a machine of kind `host`: null, and the vault view says the server's vault is made by its
  setup (Complete setup), from the secrets file.
- The terminal says before it starts: the master password of `~/Porelo/secrets.kdbx`, once; the vault passphrase
  comes from it.
- **Red first:** for a rented server the unlock line reads the passphrase from the file's entry and pipes it, and no
  argument holds a secret.

## Acceptance

- After a server's reboot, Unlock the vault asks the master password once and the vault opens.
- Open it with its passphrase in a rented server's vault view does the same.
- A rented server's vault view offers no Make one.
- A machine that is not a rented server unlocks and makes its vault as today.
