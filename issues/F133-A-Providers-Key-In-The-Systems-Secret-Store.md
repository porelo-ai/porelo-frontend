# F133 — A Provider's Key In The System's Secret Store

**Status:** Backlog.
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

## Acceptance

- The round trip is green in the Build on Linux (`ubuntu-22.04`) and on Windows (`windows-2025`),
  and the value is seen in no argument (`ps` while it runs) and in no file.

## To be checked

- Whether a Secret Service with a locked collection asks at the desktop or refuses, when the
  command line runs without one.
