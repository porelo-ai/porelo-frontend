# F140 — The Host's Files Written Into The Person's Drive

**Status:** Analyzed.
**Size:** M - a folder found once per project, two files written there, and one of them encrypted
for a drive that is not end to end.

**What must be true.** Where the interface runs, it writes the files the host reads from the
person's drive - the WireGuard key and the machine file - straight into that drive's folder on the
desktop, which the desktop already syncs. The person copies nothing by hand. It holds for every kind
of drive: Tresorit's, and OneDrive's ([F139](README.md#f139)).

## Plan

- **A project's drive folder, chosen once and kept.** *Put this project on a server…*
  ([F135](README.md#f135)) asks for the folder of the project's tresor on this computer, with the
  system's folder picker. The folder is offered first where it can be read without guessing: on
  Windows `%OneDrive%` and `%OneDriveCommercial%`, which the OneDrive client sets. Nothing is read
  out of another program's settings. The choice is kept in the interface's own settings for the
  project, never in its `project.yml`, and can be changed there. Without a folder, the dialog says
  which files to copy and where, as today.
- **The kind of drive is the person's to say**, beside the folder: *encrypted end to end*
  (Tresorit) or *not* (OneDrive and any other). The interface does not infer it from a path.
- **What is written, under `porelo-host/` in that folder:**
  - `wireguard.key`, made here with `wg genkey`'s format (32 random bytes, base64), for the host's
    end. Its public half goes to `up` as `--vpn-peer-public-key`, as today.
  - `machine.yml`, which the host reads with `porelo project inventory --machine-file`
    (porelo-host's HO02). Its `keys` paths are relative to it, and it names only what lies beside it.
  - **Nothing is written over:** a file that is there already and differs is kept, and the dialog
    says so and names it. The person removes it or chooses another folder.
- **For a drive that is not end to end,** `wireguard.key` is written as `wireguard.key.age`, in the
  [age](https://age-encryption.org) format, which Ubuntu and Fedora package. The host decrypts it with
  `age`. What it is encrypted to is Q2. The interface says, beside that kind, that the drive's
  provider and the company's admins could read what lies there otherwise, and that the key is
  therefore written encrypted.
- **The command line stays as it is.** `porelo-host` only reads its options; the files are the
  interface's to write before `up`, and a person without the interface writes them by hand.
- **Tests:**
  - the folder kept per project;
  - the two files written, and a differing file kept and named;
  - the encrypted file decrypted back by the same format's reference `age` in the test, seen red
    with a changed byte;
  - no key ever in a log line or a step.

## Acceptance

- On Linux and Windows, *Put this project on a server…* with a chosen folder writes both files there.
  `up` then finds the key where the drive brings it, without a hand copy (with porelo-host's side).
- For a drive marked not end to end, only `wireguard.key.age` lies in the folder, and the host's
  `age` decrypts it.

## Open questions

- **Q1 - how the folder is found.**
  - **(a) proposed:** the person picks it once per project, with Windows' OneDrive folders offered
    first.
  - **(b):** read the Tresorit app's and GNOME Online Accounts' own settings to find the folders.
    That is undocumented and changes with their versions.
- **Q2 - what the encrypted key is encrypted to.**
  - **(a) the operator's shape:** an age identity made here (`AGE-SECRET-KEY-1…`), the key
    encrypted to its recipient. The identity is kept in the system's secret store as `porelo-host
    key set` keeps the provider's key, and given to the host only at the stop on standard input:
    one more answer, `driveKeyIdentity`, beside the vault's. Not a passphrase, since `age` asks for
    one only at a terminal, which the host has not at the stop. Measured on Ubuntu 26.04's `age`
    1.2.1: a passphrase without a terminal is refused, and `age -d -i -` takes an identity from a
    pipe.
  - **(b):** the host's own ssh host key, which `up` makes here before renting. age encrypts to an
    `ssh-ed25519` key, so the host decrypts with what it already holds, and no secret passes at the
    stop. But the file is bound to that one host, and written anew each time a host is rented.
  - **(a) is proposed:** it survives a new host, and the stop already carries secrets.

## To be checked

- **Encrypting in Dart:** the pure-Dart age packages on pub.dev (`dartage`, `dage`) are small and
  little used. Weigh them against carrying the `age` program from its release by its digest, on
  Linux and Windows, and read the chosen one against age's test vectors.
- **GNOME Online Accounts' OneDrive** on Linux mounts through gvfs under `/run/user/<uid>/gvfs/`.
  Read whether a file written there is synced before the host reads it, and say so in the dialog if
  not.
- **The host's side** is porelo-host's: reading `wireguard.key.age` and decrypting it with what the
  stop gave, `age -d -i` with the identity through a pipe or a 0600 file on a `noexec` tmpfs (HO16),
  and reading the machine file
  (HO02).
