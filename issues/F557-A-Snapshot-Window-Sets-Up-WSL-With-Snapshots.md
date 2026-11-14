# F557 — A Snapshot Window Sets Up WSL With Snapshots

```json
{
  "$schema": "issue-1.json",
  "id": "F557",
  "title": "A Snapshot Window Sets Up WSL With Snapshots",
  "state": "Backlog",
  "size": "XS",
  "priority": "High",
  "rank": 9,
  "blockedBy": [],
  "covers": "Story ST50, a machine and a host reached from Windows: a snapshot window sets Porelo up in a WSL distribution from Porelo's snapshots repository, and a release window from its releases repository."
}
```

**Why this size.** One caller passes one flag the method already takes, and one test.

**What must be true.** The operator's rule of 2026-11-14: whatever Porelo snapshot is used, everything it needs is
there as a snapshot too. A snapshot window on Windows that sets up WSL installs snapshot Porelo, not release Porelo.

## Plan

- **Today.** `WslSetup.setupLines` (`lib/src/app/wsl_setup.dart`) takes `snapshots` and defaults it to false; its one
  caller, `_offer` in `lib/src/ui/wsl_machine.dart`, never passes it, so the lines shown and run always name
  Porelo's `releases` apt or rpm repository.
- **The change.** The window's channel decides, as `hostArguments` (`lib/src/app/host_session.dart`) already does for
  porelo-host: a release build (`kReleaseMode` and a release version) passes `snapshots: false`, any other build
  `snapshots: true`. The channel is read in one place, shared with `hostArguments`, rather than a second rule; the
  lines on screen are the lines run.
- **Red first** (harm: a snapshot window sets WSL up with release Porelo, which lacks what the snapshot window
  expects): a widget test of the WSL offer in a snapshot build shows and runs the `snapshots` repository line, and in
  a release build the `releases` one; it fails on today's code.

## Acceptance

- The WSL offer of a snapshot window names Porelo's snapshots repository, a release window's its releases; the test
  is seen red first.
