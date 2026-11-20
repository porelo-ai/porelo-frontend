# F632 — The Maven Cache Keeps What The Build Downloads

```json
{
  "$schema": "issue-1.json",
  "id": "F632",
  "title": "The Maven Cache Keeps What The Build Downloads",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "The Build's Maven cache is keyed by pom.xml alone and never saved over an exact hit, so the parent's and plugins' artifacts that move without this pom are fetched from Maven Central on every Build, which a 429 from Central turns red"
}
```

**Why this size.** XS: the shared form of the Build's Maven cache taken over as a copy, in `.github/actions/` and the
Build's one saving job; no code that ships.

**What must be true.** A Build fetches from Maven Central only what changed since the cache was saved, so Central's
rate limit never turns a Build red that has no fault.

## Plan

- Measured in Build 44731610972: the step restored `maven-Linux-<hash>` as an exact hit, and Maven then logged 141
  `Downloading from central` lines (BOMs, plugins, `commons-*`, `asm`, the snapshot parent's metadata among them).
- Cause: the key is `maven-${{ runner.os }}-${{ hashFiles('pom.xml', '.mvn/wrapper/maven-wrapper.properties') }}`,
  but what Maven resolves also comes from `porelo-parent` 0.2.2-SNAPSHOT and its imported BOMs and plugin versions,
  which move without this pom changing. `actions/cache` never saves over an exact hit, so what a moved parent brings is
  downloaded again in every Build.
- The fix is the shared form all Porelo repositories copy: `pinned-jdk` restores under a key holding the run's id and
  attempt and touches a marker; a new `maven-cache-save` action, the last step of the Build's `build` job with
  `if: always()`, saves only when a jar or pom changed status after the marker (`find -cnewer`, since Maven dates a
  download by the server's Last-Modified). The wrapper's Maven gets a cache of its own, keyed by its properties.

## Acceptance

- Two Builds in a row with no change to the parent or the pom: the second logs no `Downloading from central`.
