# F212 — The Forge's CA One Per Host

**Status:** Estimated (operator, 2026-10-28); accepted with `porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78); blocked by [F210](README.md#f210).
**Size:** M - the CA's names and constraint, its place in the secrets file, its trust and warning per host, on [F202](README.md#f202)'s built pieces.

**What must be true.** Each host has its own lasting CA, made by its host admin once in their secrets file and constrained to `<host>.porelo.internal` and that host's network; it signs the host's forge (`forge.<host>.porelo.internal`) and homeserver (`matrix.<host>.porelo.internal`), and every laptop that reaches the host trusts that CA, and only for that host.

## Why

Decided with `porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78): the host admin's lasting CA signs the shared forge's and homeserver's certificates, constrained to the host's own names and network. [F202](README.md#f202) built one CA for every host, constrained to `porelo.internal`.

## Plan

- **The CA:** `SecretsFile._forgeCertificate` (`packages/porelo_host/lib/src/secrets_file.dart`) makes it into `hosts/<host>/forge-ca-key` and `hosts/<host>/forge-ca`, with `nameConstraints=critical,permitted;DNS:<host>.porelo.internal,permitted;IP:10.73.<n>.0/255.255.255.0`, and signs both requests the stop names (forge and homeserver) with their names and `10.73.<n>.1`.
- **The trust:** `Settings.forgeCa` becomes per host (`HostUpRecord`); `_vpnRootStep` installs `porelo-host-<host>.crt` ([F209](README.md#f209)); a developer's laptop installs it only where its SHA-256 equals the signed `ca_sha256` ([F216](README.md#f216)).
- **The warning:** `forgeCaWarning` per host, naming the host.
- **Red first:** the secrets file test that a second host gets a CA of its own, constrained to its name, and that a certificate for another host's name signed by it fails `openssl verify`.

## Acceptance

- Two hosts prepared from one secrets file have two CAs; each forge's certificate verifies against its own CA and not the other's.
- A name outside `<host>.porelo.internal` signed by a host's CA fails `openssl verify`.
- Seen to fail: the two-host test red before the CA is per host.
