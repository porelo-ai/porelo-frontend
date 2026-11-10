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

- `porelo-host` takes its default channel from the version compiled into it: only a release's own version,
  `<major>.<minor>.<patch>` as `tool/package.sh` and `tool/windows-package.ps1` compile it from a tag, installs
  from `releases`; `~snapshot.<run>`, an empty version, the pubspec's `-SNAPSHOT`, a pre-release and a build from
  source (`unreleased`) install from `snapshots`. `--distribution` still wins, and anything but `snapshots` or
  `releases` is a usage error before anything starts. A released window passes none, so its host follows the
  window's own package; a window run from source passes `--distribution snapshots`, since the `porelo-host` it
  calls is the installed one, of whatever channel.
- `packages/porelo_host/test/up_given_test.dart`, each reading `porelo_host_distribution` from the inventory
  written to the host:
  - *a host prepared by a released porelo-host installs from releases*: red first, `Expected: 'releases'
    Actual: 'snapshots'`.
  - *a host prepared by a snapshot porelo-host installs from snapshots* and *a host prepared by a development
    build installs from snapshots*: green at once, seen red (`Expected: 'snapshots' Actual: 'releases'`) with the
    default broken to `releases` on purpose.
  - *snapshots asked of a released porelo-host wins* and *releases asked of a snapshot porelo-host wins*: green
    at once, seen red with `--distribution` ignored on purpose.
- `packages/porelo_host/test/channel_test.dart`, without the `linux` tag so it runs on Windows too:
  - *only a plain release version installs from releases*: red first, `Expected: 'snapshots' Actual: 'releases'`
    for the version `""`.
  - *a build with no version compiled in says unreleased*: green at once, seen red (`Expected: 'unreleased\n'
    Actual: '0.0.0\n'`) with the compiled-in default broken to `0.0.0` on purpose; *a host prepared by a
    development build installs from snapshots*, now taking that default, went red with it too.
  - *porelo-host says the version it was built as*: green at once, seen red (`Expected: '0.5.1\n' Actual:
    'unreleased\n'`) with the compiled-in version written on purpose.
  - *porelo-host refuses an unknown --distribution as a usage error*: red first, `Actual: 'porelo-host: either
    --scaleway-project or --given\n'`.
  - *a host plan refuses an unknown distribution with or without a server name*: red first, `Expected: throws
    <Instance of 'FormatException'> Actual: <Closure: () => void>`.
- In `up_given_test.dart`, *a host prepared by a porelo-host of no release version installs from snapshots* and
  *… of the pubspec version …*: written after the fix, seen red (`Expected: 'snapshots' Actual: 'releases'`)
  with the old blocklist of `unreleased` and `~snapshot.` put back on purpose.
- `test/app/host_protocol_test.dart`, *a window run from source prepares its hosts from snapshots*: red first,
  `Expected: contains in order(['--distribution', 'snapshots'])`.
- Open limit, handed to the coordinator: the newest Porelo release, 0.5.0, has no `vault status`, which the
  host's setup asks, so a window from `releases` prepares failing hosts until a Porelo release carries it. A
  Porelo release must therefore come before a window's release, which the coordinator places in the release
  order.
- The code reading found seven points, all taken: release versions are allowlisted instead of snapshot ones
  blocklisted; the compiled-in default, an empty version, the pubspec's version and `--version` are tested; a
  window run from source asks for `snapshots`; the channel tests run without the `linux` tag; an unknown
  `--distribution` is a usage error and checked by the plan before its early return for a project's host;
  `HostPlan`'s own default is documented as `snapshots`, rather than the version's channel moved into the
  library, since only the command builds a plan from a version; the leftover *To be checked* is the open limit
  above. Nothing was declined.

## Acceptance

- Each of the three cases in a test, seen to fail first.
