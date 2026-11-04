# F204 — The Build Runs On The Local Forge As On The Central One

**Status:** Analyzed.
**Size:** M - the workflows, the leased profile and one test here, no contract another repository reads, and runs of a
Flutter build on a throwaway Forgejo.

**What must be true.** porelo-frontend's `build.yml` runs green on the host's Forgejo and on the central forge on the
same commit, with no edit between them: the rented machine of its integration leg asked for by kind, never by a
provider, the registry it publishes to taken as a variable, and the Windows job switched by a variable present on both
forges, as `porelo-host`'s `doc/local-forge.md`, *The local registry and publication settings*, describes.

## Plan

Read in today's `.github/workflows/`, `pom.xml` and `tool/e2e.sh`, measured on a throwaway Forgejo 17 in podman: a runner
of 4 CPUs and 8 GiB in the job image the host pins, with `PORELO_PUBLISH=false`.

- **What ties the Build to the central forge:**
  - `Linux` asks for `ubuntu-22.04` and `Windows` for `windows-2025`, which no host's runner offers, so both wait for ever
    and the run never ends. A host's labels are `ubuntu-24.04` and `ubuntu-26.04`.
  - The first step of `Install what a Linux desktop build needs` deletes every apt source, and since 24.04 Ubuntu's own
    is one of them.
  - `Prove the packages install` runs containers, and a host's runner gives a job no socket.
  - `legs` asks the central forge's API, `Publish` uploads to the Artifactory, `delete-runs.yml` and
    `artifactory-probe.yml` call either.
  - `integration` names a provider in its secrets and its Maven profile, and takes whichever machine the tool defaults to.
  - A push builds `main` alone, and a task's branch on a host is built only through its pull request.
- **Steps:**
  1. `vars.PORELO_PUBLISH` is checked to be `true` or `false` at the start of `Linux`. It switches off `Windows`, `legs`,
     `integration`, `installs` and `Publish` where it is `false`, and the jobs of `windows.yml`, `delete-runs.yml` and
     `artifactory-probe.yml`.
  2. `Linux` takes `ubuntu-22.04` where it publishes and `ubuntu-24.04` elsewhere: the floor is about what goes out, and
     nothing goes out from a host.
  3. Only third-party apt sources are deleted.
  4. The Maven profile is `leased`, the secrets `PORELO_MACHINES_API` and `PORELO_MACHINES_SSH`, the machine `--kind amd64`,
     and `check-providers` joins the Build.
  5. `pull_request` joins the triggers, with the same paths. `Windows`, `installs`, `integration` and `Publish` skip a
     pull request, so one from outside rents nothing and publishes nothing.
  6. `settings.xml` and `.mvn/` take the shape porelo-buildtools sets for reading snapshots from central and the host,
     together with the workflows' `MAVEN_SNAPSHOTS_URL` and read token. They are not designed here.
- **Red first:** today's `main` on that Forgejo: `Linux` and `Windows` are never taken by the runner, and `check-providers`
  on today's tree names the workflow, `pom.xml`, `tool/e2e.sh` and `AGENTS.md`.

## Acceptance

- Seen to fail first: today's `build.yml` on the throwaway Forgejo.
- On it, the same commit runs `Linux` green on a push to `main` and on a pull request from `porelo/<task>`, with
  `Windows`, `legs`, `integration`, `installs` and `Publish` skipped.
- On the central forge a push to `main` runs what it ran: 22.04, Windows, the leg on a machine of kind `amd64`, the
  installs and Publish.
- A Build with `PORELO_PUBLISH` unset fails naming the variable.

A host lends no machine by kind to a job yet, so the leg stays off there: that is [F354](README.md#f354).

## To be checked

- The central forge's organization values reach this repository: `PORELO_PUBLISH`, `PORELO_MACHINES_API` and
  `PORELO_MACHINES_SSH`.
- The Build on a real host: its egress, its disk, and the socket gate's address in `MAVEN_SNAPSHOTS_URL`.
