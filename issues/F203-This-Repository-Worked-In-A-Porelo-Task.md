# F203 — This Repository Worked In A Porelo Task

**Status:** Analyzed.
**Size:** S - the image's missing display tool, the local rules that still hold in a task carried into `AGENTS.md`,
and the move's own small change worked in the task; the rest stands already.

**What must be true.** porelo-frontend's agent works in an attended Porelo task of the project `porelo` on the host,
as `Agent Frontend` (its nickname `Frontend` in porelo-project's `project.yml`, decided), with this
repository only: its image holds the Flutter toolchain the
build needs (the pinned Flutter, `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev`, `libsecret-1-dev`, `xvfb`,
`dbus`) and the pinned JDK for the document checks; its pushes go through the gate to the host's Forgejo, whose build
of them is green; it is reached in the project's room; and a way back to this machine stays open, as
the project's procedure for an agent's move lays out. This
issue is worked to Review from inside that task, to show the move done.

## What stands already (read 2026-11-06)

- **The image**: `porelo.yml` builds on Ubuntu 24.04 with the pinned Flutter 3.47.0 (as `pubspec.yaml`), its Linux
  engine fetched at build time, `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev`, `libsecret-1-dev`, `dbus`,
  `gnome-keyring`, the pinned GraalVM for the document checks, nfpm and shfmt, each by digest. **`xvfb` is missing**,
  which the integration leg's display needs.
- **The workflows on the host's forge**: every job that publishes, rents a machine or builds on Windows
  (`windows`, `integration`, the uploads, `delete-runs`, `artifactory-probe`) is guarded by `vars.PORELO_PUBLISH`,
  which porelo-host's `up` sets to `false` there; the build and test jobs run on `ubuntu-24.04` and `ubuntu-26.04`,
  both labels of the host's runner. So the forge builds the repository unchanged, without the Windows build and the
  leg on a leased machine, which stay the central forge's.
- **The name**: `Agent Frontend`, nickname `Frontend` in porelo-project's `project.yml`.

## Plan

1. `porelo.yml`: `xvfb` in the image, so the integration leg can run under `xvfb-run` where a machine is given.
2. `AGENTS.md`: the local rules of this repository that hold in a task too, committed, since the local rules file is not in
   the task, as the project's procedure for an agent's move says: the commit-message check before
   a commit, `TMPDIR` for large test runs, one review reading per issue, the tests run on a commit. What names the
   development machine (its VM accounts and keys, its own folders, the laptop's sub-agents) stays there.
3. The move itself, by the project's procedure for an agent's move, once the host stands and the operator starts the task: this issue's own small
   change - the two above - taken from start to Review inside the task, through the gate, with the forge's Build green,
   and the check read.

No test goes red first: nothing here is code. The forge's Build of the task's push is the check.

## To be checked

- What the integration leg needs inside a task: a display under `xvfb-run`, and a VM to test against, which the
  task reaches only as the move's procedure and the VM pool allow; until the pool lends machines by kind, the leg is
  named in the hand-over as not run, as on the central forge without a lease.
- Whether the task's egress reaches `storage.googleapis.com` and `pub.dev` for `flutter pub get` (the engine is in
  the image), and Maven Central and Sonatype's snapshots for the document checks.
