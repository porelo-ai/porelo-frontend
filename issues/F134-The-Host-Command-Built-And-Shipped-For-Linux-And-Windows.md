# F134 — The Host Command Built And Shipped For Linux And Windows

**Status:** Analyzed; blocked by [F131](README.md#f131).
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

## Acceptance

- The Build is green on both legs. `porelo-host --version` from inside the installed deb on the
  test VM and from the MSIX in the Windows job answers the interface's version.

## To be checked

- That `dart compile exe` with the package's dependencies needs no native library on either
  system. `package:win32` and `dart:ffi` load the system's own.
