# F507 — The Window's Windows Scripts Package Another App

```json
{
  "$schema": "issue-1.json",
  "id": "F507",
  "title": "The Window's Windows Scripts Package Another App",
  "state": "Implementing",
  "size": "M",
  "priority": "High",
  "rank": 20,
  "blockedBy": [],
  "covers": "The Windows packing and install check take the app's name, version, files, manifest and start as parameters, so another repository's Windows build calls them at a pinned commit; the window's own packages stay as they are, and neither script leaves a signing key or the app's files behind."
}
```

**Why this size.** two scripts, the two workflows that call them, and one contract another repository reads at a
pinned commit; M, near its upper end. The two leftover faults are fixed on the way, in the same code.

**What must be true.** `tool/windows-package.ps1` and `tool/windows-install-check.ps1` pack, sign and install-check
any Porelo app signed with the same certificate. The caller gives the app's files, name, version, manifest, icons
and how it starts. Another repository's Windows build checks out `tool/` at a pinned commit and calls them, instead
of keeping a copy. The window's own ZIP, MSIX, certificate and SHA256SUMS keep their names and contents.

No run leaves a signing key or the started app's files on the machine.

porelo-planner's Windows build, which serves the board on Windows, is the first other caller.

## Why

- `windows-package.ps1` is the window's alone. It reads `pubspec.yaml` (line 20), compiles and checks
  `porelo-host.exe` (lines 28-33), checks the carried collection (lines 35-40) and packs
  `build/windows/x64/runner/Release` (line 24). Its only parameters are `-Out` and `-ExpectedSignerThumbprint`.
- `windows-install-check.ps1` asserts `ai.porelo.frontend`, `CN=porelo.ai`, `PoreloInterface` and
  `porelo_frontend.exe` (lines 52-56), and looks for the process `porelo_frontend` (line 37).
- **The signing key stays on the machine.** The PFX is imported with `UserKeySet,PersistKeySet` (lines 68-70).
  The store is opened (line 72) before the `try` (line 73). The `finally` (lines 86-90) removes only the store entry,
  then disposes the certificate. Neither deletes the persisted private key's container. So every signed run leaves
  the key's container in the user's profile. A failure between the import and the `try` leaves the store entry too.
