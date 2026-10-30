# F276 — The VPN, The CA And Per-Machine Keys Taken Out

**Status:** Accepted.
**Size:** M - everything one-click joining makes needless removed from the interface and packages/porelo_host, with its tests and walks.

**What must be true.** The interface no longer has: the WireGuard VPN and its root step (`host_vpn.dart`, `own_host_vpn.dart`, the tunnel files), the host CA and Firefox's policy, the `/etc/hosts` lines, the stops for the CA, the forge password, identities and the central forge's token, per-machine keys and *Copy my public keys for a host…* (`join_keys.dart`), the access file's laptops, the project's own signing key and `signed_by`, and the bring, join and Developers wizard steps that paste host values or keys. A record of a host kept from before is shown as "made before one-click joining: give it back or set it up again". Walks 17–23 are deleted.

## Why

One-click joining from signed state (operator, 2026-10-30): no VPN, no host CA, no forge password, no per-machine key, no project signing key.

Built issues whose code goes here: [F209](README.md#f209), [F212](README.md#f212), [F217](README.md#f217)'s VPN part, [F232](README.md#f232), [F245](README.md#f245), [F251](README.md#f251).

## Plan

- Removed only once [F270](README.md#f270), [F271](README.md#f271), [F272](README.md#f272) and [F273](README.md#f273) stand, so the interface always has one way to reach a host.
- **Red first:** a test that an old host record is shown with the sentence above and offers only give-back and setup again.

## Test

Only the change: the remaining tests of the touched files pass; the deleted tests go with their code.

## Estimate

`F276 size=M est=60 basis=median M 61 (24 records)`
