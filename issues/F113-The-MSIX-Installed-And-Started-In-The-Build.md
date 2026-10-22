# F113 — The MSIX Installed And Started In The Build

**Status:** Review.
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
- **`.github/workflows/windows.yml`:** the branch trial makes a throwaway signing certificate in
  `Cert:\CurrentUser\My`, exports a password-protected PFX in memory, masks it and its random password,
  and passes both through `GITHUB_ENV` to Pack; Pack checks that certificate's thumbprint through
  `-ExpectedSignerThumbprint` (the production default stays pinned). The same install check follows
  Pack, and an `always()` step removes the trial certificate; no real signing certificate reaches
  a branch.
- **Red first:** the script run on the runner before the step's red half exists, against a copy
  signed by another certificate, must fail the job: run once green and once red, never proven by
  reading the workflow's text.

## Acceptance

- **The MSIX installs and starts on the runner in every Build on `main`**, and the job fails when it
  does not. Seen to fail: the same step against an MSIX signed by another certificate, which
  `Add-AppxPackage` refuses.
- **Nothing stays behind on the runner:** the package removed, the throwaway certificate removed.
- **What "starts" means here, and what it leaves out:** a window seen, or the process alive for 5 s
  without one, since a runner's session may show no window at all. A crash after its first window is
  not caught here; that is for the interface's own tests, not for an install check.

## Measured

- On GitHub's `windows-2025` runner, in the trial on `windows/f113`: the copy re-signed with another
  key of the same subject was refused with `0x800B0109` ("The root certificate of the signature in
  the app package or bundle must be trusted") while the MSIX's own certificate was trusted; the real
  MSIX installed, started through `shell:AppsFolder\…!PoreloInterface` with a window, from
  `C:\Program Files\WindowsApps\ai.porelo.frontend_<version>_x64__<id>\porelo_frontend.exe`, and
  the package, both certificates and the copy were removed.
- Seen red: the same step with the check turned to expect the wrong-key copy to install failed the
  job.
