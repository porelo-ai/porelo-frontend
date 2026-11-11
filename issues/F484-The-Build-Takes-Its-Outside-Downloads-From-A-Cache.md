# F484 — The Build Takes Its Outside Downloads From A Cache

```json
{
  "$schema": "issue-1.json",
  "id": "F484",
  "title": "The Build Takes Its Outside Downloads From A Cache",
  "state": "Implementing",
  "size": "M",
  "priority": "Medium",
  "rank": 6,
  "blockedBy": [],
  "covers": "Every download the frontend's workflows take from outside, pinned by digest or version, comes from a cache keyed by that pin, with only the newest entry of each kept, so an outside registry or mirror that does not answer does not turn a build red."
}
```

**Why this size.** Four kinds of download in `.github/workflows/build.yml`, each with its own way into a cache, and
the removal of older entries; proven by a build that runs with the outside sources not answering.

**What must be true.** A build whose pinned downloads were fetched once runs green again while the place they come
from is down.

## Why

- Serves porelo-project's *Builds take outside downloads from a cache* (story ST317, porelo-project 1a81434).
- porelo-host's molecule went red when Codeberg's registry answered 504. The frontend's build takes these from
  outside on every run:
  - **the four container images** of the job that installs the packages in a clean Ubuntu 26.04, Debian 13, Fedora 43
    and Fedora 44 (`docker run … ${{ matrix.image }}`, each pinned by digest), from Docker Hub;
  - **nfpm**, the packager, a release tarball from GitHub, pinned by its SHA-256 (the Package step);
  - **porelo-host's collection**, a release asset fetched by `tool/fetch_collection.sh`, pinned by version and SHA-256,
    in the Linux and the Windows build;
  - **Ubuntu's packages** for a desktop build (`apt-get install` in the build and the leased-machine jobs, and
    python3-yaml in `workflows.yml` where the runner lacks it), from Ubuntu's mirrors.
- Already cached: the pinned JDK and Maven's repository (`.github/actions/pinned-jdk`), Flutter's SDK and pub's cache
  (`subosito/flutter-action` with `cache: true`).

## Plan

- The images: `docker save` into `actions/cache` keyed by the image digest, `docker load` before the run; a miss
  pulls and saves.
- nfpm and the collection: the file itself in `actions/cache`, keyed by its SHA-256, checked against it after a hit as
  after a download.
- Ubuntu's packages: the `.deb`s in `actions/cache`, keyed by the package list and the runner image's version, with
  `apt-get install` from them; a miss goes to the mirror.
- Only the newest entry of each is kept: `delete-runs.yml` also removes cache entries whose key is not the one in
  force (`gh cache delete`).

## To be checked

- Whether GitHub's repository settings can let cache entries expire after a set time, which would spare the removal
  in `delete-runs.yml`; today an entry unused for seven days goes by itself.
- Whether the leased-machine job's runner keeps a cache of its own that this should use instead.
