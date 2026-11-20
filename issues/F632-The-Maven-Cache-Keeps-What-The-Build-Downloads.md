# F632 — The Maven Cache Keeps What The Build Downloads

```json
{
  "$schema": "issue-1.json",
  "id": "F632",
  "title": "The Maven Cache Keeps What The Build Downloads",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 2,
  "blockedBy": [],
  "covers": "The Build's Maven cache is keyed by pom.xml alone and never saved over an exact hit, so the parent's and plugins' artifacts that move without this pom are fetched from Maven Central on every Build, which a 429 from Central turns red"
}
```

**Why this size.** S: one cache step in `.github/actions/pinned-jdk/action.yml` and the Builds that read it; no code
that ships.

**What must be true.** A Build fetches from Maven Central only what changed since the cache was saved, so Central's
rate limit never turns a Build red that has no fault.

## Plan

- Measured in Build 44731610972: the step restored `maven-Linux-<hash>` as an exact hit, and Maven then logged 141
  `Downloading from central` lines (BOMs, plugins, `commons-*`, `asm`, the snapshot parent's metadata among them).
- Cause: the key is `maven-${{ runner.os }}-${{ hashFiles('pom.xml', '.mvn/wrapper/maven-wrapper.properties') }}`,
  but what Maven resolves also comes from `porelo-parent` 0.2.2-SNAPSHOT and its imported BOMs and plugin versions,
  which move without this pom changing. `actions/cache` never saves over an exact hit, so what a moved parent brings is
  downloaded again in every Build.
- First, read how `porelo-parent`'s users that solved this key their cache, so the repositories keep one form.
- Then the key changes whenever what Maven resolved changes, never by a retry: for example, a save after the build
  keyed by a hash of the resolved artifacts' list, restored by prefix.
- Red first: a Build log where an exact hit is followed by `Downloading from central` lines; after the fix, a second
  Build on an unchanged parent downloads none.

## Acceptance

- Two Builds in a row with no change to the parent or the pom: the second logs no `Downloading from central`.
