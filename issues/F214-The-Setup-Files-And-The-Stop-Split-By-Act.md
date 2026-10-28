# F214 — The Setup Files And The Stop Split By Act

**Status:** Estimated (operator, 2026-10-28); accepted with `porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78); blocked by `porelo-host` [HO42](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho42) and [HO45](https://github.com/porelo-ai/porelo-host/blob/main/issues/README.md#ho45).
**Size:** M - [F197](README.md#f197)'s upload and [F199](README.md#f199)'s feed changed in place, by act, with their tests.

**What must be true.** The setup's files reach the person's own home on the host, owned by them, and the stop is fed by act: the host admin's root stop takes only the VPN key and the forge's certificate; a project admin's bring and a developer's join take their vault, keys and tokens in their own account, with no `sudo`.

## Why

`porelo-project` [PJ78](https://github.com/porelo-ai/porelo-project/blob/main/issues/README.md#pj78) moves every person's part out of root: `porelo-host`'s setup directory becomes the person's own, and its stop gains an own-account mode.

## Plan

- **The upload** ([F197](README.md#f197)): `HostFiles` (`packages/porelo_host/lib/src/host_files.dart`, `/etc/porelo-host/setup/…`) and `HostRun.setupPlace` take the person's own setup directory for bring and join; the root path stays for nothing.
- **The feed** ([F199](README.md#f199)): `hostStopFeedCommand` (`lib/src/app/host_stop_feed.dart`) builds `porelo-host-stop --stdin` with or without `sudo` by act, and refuses a need the act does not take (a root stop asking `keys`, an own-account stop asking `wireguard`).
- **Red first:** the feed's test that a root stop's command for `keys` is refused and an own-account command carries no `sudo`.

## Acceptance

- A bring's files land in the admin's home, owner them, mode as `porelo-host` checks.
- A root stop never receives a vault passphrase or key; an own-account stop never a VPN key.
- Seen to fail: the feed test red before the act is named.
