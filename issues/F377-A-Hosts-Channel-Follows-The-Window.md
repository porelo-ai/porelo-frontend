# F377 — A Host's Channel Follows The Window

**Status:** Review.
**Size:** S - the channel `porelo-host` defaults to, read from its own version.

**What must be true.** A host the window prepares installs from the window's own channel: a window from `snapshots` makes `snapshots` hosts, one from `releases` makes `releases` hosts.

## Why

`HostPlan`'s `distribution` defaults to `snapshots` and the window never passes `--distribution`, so a released window prepares hosts from `snapshots`.

## Plan

- `tool/package.sh` already compiles the version into `porelo-host`, with `~snapshot.` in every version not built from a tag. `porelo-host` takes its default channel from that: `~snapshot.` means `snapshots`, otherwise `releases`.
- A development build, with no version compiled in, stays on `snapshots`.
- An explicit `--distribution` still wins.

## How it stands

- `porelo-host` takes its default channel from the version compiled into it: a version with `~snapshot.` and a
  build from source (`unreleased`) install from `snapshots`, any other version from `releases`; `--distribution`
  still wins. The window passes none, so its host follows the window's own package.
- `packages/porelo_host/test/up_given_test.dart`, each reading `porelo_host_distribution` from the inventory
  written to the host:
  - *a host prepared by a released porelo-host installs from releases*: red first, `Expected: 'releases'
    Actual: 'snapshots'`.
  - *a host prepared by a snapshot porelo-host installs from snapshots* and *a host prepared by a development
    build installs from snapshots*: green at once, seen red (`Expected: 'snapshots' Actual: 'releases'`) with the
    default broken to `releases` on purpose.
  - *snapshots asked of a released porelo-host wins* and *releases asked of a snapshot porelo-host wins*: green
    at once, seen red with `--distribution` ignored on purpose.
- The newest Porelo release, 0.5.0, has no `vault status`, which the host's plays ask, so a window from
  `releases` prepares a working host only after a Porelo release that carries it.

## Acceptance

- Each of the three cases in a test, seen to fail first.

## To be checked

- It means a Porelo release comes before a window's release: a window from `releases` needs a released Porelo to install. The order of a release says so.
