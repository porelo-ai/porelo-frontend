# F134 — The Host Command Built And Shipped For Linux And Windows

**Status:** Implementing; blocked by [F131](README.md#f131).
**Size:** S - two build legs the Build already has, and the command inside each package.

**What must be true.** Each release of porelo-frontend carries `porelo-host` for Linux x64 and
Windows x64, built from the same commit. The interface's own packages carry the copy it calls, and
each one stands alone as a release asset with its checksum. A person can run it without the
interface, and the interface never runs one of another version. macOS is left out for now, by the
operator's decision; it comes with [F109](README.md#f109), unsigned with its checksum first.

## Plan

- **In the Build:** the Linux job (`ubuntu-22.04`) and the Windows job (`windows-2025`) each run
  `dart compile exe packages/porelo_host/bin/porelo_host.dart`, then `porelo-host --version`.
- **Shipped inside:** the deb and rpm (`packaging/nfpm.yaml.in`) put it at
  `/usr/lib/porelo-frontend/porelo-host`, and the MSIX in its own folder. The interface calls it
  by that path, never by `PATH`.
- **Shipped alone:** each executable with a `SHA256SUMS` beside it in Artifactory, as the
  packages are.
- **The red test first:** the package check that lists the deb's and the MSIX's files is run red
  without the executable.

## Built so far

- `tool/package.sh` compiles `porelo-host` into the bundle with `-Dporelo_host.version=<the
  package's version>` and refuses a binary that says another; it is scanned with the launcher for
  the package's dependencies. `tool/windows-package.ps1` puts `porelo-host.exe` beside the
  interface before the ZIP and the MSIX are packed, with the same check.
- The install proof runs `/usr/lib/porelo-frontend/porelo-host --version` in each clean system
  against the installed package's own version.
- Measured: the deb and the rpm built by `tool/package.sh` here hold
  `/usr/lib/porelo-frontend/porelo-host`, and installed in clean `ubuntu:26.04` and `fedora:44`
  (the Build's pinned digests) it says the package's version. Seen red: the same check without the
  file ends 1.
- **Shipped alone** with its `SHA256SUMS` in Artifactory is left for [F136](README.md#f136), which
  moves every upload to curl; done here it would be one more JFrog CLI call to replace there.
- Left: the Windows job, which only the Build runs.

## Acceptance

- The Build is green on both legs. `porelo-host --version` from inside the installed deb on the
  test VM and from the MSIX in the Windows job answers the interface's version.

## To be checked

- That `dart compile exe` with the package's dependencies needs no native library on either
  system. `package:win32` and `dart:ffi` load the system's own.
