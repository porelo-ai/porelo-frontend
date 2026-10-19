# F133 — A Provider's Key In The System's Secret Store

**Status:** Review.
**Size:** S - two platform stores from pure Dart, each proven in the Build's own job.

**What must be true.** The provider's key is entered once, in the interface or by `porelo-host
key set` from standard input, and lies only in the system's own store: Credential Manager on
Windows, Secret Service on Linux. The interface and the command line read
the same entry. It is never in a file, a log or a command line.

## Plan

- `SecretStore` in `packages/porelo_host/`, pure Dart, one implementation per system:
  - **Linux:** the Secret Service over D-Bus (`package:dbus`), in the default collection, as
    `lib/src/app/keystore.dart` uses it through libsecret today;
  - **Windows:** `CredWriteW`/`CredReadW` through `package:win32`'s FFI;
  - macOS is left out for now, by the operator's decision; it comes with the interface on macOS,
    [F109](README.md#f109).
- One service name and account per provider, so the interface (through `flutter_secure_storage`
  today) and the command line meet. Where `flutter_secure_storage`'s naming differs, the interface
  uses this store for the provider's key.
- **The red test first:** write, read and remove on each system in the Build's own job for it,
  run red with a read under another name.

## Built so far

- `SecretStore` with `SecretServiceStore` (D-Bus, `package:dbus` 0.8.0) and `CredentialManagerStore`
  (`package:win32` 6.4.0), and `porelo-host key set|forget PROVIDER`, the key on standard input,
  not echoed at a terminal, never said back.
- `tool/keyring-test.sh` runs the store's tests on Linux against a GNOME Keyring of their own, on
  a bus and in a home made for the run; the person's keyring is never touched. Seen red: one
  attribute for every name, and `key set` keeping the key under another name.
- Measured: with no keyring opened, and with none running (D-Bus starts one), `key set` ends at
  once with 65 and "no keyring is open"; it does not wait at a desktop nobody sits at.
- The Build on `60b657b` (39220899672), published as `0.5.1~snapshot.167`, ran the round trip on
  Linux and on Windows (`windows-2025`).

## Acceptance

- The round trip is green in the Build on Linux (`ubuntu-22.04`) and on Windows (`windows-2025`),
  and the value is seen in no argument (`ps` while it runs) and in no file.
