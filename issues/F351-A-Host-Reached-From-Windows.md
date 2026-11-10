# F351 — A Host Reached From Windows

```json
{
  "$schema": "issue-1.json",
  "id": "F351",
  "title": "A Host Reached From Windows",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 7,
  "blockedBy": [],
  "covers": "A host reached from Windows, measured first, probably by WSL's ssh."
}
```

**What must be true.** The Windows build reaches a host, as it reaches a machine over ssh. How is measured first, and is probably WSL's ssh.

## Why

`Machine.whyNotReachableOn` in `lib/src/app/machines.dart` refuses card connections on Windows, so [F108](README.md#f108) reaches a machine over ssh, but no host. [F290](README.md#f290) describes a way through Windows' own OpenSSH.

## To be measured first

- Whether WSL's ssh carries a host's card, its forwards and its agent, against Windows' own OpenSSH as in [F290](README.md#f290).

## When it is built

- The three plain starts named in [F108](README.md#f108) take `openSsh`: `lib/src/app/host_progress.dart`, `packages/porelo_host/lib/src/remote.dart` and `packages/porelo_host/lib/src/host_run.dart`.
- Until then the documentation says that the Windows build reaches no host.
