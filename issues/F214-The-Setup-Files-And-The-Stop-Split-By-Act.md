# F214 — The Setup Files And The Stop Split By Act

**Status:** Implementing.
**Size:** M - [F197](README.md#f197)'s upload and [F199](README.md#f199)'s feed changed in place, by act, with their tests.

**What must be true.** The setup's files reach the person's own home on the host, owned by them, and the stop is fed by act: the host admin's root stop takes only the VPN key and the forge's certificate; a project admin's bring and a developer's join take their vault, keys and tokens in their own account, with no `sudo`.

## Why

Every person's part moves out of root: `porelo-host`'s setup directory becomes the person's own, and its stop gains an own-account mode.

## Plan

- **The upload** ([F197](README.md#f197)): `HostFiles` (`packages/porelo_host/lib/src/host_files.dart`) and `HostRun.setupPlace` take the person's own setup directory for bring and join, `.local/share/porelo-host/setup` relative to their host home, defined once by `HostAct`. `HostRun.uploadSetupFiles` exposes the upload for the coming bring/join callers, requires the access bundle beside the machine file and project bundle, installs the directory as `0700` and each file as `0600` without `sudo`, and checks SHA-256 in staging and in place. No bring/join CLI command exists yet. The root path remains for today's combined project `up` until [F213](README.md#f213) replaces it.
- **The feed** ([F199](README.md#f199)): `hostStopFeedCommand` (`lib/src/app/host_stop_feed.dart`) requires `HostAct.root`, `ownAccount` or `legacyUp`, builds `porelo-host-stop --stdin` with or without `sudo`, and refuses a need the act does not take by name. Server preparation is root; combined project `up` retains its legacy sudo feed. Drive login and Matrix admission remain legacy handling. Own-account identities are refused until the secrets file supplies them; certificate requests stay privileged.
- **Red first:** the feed's tests that root refuses `keys` by name, own-account commands carry no `sudo` and refuse `wireguard`; upload tests that require the person's directory and both bundles before switching their caller from the combined `up` to the new upload method. Execute the upload commands in a private test home to verify actual ownership, modes and digest failures.

## Acceptance

- A bring's files land in the admin's home, owner them, mode as `porelo-host` checks.
- A root stop never receives a vault passphrase or key; an own-account stop never a VPN key.
- Seen to fail: the feed test red before the act is named.
