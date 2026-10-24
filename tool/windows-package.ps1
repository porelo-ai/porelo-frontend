# Packs the Windows build: a ZIP to unpack and start, and an MSIX to install, with a SHA256SUMS over
# what it made. Run from the repository's root after `flutter build windows --release`.
#
# Named as the Linux packages are: `<version>~snapshot.<run>` from `main`, `<version>` from a tag
# `v<version>`. The MSIX takes four numbers, so it is `<major>.<minor>.<patch>.<run>`.
#
# The MSIX is signed only where WINDOWS_SIGNING_PFX (the certificate with its key, base64) and
# WINDOWS_SIGNING_PFX_PASSWORD are set: the Build on `main` and tags. Elsewhere it is packed and left
# unsigned, which proves the manifest and the layout, and it is said so. The key goes into this
# user's certificate store only for `signtool`, and is taken out whatever happens; it is never a file,
# and its password never on a command line.
param(
  [string] $Out = 'build/windows-zip',
  [ValidatePattern('^[A-Fa-f0-9]{40}$')]
  [string] $ExpectedSignerThumbprint = '8BD1F34465EDC9B11A162B39C6644231851DEE24'
)

$ErrorActionPreference = 'Stop'

$base = ((Select-String -Path pubspec.yaml -Pattern '^version:').Line -replace 'version:\s*', '').Trim() -replace '-SNAPSHOT$', ''
$run = if ($env:GITHUB_RUN_NUMBER) { $env:GITHUB_RUN_NUMBER } else { '0' }
if ($env:GITHUB_REF -like 'refs/tags/v*') { $version = $base } else { $version = "$base~snapshot.$run" }
$msixVersion = "$base.$run"
$release = 'build/windows/x64/runner/Release'
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$name = "porelo-frontend-$version-windows-x64"

# `porelo-host.exe`, beside the interface and of its version: the interface calls this copy by its path.
dart pub get --directory=packages/porelo_host | Out-Null
dart compile exe packages/porelo_host/bin/porelo_host.dart "-Dporelo_host.version=$version" -o "$release/porelo-host.exe"
if ($LASTEXITCODE -ne 0) { Write-Error "porelo-host did not compile (exit $LASTEXITCODE)"; exit 1 }
$said = & "$release/porelo-host.exe" --version
if ($said -ne $version) { Write-Error "porelo-host says '$said', not $version"; exit 1 }

$collection = (& "$release/porelo-host.exe" --collection-info) -split ' '
if ($LASTEXITCODE -ne 0 -or $collection.Count -ne 3) { throw 'Cannot read the pinned host collection' }
$collectionPath = Join-Path $release $collection[2]
if (-not (Test-Path -PathType Leaf $collectionPath)) { throw "Missing carried collection: $collectionPath" }
$actual = (Get-FileHash -Algorithm SHA256 $collectionPath).Hash.ToLowerInvariant()
if ($actual -ne $collection[1]) { throw "Collection SHA-256: expected $($collection[1]); got $actual" }

# The ZIP: the built folder as it is.
Compress-Archive -Path "$release/*" -DestinationPath "$Out/$name.zip" -Force

# The MSIX: the same folder, the manifest and its logos.
$layout = Join-Path ([System.IO.Path]::GetTempPath()) "porelo-msix-$run"
if (Test-Path $layout) { Remove-Item -Recurse -Force $layout }
New-Item -ItemType Directory -Path $layout | Out-Null
Copy-Item -Recurse "$release/*" $layout
Copy-Item -Recurse packaging/windows/assets (Join-Path $layout 'assets')
(Get-Content -Raw packaging/windows/AppxManifest.xml.in).Replace('@VERSION@', $msixVersion) |
  Set-Content -Encoding utf8 (Join-Path $layout 'AppxManifest.xml')

$kit = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe" -ErrorAction SilentlyContinue |
  Sort-Object FullName | Select-Object -Last 1
if (-not $kit) { Write-Error 'no MakeAppx.exe from the Windows SDK on this machine'; exit 1 }
$bin = $kit.DirectoryName
$msix = "$Out/$name.msix"
& "$bin\makeappx.exe" pack /d $layout /p $msix /o /h SHA256
if ($LASTEXITCODE -ne 0) { Write-Error "MakeAppx refused the package (exit $LASTEXITCODE)"; exit 1 }
Remove-Item -Recurse -Force $layout

if ($env:WINDOWS_SIGNING_PFX) {
  # The key is never written to a file and its password never goes on a command line: the PFX is read
  # from the environment into memory, put in this user's certificate store for the one signing, found
  # there by its thumbprint, and taken out again whatever happened.
  $pinned = $ExpectedSignerThumbprint
  $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]'UserKeySet,PersistKeySet'
  $loaded = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
    [Convert]::FromBase64String($env:WINDOWS_SIGNING_PFX), $env:WINDOWS_SIGNING_PFX_PASSWORD, $flags)
  $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
  $store.Open('ReadWrite')
  try {
    $store.Add($loaded)
    & "$bin\signtool.exe" sign /fd SHA256 /s My /sha1 $loaded.Thumbprint $msix
    if ($LASTEXITCODE -ne 0) { Write-Error "SignTool did not sign the MSIX (exit $LASTEXITCODE)"; exit 1 }
    # The public half beside it, for a person to trust once on their machine.
    [IO.File]::WriteAllBytes("$Out/porelo-msix.cer", $loaded.Export('Cert'))
    # A subject can be copied: pin the production key by default, or the trial's explicit thumbprint.
    $signer = (Get-AuthenticodeSignature $msix).SignerCertificate
    if ($signer.Thumbprint -ne $pinned) {
      Write-Error "the MSIX is signed by $($signer.Subject), thumbprint $($signer.Thumbprint), not $pinned"
      exit 1
    }
    "signed by $($signer.Subject), thumbprint $($signer.Thumbprint)"
  } finally {
    $store.Remove($loaded)
    $store.Close()
    $loaded.Dispose()
  }
} else {
  # An unsigned MSIX installs nowhere, so it is not offered: packing it proved the manifest.
  Remove-Item -Force $msix
  'no WINDOWS_SIGNING_PFX here: the MSIX was packed to prove it, and is not kept unsigned'
}

# Written with `\n` alone: `Set-Content` ends lines with `\r\n` on Windows, and `sha256sum -c` then
# looks for a file whose name ends in `\r`.
Push-Location $Out
$sums = Get-ChildItem *.zip, *.msix, *.cer -ErrorAction SilentlyContinue |
  ForEach-Object { "$((Get-FileHash $_.Name -Algorithm SHA256).Hash.ToLower())  $($_.Name)`n" }
[System.IO.File]::WriteAllText("$PWD/SHA256SUMS", ($sums -join ''))
if ([System.IO.File]::ReadAllText("$PWD/SHA256SUMS").Contains("`r")) {
  Write-Error 'SHA256SUMS has a carriage return in it; sha256sum -c would not find the files'
  exit 1
}
Get-Content SHA256SUMS
Pop-Location
