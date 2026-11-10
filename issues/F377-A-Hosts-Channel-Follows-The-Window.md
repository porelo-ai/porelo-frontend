# F377 — A Host's Channel Follows The Window

**Status:** Implementing.
**Size:** S - the channel `porelo-host` defaults to, read from its own version.

**What must be true.** A host the window prepares installs from the window's own channel: a window from `snapshots` makes `snapshots` hosts, one from `releases` makes `releases` hosts.

## Why

`HostPlan`'s `distribution` defaults to `snapshots` and the window never passes `--distribution`, so a released window prepares hosts from `snapshots`.

## Plan

- `tool/package.sh` already compiles the version into `porelo-host`, with `~snapshot.` in every version not built from a tag. `porelo-host` takes its default channel from that: `~snapshot.` means `snapshots`, otherwise `releases`.
- A development build, with no version compiled in, stays on `snapshots`.
- An explicit `--distribution` still wins.

## Acceptance

- Each of the three cases in a test, seen to fail first.

## To be checked

- It means a Porelo release comes before a window's release: a window from `releases` needs a released Porelo to install. The order of a release says so.
