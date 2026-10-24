# F137 — The Collection Taken Only By Its Digest

**Status:** Implementing; blocked by porelo-host's release issue, which attaches the tarball and its
`SHA256SUMS` to each release.
**Size:** S - one pinned digest, checked twice, with a test seen red on a changed byte.

**What must be true.** `porelo-host up` installs on the host only the porelo-host collection whose
SHA-256 it was built to expect. A tarball that differs by one byte is refused before anything is
copied, and again on the host before `ansible-galaxy collection install`, saying both digests.

## Why

Ubuntu 26.04's `ansible-core` 2.20.1 carries CVE-2026-89091: `ansible-galaxy collection install`
resolves member paths without following symlinks, so a crafted tarball can write outside its
target. The operator accepted that risk while the tarball is our own (porelo-host's
`doc/decisions.md`) and asked for this check, so that only that tarball reaches the installer.

## Plan

- `packages/porelo_host` carries the release it is built against: the porelo-host version and the
  tarball's SHA-256 as read from that release's `SHA256SUMS`, in one Dart constant beside the
  package's own version. Moving to a newer collection is a change to that constant, made after
  the release has stood as the shared rule on a dependency's age asks.
- **Before the copy:** `HostRun.up` computes the SHA-256 of the tarball it was given (package
  `crypto`, already used by the interface) and refuses with 65 and both digests when it differs.
- **On the host, before the install:** `sha256sum -c` against the expected digest, written to the
  command's standard input; a mismatch ends the step with 65 and the host's own words.
- `--collection FILE` stays for a tarball built from a clean clone in a test run, and takes
  `--collection-sha256 HEX` with it; without the flag the pinned digest is the only one accepted.
- **The red test first:** a unit test with a tarball one byte changed, refused before any remote
  command; and `tool/vm-run.sh` with a tarball changed after the local check, refused on the host.

## Acceptance

- `tool/vm-run.sh` against the published release's tarball: `up` installs it. Seen to fail: a tarball
  with one byte changed, refused before any copy, and a tarball swapped on the host after the copy,
  refused before `ansible-galaxy` runs.
