# F113 — The MSIX Installed And Started In The Build

**Status:** Accepted.

**What must be true.** The Build's job *Windows* installs the MSIX it has just signed on GitHub's
Windows runner, with the certificate's public half trusted as the download page says, and starts the
installed interface once; a package that does not install or start fails the job.

## Why

The MSIX is built and signed in every Build, but nothing installs it. The Windows build's regular
check is GitHub's Windows runner, and a test on a Windows machine comes only from time to time
(`doc/decisions.md`, "The Windows build is checked on GitHub's Windows runner"). Installing it on
the runner is the nearest thing to that test which runs on every build.

## The shape

- A step after the packing in `.github/workflows/build.yml`: `Import-Certificate` of `sokar-msix.cer`
  into `TrustedPeople`, `Add-AppxPackage` of the MSIX, and the installed interface started once and
  seen to run.
- Red first: the same step against an MSIX signed by another certificate, which must fail; proved by
  running it green and red, not by asserting the workflow's text.
