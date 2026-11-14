# F556 — A Snapshot Window Carries The Newest Snapshot Collection

```json
{
  "$schema": "issue-1.json",
  "id": "F556",
  "title": "A Snapshot Window Carries The Newest Snapshot Collection",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 3,
  "blockedBy": [],
  "covers": "A snapshot build of the window carries porelo-host's newest snapshot collection, found by its published latest pointer and taken only by that digest, and names the one collection it took; a release build keeps pinning a porelo-host release."
}
```

**Why this size.** The build's fetch, the digest compiled into porelo-host, and their tests; the release path stays.

**What must be true.** The operator's decision of 2026-11-14: whatever Porelo snapshot is used, everything it needs is
there as a snapshot too. A snapshot window prepares a machine with porelo-host's newest snapshot collection, not the
pinned 0.5.12 release, whose missing `/usr/sbin/porelo-host` left the operator's machine without one.

## Plan

- **Today.** `hostCollection` (`packages/porelo_host/lib/src/collection.dart`) pins version, file and digest of a
  release as constants; `porelo-host --collection-info` prints them; `tool/fetch_collection.sh` fetches
  `v<version>/<file>` from porelo-host's releases and checks it against that digest and `SHA256SUMS`;
  `tool/package.sh` bundles it, and `readCarriedHostCheck` takes the carried file only by the compiled digest.
- **The snapshot place** (Agent Machines): the rolling pre-release `snapshot` of porelo-host, base
  `https://github.com/porelo-ai/porelo-host/releases/download/snapshot/`; files `porelo-host-<x.y.z>-snapshot.<run>.tar.gz`
  with `SHA256SUMS` beside them; the pointer `latest.json` holds `version`, `file`, `sha256` and `commit`, uploaded
  last.
- **The change.**
  - A snapshot build (the channel the build already tells apart) reads `latest.json` once, checks `version` against
    `^[0-9]+\.[0-9]+\.[0-9]+-snapshot\.[0-9]+$`, `file` against `porelo-host-<version>.tar.gz` and `sha256` as 64 hex
    digits, and passes the three on; `fetch_collection.sh` takes a snapshot version, then fetches from `snapshot/`
    and checks the file against that digest and `SHA256SUMS` as strictly as a release.
  - porelo-host is compiled with the taken version, file and digest as `-D` defines over `hostCollection`, so
    `--collection-info` and the carried check name exactly the collection in the package; without the defines the
    release pin stands. The build writes the three and the pointer's `commit` into its log; the bundle names the three
    through its porelo-host's `--collection-info`.
  - One script, `tool/host_collection.sh <releases|snapshots>`, makes the choice for the Linux job, the Windows job
    and the Windows trial, and prints `<version> <sha256> <file> <source>` (the tag `v<version>` for a release, the
    pointer's commit for a snapshot); `tool/package.sh` and `tool/windows-prepare.ps1` take the three as
    `PORELO_HOST_COLLECTION_VERSION`, `_SHA256` and `_FILE`, compile them in and check that porelo-host names them.
  - A release build keeps the release pin and refuses a snapshot one.
- **Anything else pinned to a release only**, read in the build and packaging:
  - The Windows setup of a WSL distribution (`WslSetup.setupLines`, `lib/src/app/wsl_setup.dart`) names Porelo's
    `releases` package repository, also in a snapshot window: its one caller (`lib/src/ui/wsl_machine.dart`) never
    passes `snapshots`. A snapshot window needs it as a snapshot; it is to be filed apart.
  - `porelo-host up` installs Porelo from the channel of its own version (`channelOf`), so a snapshot window's
    porelo-host installs snapshots: no release pin.
  - The packages' `recommends: porelo` names no channel: apt takes it from whichever distribution the machine's
    sources name. No release pin.
  - The build's JDK (the GraalVM porelo-machines pins), nfpm (v2.43.0 by digest) and Flutter (`pubspec.yaml`) are
    build tools, carried by nothing that ships.
- **Red first** (harm: a snapshot window prepares machines with an old release that lacks what the snapshot expects):
  `fetch_collection.sh` with a snapshot version against a local source refuses a wrong digest and takes the right
  one; a test of porelo-host compiled with the defines prints them from `--collection-info`; a test that a release
  build's channel keeps the release pin.

## Acceptance

- A snapshot package's porelo-host names the newest snapshot collection by `--collection-info` and its check runs on
  it; a release package names the release; the tests are seen red first.
