# Readies the window's own Windows build for tool/windows-package.ps1: names its version, puts
# `porelo-host.exe` of that version beside the interface and checks the carried collection. Run from the
# repository's root after `flutter build windows --release`.
#
# Named as the Linux packages are: `<version>~snapshot.<run>` from `main`, `<version>` from a tag
# `v<version>`. Where GITHUB_ENV is set, the version and run go there as PORELO_WINDOWS_VERSION and
# PORELO_WINDOWS_RUN for the steps after this one; the last line printed is the version either way.
param(
  [string] $Release = 'build/windows/x64/runner/Release'
)

$ErrorActionPreference = 'Stop'

$base = ((Select-String -Path pubspec.yaml -Pattern '^version:').Line -replace 'version:\s*', '').Trim() -replace '-SNAPSHOT$', ''
$run = if ($env:GITHUB_RUN_NUMBER) { $env:GITHUB_RUN_NUMBER } else { '0' }
if ($env:GITHUB_REF -like 'refs/tags/v*') { $version = $base } else { $version = "$base~snapshot.$run" }

# `porelo-host.exe`, beside the interface and of its version: the interface calls this copy by its path.
dart pub get --directory=packages/porelo_host | Out-Null
dart compile exe packages/porelo_host/bin/porelo_host.dart "-Dporelo_host.version=$version" -o "$Release/porelo-host.exe"
if ($LASTEXITCODE -ne 0) { Write-Error "porelo-host did not compile (exit $LASTEXITCODE)"; exit 1 }
$said = & "$Release/porelo-host.exe" --version
if ($said -ne $version) { Write-Error "porelo-host says '$said', not $version"; exit 1 }

$collection = (& "$Release/porelo-host.exe" --collection-info) -split ' '
if ($LASTEXITCODE -ne 0 -or $collection.Count -ne 3) { throw 'Cannot read the pinned host collection' }
$collectionPath = Join-Path $Release $collection[2]
if (-not (Test-Path -PathType Leaf $collectionPath)) { throw "Missing carried collection: $collectionPath" }
$actual = (Get-FileHash -Algorithm SHA256 $collectionPath).Hash.ToLowerInvariant()
if ($actual -ne $collection[1]) { throw "Collection SHA-256: expected $($collection[1]); got $actual" }

if ($env:GITHUB_ENV) {
  "PORELO_WINDOWS_VERSION=$version" >> $env:GITHUB_ENV
  "PORELO_WINDOWS_RUN=$run" >> $env:GITHUB_ENV
}
$version
