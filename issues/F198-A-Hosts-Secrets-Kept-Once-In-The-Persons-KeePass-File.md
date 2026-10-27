# F198 — A Host's Secrets Kept Once In The Person's KeePass File

**Status:** Implementing.
**Size:** L - a new part beside the host dialog (the file's entries, its terminal, a first-use step) and a package
dependency, no contract of the daemon, but one with `porelo-host` through [F199](README.md#f199).

**What must be true.** The secrets a person needs to put a project on a host are kept once, in `secrets.kdbx` where
the person chooses, a KDBX 4 file they can open with KeePassXC: one master password for all hosts; a group `shared`
(the lasting forge CA's key, the forge password) and a group per host under `hosts/<name>` (its
WireGuard key, its vault passphrase). The file is unlocked on the person's desktop only, never on a host, and no
secret lies in the clear on the drive. The drive's (Tresorit's) login stays out of it
altogether (decided).

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
  the interface holds none of them (decided: the master password and every entry stay out of the interface; at the
  first host the lasting forge password is typed in that terminal and goes into the file there).
- **KeePassXC comes with the interface (decided):** the Linux packages depend on `keepassxc-minimal` (Debian,
  Ubuntu; 2.7.10 on Ubuntu 26.04) or `keepassxc` (Fedora), installed by apt or dnf with the interface, and the
  interface calls that `keepassxc-cli` by its absolute path. A person's own KeePassXC, snap or not, stays theirs for
  opening the file. Measured: the snap's `keepassxc.cli` may not write in `/tmp` or a hidden folder of the home
  (`Zugriff verweigert`), which the packaged one does not share; 2.7.10's manual page lists `open` (a shell on one
  unlocked file), `show`, `export` (XML or CSV to standard output), `db-create`, `mkdir` and `add`.
  Windows and macOS are [F200](README.md#f200); until then *Put this project on a server…* is unavailable on
  Windows with its reason, since a server's keys are kept in the file (found by the Windows Build after the push).
- **The entries the interface relies on**, so a person's own file works: `shared/forge-password`,
  `shared/forge-ca-key`, `hosts/<project>/wireguard`, `hosts/<project>/vault-passphrase`, each a KeePass entry whose
  password field holds the secret, named by its path below the root group (whose own name is localized). A missing
  entry is said by its name, never guessed.
- **The terminal's script, so no secret enters the interface:** a `bash` script the interface writes, with no secret
  in it, runs in the interface's terminal on this desktop. It asks the master password once with `read -rs` and
  hands it to each `keepassxc-cli` call on standard input with the shell's builtin `printf`, never as an argument or
  in the environment of another program. The host's WireGuard key is made there (`wg genkey`) straight into
  `hosts/<project>/wireguard`, and only its public half (`wg pubkey`) is written to a `0600` file in a private folder
  of the interface, which `HostTunnel` reads; a new host's vault passphrase is generated into
  `hosts/<project>/vault-passphrase` by `keepassxc-cli add -g`. The person's own half stays in the system store, as
  today.
- **Where it lies (decided):** the person chooses the file at first use, offered `~/Porelo/secrets.kdbx`, or a drive
  folder where one is set up; the interface keeps only its path in its settings, never a copy.
- **First use:** the host dialog's step *Your secrets file*, after *Your ssh keys*, names an existing file or where
  the script creates one (`keepassxc-cli db-create`, then the groups `shared`, `hosts` and `hosts/<project>`); a
  host's key already in the tresor is moved into the file in that script and then removed from the tresor. The file
  takes the place of the drive's `wireguard.key`, so it is opened only where a drive folder is chosen; without one
  the host's files are supplied by hand, as before.
- **Between 6d and 6e:** with the file, `wireguard.key` no longer goes to the drive, while the host still reads it
  there until `porelo-host` [HO37](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho37) takes it
  on standard input ([F199](README.md#f199)); so 6d is tested without a host, as its sprint says.
- **The package:** `packaging/nfpm.yaml.in` names `keepassxc-minimal` (deb) and `keepassxc` (rpm), and
  `wireguard-tools`, which the VPN action runs already and the script's `wg` needs: dependencies listed rather than
  derived from the ELF files, since the interface runs them by path; `AGENTS.md`'s
  packaging rule says so, and `test/packaging_test.dart` asserts it.
- **Red first:** a widget test that a run with the file never writes `wireguard.key` into the drive, and a test of
  the entry names against a file made with `keepassxc-cli` from a fixture.

- **Pushed only with the host's side:** with the file, setup writes no `wireguard.key` to the drive, and a host
  that still reads it there stops at its VPN step after it is rented. So this issue's code goes out only with
  [F199](README.md#f199) and once `porelo-host`
  [HO37](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho37) is published.
- **Declined from its harm reading, with the reason:** the master password is typed into the interface's own
  terminal, as every sign-in here is, and the words now say so rather than that it never passes through the
  program; the tests that run the real `keepassxc-cli` are skipped where none is installed, the Build among them,
  and each skip names why; the dialog's test does not tell a non-zero exit from a missing public half, since either
  refuses before anything is rented.

## Acceptance

- After setting up a host with the file, the drive holds no secret in the clear; KeePassXC opens the file and shows
  the host's group and `shared`.
- A second host takes `shared` from the same file and gets a group of its own.
- No secret appears in the interface's memory, settings, logs or arguments: measured by a scan of its settings and
  logs after a run, and by reading the code.
- Seen to fail: the first test red against today's `wireguard.key` in the tresor.

## Open questions

## To be checked

- A round trip: a file made by `keepassxc-cli` read back and an entry added, then opened by KeePassXC, in a folder
  the snap may reach (the drive).
- How a write is done while the person has the file open in KeePassXC, without losing either's change.
- The same on Windows (KeePassXC's own `keepassxc-cli.exe`) and on macOS.
