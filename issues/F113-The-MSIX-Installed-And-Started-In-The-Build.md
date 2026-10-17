# F113 — The MSIX Installed And Started In The Build

**Status:** Analyzed.
**Size:** S - one PowerShell script and one step in the Build's job *Windows*; no contract, nothing
in `lib/`.

**What must be true.** The Build's job *Windows* installs the MSIX it has just signed on GitHub's
Windows runner, with the certificate's public half trusted as the download page says, and starts the
installed interface once; a package that does not install or start fails the job.

## Why

The MSIX is built and signed in every Build, but nothing installs it. The Windows build's regular
check is GitHub's Windows runner, and a test on a Windows machine comes only from time to time
(`doc/decisions.md`, "The Windows build is checked on GitHub's Windows runner"). Installing it on
the runner is the nearest thing to that test which runs on every build.

## Plan

- **`tool/windows-install-check.ps1`**, given the MSIX and `porelo-msix.cer`:
  - `Import-Certificate` of the `.cer` into `Cert:\LocalMachine\TrustedPeople`, as `doc/index.md`
    tells a person to;
  - `Add-AppxPackage` of the MSIX; `Get-AppxPackage ai.porelo.frontend` must then name the
    version just built (the identity in `packaging/windows/AppxManifest.xml.in`);
  - the installed application started through its identity,
    `shell:AppsFolder\<PackageFamilyName>!PoreloInterface`, and `porelo_frontend.exe` seen running
    from the package's install folder after a few seconds, then stopped;
  - `Remove-AppxPackage` at the end, whatever happened.
- **Its own red, in the same step, every build:** a copy of the MSIX re-signed with a throwaway
  certificate (`New-SelfSignedCertificate` in the runner's temporary store, never kept) must be
  refused by `Add-AppxPackage` while only the project's certificate is trusted. A script that would
  install anything proves nothing; this proves it refuses, then the real one proves it installs.
- **`.github/workflows/build.yml`:** a step "Install and start the MSIX" after "Pack the ZIP and
  the MSIX", only where the MSIX was kept (the signing secrets are there); where they are not, the
  script says it skipped and why.
- **Red first:** the script run on the runner before the step's red half exists, against a copy
  signed by another certificate, must fail the job: run once green and once red, never proven by
  reading the workflow's text.

## Acceptance

- **The MSIX installs and starts on the runner in every Build on `main`**, and the job fails when it
  does not. Seen to fail: the same step against an MSIX signed by another certificate, which
  `Add-AppxPackage` refuses.
- **Nothing stays behind on the runner:** the package removed, the throwaway certificate removed.

## To be checked

- **Whether a hosted Windows runner starts a Flutter window at all:** it runs an interactive
  session, and Flutter's ANGLE falls back to WARP without a GPU; measured in the first run. If no
  window can start, "started" becomes the process alive for a few seconds. (Agent Frontend's)
