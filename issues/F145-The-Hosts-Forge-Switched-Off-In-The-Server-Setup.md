# F145 — The Host's Forge Switched Off In The Server Setup

**Status:** Estimated (operator, 2026-10-28); revived from Rejected, placed later by the operator.
**Size:** S - one choice in the server setup dialog, kept in the host's record, passed to `porelo-host` and written
into the first inventory; the inventory's value exists already.

**What must be true.** The server setup dialog offers *Set up a forge on the server*, on by default; a person whose
people use a central forge switches it off, and the host's first inventory then says `porelo_host_forge: false`, so
nothing of a forge is set up there.

## Why

The operator, 2026-10-28: a host gets a local Forgejo of its own only where the person wants it; where a central
forge is used, nothing is set up on the host. On by default is fine, as long as it can be switched off in the
interface. Until this is built, the interface writes `porelo_host_forge: true` for every host
([F202](README.md#f202), sprint 6h).

## Plan

- **The record:** `HostUpRecord` (`lib/src/app/settings.dart`) keeps `forge`, true where absent, so a record kept
  before reads as on; `arguments` passes `--no-forge` where it is off.
- **The command:** `porelo-host up` takes `--no-forge`, which sets `HostPlan.forge` (`packages/porelo_host`) to
  false; the inventory writes the value already.
- **The dialog:** a switch on *The project*, `host-forge`, on by default, restored from the kept record, and named in
  the review's summary.
- **Red first:** a widget test that switching it off makes the run's arguments carry `--no-forge`, and a package
  test that `--no-forge` writes `porelo_host_forge: false`.

## Acceptance

- A host set up with the switch off has no forge; one with it on has one.
- Seen to fail: the widget test red before the switch exists.
