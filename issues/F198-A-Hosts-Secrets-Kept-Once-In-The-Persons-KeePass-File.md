# F198 — A Host's Secrets Kept Once In The Person's KeePass File

**Status:** Analyzed.
**Size:** L - a new part beside the host dialog (the file's entries, its terminal, a first-use step), no contract of
the daemon, but one with `porelo-host` through [F199](README.md#f199).

**What must be true.** The secrets a person needs to put a project on a host are kept once, in `secrets.kdbx` on
the person's drive, a KDBX 4 file they can open with KeePassXC: one master password for all hosts; a group `shared`
(the lasting forge CA's key, the forge password, the drive's login) and a group per host under `hosts/<name>` (its
WireGuard key, its vault passphrase). The file is unlocked on the person's desktop only, never on a host, and no
secret lies in the clear on the drive. The one-time code of the drive's login stays out of it.

## Why

`porelo-project` [PJ51](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj51), with the
operator's shape: one password to remember for setting up a host.

## Plan

- **Read in today's code:** the person's half of the WireGuard pair is in the desktop's system store
  (`HostFiles.keyName`, `SecretStore`), the host's half in the tresor (`porelo-host/wireguard.key`, written by
  `HostFiles.prepare`), and the drive's login and the vault passphrase are typed at each `up` in the host's terminal
  (`porelo-host-stop`, asked by `HostSession.needs`: `drive`, `vault`, `vault-new`).
- **AGENTS.md's rule decides where the master password goes:** "The interface takes no secret into a form of its
  own"; a password is typed into a terminal on the machine it is for. The file is this desktop's, so it is opened in
  a terminal here, by `keepassxc-cli`, and its entries go from there to where they are used ([F199](README.md#f199));
  the interface holds none of them. QF64 asks whether that stands.
- **Measured here:** `keepassxc-cli` 2.8.0 comes with the KeePassXC snap, and the snap may not write in `/tmp` or in
  a hidden folder of the home (`Zugriff verweigert`), so the file lives on the drive, never under `~/.porelo`; the
  Dart package `kdbx` 2.5.0 (authpass, August 2026) reads and writes KDBX 4, with Argon2 through a native library.
- **The entries the interface relies on**, so a person's own file works: `shared/drive-login`,
  `shared/forge-password`, `shared/forge-ca-key`, `hosts/<name>/wireguard`, `hosts/<name>/vault-passphrase`, each a
  KeePass entry whose password field holds the secret. A missing entry is said by its name, never guessed.
- **First use:** a step before *The drive* when no file exists: create it in a terminal (`keepassxc-cli db-create`),
  then put in what is already known (the WireGuard key from the tresor, then removed from it); a person with an
  existing file names it.
- **Red first:** a widget test that a run with the file never writes `wireguard.key` into the drive, and a test of
  the entry names against a file made with `keepassxc-cli` from a fixture.

## Acceptance

- After setting up a host with the file, the drive holds no secret in the clear; KeePassXC opens the file and shows
  the host's group and `shared`.
- A second host takes `shared` from the same file and gets a group of its own.
- No secret appears in the interface's memory, settings, logs or arguments: measured by a scan of its settings and
  logs after a run, and by reading the code.
- Seen to fail: the first test red against today's `wireguard.key` in the tresor.

## Open questions

- **QF64:** The master password typed in a terminal here, with `keepassxc-cli` as the only reader of the file, as
  AGENTS.md's rule asks; or a field in the interface, reading the file with the `kdbx` package, which changes that
  rule? Recommended: the terminal.
- **QF65:** KeePassXC as a requirement on the desktop (the person has it, since they open the file with it), or the
  file written by the interface itself? Recommended: KeePassXC required, found as `keepassxc-cli` or the snap's
  `keepassxc.cli`, and said plainly when missing.

## To be checked

- A round trip: a file made by `keepassxc-cli` read back and an entry added, then opened by KeePassXC, in a folder
  the snap may reach (the drive).
- How a write is done while the person has the file open in KeePassXC, without losing either's change.
- The same on Windows (KeePassXC's own `keepassxc-cli.exe`) and on macOS.
