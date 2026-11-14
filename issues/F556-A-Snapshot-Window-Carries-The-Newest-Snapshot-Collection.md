# F556 — A Snapshot Window Carries The Newest Snapshot Collection

```json
{
  "$schema": "issue-1.json",
  "id": "F556",
  "title": "A Snapshot Window Carries The Newest Snapshot Collection",
  "state": "Implementing",
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
    release pin stands. The build writes the three and the pointer's `commit` into its log and the bundle.
  - A release build keeps the release pin and refuses a snapshot one.
- **Anything else pinned to a release only**: read in the build and packaging which carried parts come from a
  release (the porelo backend a package recommends, the JDK and tools the build pins); each is named here, and one a
  snapshot window needs as a snapshot is filed apart.
- **Red first** (harm: a snapshot window prepares machines with an old release that lacks what the snapshot expects):
  `fetch_collection.sh` with a snapshot version against a local source refuses a wrong digest and takes the right
  one; a test of porelo-host compiled with the defines prints them from `--collection-info`; a test that a release
  build's channel keeps the release pin.

## Acceptance

- A snapshot package's porelo-host names the newest snapshot collection by `--collection-info` and its check runs on
  it; a release package names the release; the tests are seen red first.