- **The throwaway keys stay too.** The install check's throwaway certificate (line 98) and the Windows trial's
  (`.github/workflows/windows.yml`, "Make a throwaway signing certificate") are removed with `Remove-Item` on
  `Cert:\` without `-DeleteKey` (install check line 198; the trial's removal step). Their key containers stay.
- **The install check leaves the app's files.** It starts the real app (line 135). The manifest declares
  `unvirtualizedResources`, so the app's writes land in the real profile and survive removing the package. At start
  the window writes its log, `%LOCALAPPDATA%\porelo\logs\frontend.log` (`lib/main.dart`, `WindowLog`), and it may
  write `%APPDATA%\porelo\frontend.json`. The check neither refuses them before nor removes them after
  (`finally`, lines 169-205).
- A GitHub runner is thrown away after the job, but a developer's or a self-hosted Windows machine is not.
- MakeAppx and SignTool are chosen by `Sort-Object FullName` (package lines 54-55, install check lines 77-78). That
  is a string sort, so `10.0.9…` wins over `10.0.22621.0`.
- `SHA256SUMS` hashes every `*.zip`, `*.msix` and `*.cer` in `-Out` (line 100), not only what this run made.

## Plan

- **The window's preparation moves out of the packer.** The version from `pubspec.yaml` and `GITHUB_REF`, the
  `porelo-host.exe` compile and its version check, and the collection check move into a script of the window's own,
  `tool/windows-prepare.ps1`. It ends by naming the folder, name and version it prepared. The packer reads no
  `pubspec.yaml` and compiles nothing.
- **`windows-package.ps1` takes the app as parameters.** Relative paths resolve against the working directory, never
  `$PSScriptRoot`, since the caller checks out `tool/` alone. The parameters, with each meaning in the script's head:
  - `-Source <dir>` or `-Zip <file>`, exactly one. With `-Source` the ZIP is packed as today. With `-Zip` the ZIP is
    taken as it is and must be named `<prefix>-<version>-windows-x64.zip`; its files make the MSIX layout.
  - The file prefix (today `porelo-frontend`) and `-Version` (`x.y.z` or `x.y.z~snapshot.n`), both required.
  - `-Run`: `GITHUB_RUN_NUMBER`, else 0; 0 to 65535; equal to the version's snapshot run where it has one. The MSIX
    version is `<x.y.z>.<run>`.
  - The packaging folder (default `packaging/windows`): holds `AppxManifest.xml.in` and `assets/`. The app's name,
    identity, publisher, executable, display names, alias and icons come from this folder, not from the script.
  - The tested executable (optional): the file of its name in the ZIP and in the MSIX must have its SHA-256.
  - `-Out` and `-ExpectedSignerThumbprint` as today. The thumbprint is also checked on the loaded certificate before
    it enters the store.
  - `-RequireSigning`: with an empty `WINDOWS_SIGNING_PFX` or `WINDOWS_SIGNING_PFX_PASSWORD` the run stops before
    packing, naming the secret. Without it an unsigned MSIX is packed and dropped, as today.
- **The MSIX is checked after packing and after signing.** Its entries, apart from `[Content_Types].xml`,
  `AppxBlockMap.xml`, `AppxSignature.p7x` and `AppxMetadata/`, equal the ZIP's files plus `AppxManifest.xml` and
  `assets/*`. The packed manifest's Identity Name and Publisher equal the template's; its Version is the MSIX version.
- **The signing key is never left behind.** The import, the store and the signing all sit in one `try`. The
  `finally` removes the store entry and deletes the key's container whatever its provider: CNG `Key.Delete()`; CSP
  `PersistKeyInCsp = $false`, then `Clear()`; any other kind fails the run, naming it. It names anything it could
  not remove. The throwaway certificates of the install check and the trial are removed with `-DeleteKey`.
- **SDK tools by version.** MakeAppx and SignTool are chosen by the SDK folder's `[version]`, in one helper both
  scripts use.
- **`SHA256SUMS` covers only this run's** ZIP, MSIX and certificate. The certificate keeps its name
  `porelo-msix.cer`.
- **`windows-install-check.ps1` reads the app from the MSIX.** The identity, application id and executable come from
  the packed manifest; an optional expected identity asserts it. The process is found by the executable's path.
  - An alias (optional, `<name>.exe`): with PATH set to the user's `WindowsApps`, `System32` and `%SystemRoot%`,
    `where` resolves it to `%LOCALAPPDATA%\Microsoft\WindowsApps\<alias>`. It is started through `cmd.exe /d /c` from
    a fresh empty folder, its output to files. Exactly one process runs from the install location.
  - A ready script (optional): run after the start with the seconds left; it returns once the app is ready and
    throws otherwise. Without it, today's test holds: a window seen, or the process alive for 5 s.
  - **The paths the app writes outside its package**, required: each must not exist before the check, which
    otherwise refuses, naming it. Each is removed in the `finally`, after the processes stop. Anything left is named.
  - The wrong-key refusal stays, for any package.
- **The window's Build and Windows trial** call `windows-prepare.ps1`, then both scripts with the window's own values,
  its log and settings among the paths it leaves.
- **The contract is written down** in the scripts' heads: each parameter, its default, and that a change to them is a
  change another repository pins against.

## Acceptance

- The Build's Windows job and the Windows trial pass. Their ZIP, MSIX, `porelo-msix.cer` and `SHA256SUMS` have the
  same names as before.
- The trial packs a second, small app from a `-Zip`, with a manifest that has an app execution alias and a tested
  executable. The MSIX holds exactly the ZIP's files plus the manifest and its icons. A ZIP whose executable differs
  from the tested one is refused. Both are seen red first.
- With `-RequireSigning` and an empty secret, the run stops before packing, naming the secret. Seen red first.
- **No key container is left.** A trial step lists `certutil -user -key` before Pack and again after the install
  check, under `if: always()`. The two lists are equal, and none names a container of the signing or throwaway
  certificates. A forced failure between the import and SignTool still leaves the lists equal. Seen red with
  today's order.
- **No app file is left.** After the install check, under `if: always()`, a trial step finds none of the paths the
  app writes (`%LOCALAPPDATA%\porelo`, `%APPDATA%\porelo` as the window declares them) and no folder of the
  package's family under `%LOCALAPPDATA%\Packages`. Seen red with today's check.
- The install check refuses a declared path that already exists, naming it.

## To be checked

- Which paths the window writes at its first start on Windows besides its log: `frontend.json`, the one-instance
  lock, `porelo-host`'s folder under `%LOCALAPPDATA%`. Read in the trial's run with a listing before and after.
- That `Remove-Item -DeleteKey` on `Cert:\` works in PowerShell 7 on the runner, else the key is deleted as Pack does.

## Measured

- The Windows suite alone (`flutter test --exclude-tags "linux || documents" --concurrency 1` on `windows-2025`) takes
  about 32 minutes: trial 3 (run 43297658386) ran steadily, no test hung, and was in file 326 of 346 when its 30-minute
  limit cut it. The trial's Test step has 45 minutes and its job 75 since then.
