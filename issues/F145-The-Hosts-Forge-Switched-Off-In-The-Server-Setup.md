# F145 — The Host's Forge Switched Off In The Server Setup

```json
{
  "$schema": "issue-1.json",
  "id": "F145",
  "title": "The Host's Forge Switched Off In The Server Setup",
  "state": "Estimated",
  "size": "S",
  "priority": "Low",
  "rank": 1,
  "blockedBy": [],
  "covers": "*Set up a forge on the server* in the server setup dialog, on by default; switched off, the host's inventory says `porelo_host_forge: false`."
}
```

**Why this size.** one choice in the server setup dialog, kept in the host's record, passed to `porelo-host` and written
into the first inventory; the inventory's value exists already.

**How it stands.** Revived from Rejected.

**What must be true.** The server setup dialog offers *Set up a forge on the server*, on by default; a person whose
people use a central forge switches it off, and the host's first inventory then says `porelo_host_forge: false`, so
nothing of a forge is set up there.

## Why

A host gets a local Forgejo of its own only where it is wanted; where a central
forge is used, nothing is set up on the host. On by default is fine, as long as it can be switched off in the
interface. `HostUpRecord.forge` in `lib/src/app/settings.dart` defaults to true and passes
`--forge true|false`; `runHostCommand` in `packages/porelo_host/bin/porelo_host.dart` accepts it, and
`HostRun._inventoryVariables` in `packages/porelo_host/lib/src/host_run.dart` writes
`porelo_host_forge`. `HostDialog` in `lib/src/ui/host_dialog.dart` does not offer the promised
switch; its new records use the default.

## Plan

- **The record:** `HostUpRecord` (`lib/src/app/settings.dart`) keeps `forge`, true where absent, so a record kept
  before reads as on; `arguments` passes `--forge false` where it is off.
- **The command:** `porelo-host up` takes `--forge false`, which sets `HostPlan.forge` (`packages/porelo_host`) to
  false; the inventory writes the value already.
- **The dialog:** a switch in `HostDialog` (`lib/src/ui/host_dialog.dart`), `host-forge`, on by default,
  restored from the kept record.
- **Red first:** a widget test that switching it off makes the run's arguments carry `--forge false`, and a package
  test that `--forge false` writes `porelo_host_forge: false`.

## Acceptance

- A host set up with the switch off has no forge; one with it on has one.
- Seen to fail: the widget test red before the switch exists.
