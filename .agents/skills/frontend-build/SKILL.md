---
name: frontend-build
description: porelo-frontend build and publishing rules. Use when building or publishing the frontend.
---

# frontend-build

### Building and publishing

- **Packages are `.deb` and `.rpm` from `tool/package.sh` with nfpm**, `type: tree`, dependencies
  derived from the ELF files and never written into the template; `recommends: porelo`, `amd64` only;
  `test/packaging_test.dart` asserts the template with comments stripped.
- **The job that packages the bundle runs on `ubuntu-22.04`**, because the bundle links the system
  GTK, so the build machine is the oldest one the package installs on; every other Linux job runs on
  `ubuntu-26.04`.
- **A snapshot is `0.1.0~snapshot.<run>`**, so each build supersedes the last; a flat version
  published once strands whoever installed it.
- **An upload names distribution, component and architecture as matrix parameters on its target
  path** (`;deb.distribution=…;deb.component=…;deb.architecture=…`); without Annotate permission
  they are dropped in silence (`artifactory-probe.yml` checks it). `JF_URL` is the platform URL,
  without `/artifactory`.
- **`tool/test_report.dart` reads `flutter test --machine` once** and writes the HTML page, JUnit XML,
  the step summary and one annotation per failing scenario; an empty run fails.
- **A change to `**.md`, `doc/` or `mkdocs.yml` alone starts no build.**
- **Every download a workflow takes from outside is pinned, by digest or version, and comes from `actions/cache` keyed
  by that pin**, checked against it after a hit as after a download; a miss fetches and saves. The pin is the key's
  last part after a `-` and what comes before it names the kind, as `delete-runs.yml` keeps only the newest entry of
  each kind per ref. Ubuntu's packages come through `.github/actions/cached-apt`, keyed by the runner image and the list.
