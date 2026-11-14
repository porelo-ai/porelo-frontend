# Readies the window's own Windows build for tool/windows-package.ps1: names its version, puts
# `porelo-host.exe` of that version beside the interface and checks the carried collection. Run from the
# repository's root after `flutter build windows --release`.
#
# Named as the Linux packages are: `<version>~snapshot.<run>` from `main`, `<version>` from a tag
# `v<version>`. Where GITHUB_ENV is set, the version and run go there as PORELO_WINDOWS_VERSION and
# PORELO_WINDOWS_RUN for the steps after this one; the last line printed is the version either way.
#
# The collection tool/host_collection.sh chose comes as PORELO_HOST_COLLECTION_VERSION, _SHA256 and _FILE and is
# compiled into porelo-host.exe, so its `--collection-info` and its check name exactly that one; without them the
# release porelo-host pins stands. A release carries only a released collection.
#Requires -Version 7.0
param(
  [string] $Release = 'build/windows/x64/runner/Release'
)

$ErrorActionPreference = 'Stop'

$base = ((Select-String -Path pubspec.yaml -Pattern '^version:').Line -replace 'version:\s*', '').Trim() -replace '-SNAPSHOT$', ''
$run = if ($env:GITHUB_RUN_NUMBER) { $env:GITHUB_RUN_NUMBER } else { '0' }
$release = $env:GITHUB_REF -like 'refs/tags/v*'
if ($release) { $version = $base } else { $version = "$base~snapshot.$run" }

$given = @($env:PORELO_HOST_COLLECTION_VERSION, $env:PORELO_HOST_COLLECTION_SHA256, $env:PORELO_HOST_COLLECTION_FILE)
$collectionDefines = @()
if (@($given | Where-Object { $_ }).Count -gt 0) {
  if (@($given | Where-Object { -not $_ }).Count -gt 0) {
    throw 'PORELO_HOST_COLLECTION_VERSION, _SHA256 and _FILE are given all three or none'
  }
  $collectionDefines = @(
    "-Dporelo_host.collection.version=$($given[0])",
    "-Dporelo_host.collection.file=$($given[2])",
    "-Dporelo_host.collection.sha256=$($given[1])"
  )
}

# `porelo-host.exe`, beside the interface and of its version: the interface calls this copy by its path.
dart pub get --directory=packages/porelo_host | Out-Null
if ($LASTEXITCODE -ne 0) { throw "dart pub get refused packages/porelo_host (exit $LASTEXITCODE)" }
dart compile exe packages/porelo_host/bin/porelo_host.dart "-Dporelo_host.version=$version" @collectionDefines -o "$Release/porelo-host.exe"
if ($LASTEXITCODE -ne 0) { Write-Error "porelo-host did not compile (exit $LASTEXITCODE)"; exit 1 }
$said = & "$Release/porelo-host.exe" --version
if ($said -ne $version) { Write-Error "porelo-host says '$said', not $version"; exit 1 }

$collection = (& "$Release/porelo-host.exe" --collection-info) -split ' '
if ($LASTEXITCODE -ne 0 -or $collection.Count -ne 3) { throw 'Cannot read the carried host collection' }
if ($collectionDefines.Count -gt 0 -and ($collection -join ' ') -ne "$($given[0]) $($given[1]) $($given[2])") {
  throw "porelo-host names the collection $($collection -join ' '), not $($given -join ' ')"
}
if ($release -and $collection[0] -notmatch '^\d+\.\d+\.\d+$') {
  throw "A release carries a released collection, not $($collection[0])"
}
Write-Host "porelo-host carries the collection $($collection[0]), SHA-256 $($collection[1])"
$collectionPath = Join-Path $Release $collection[2]
if (-not (Test-Path -PathType Leaf $collectionPath)) { throw "Missing carried collection: $collectionPath" }
$actual = (Get-FileHash -Algorithm SHA256 $collectionPath).Hash.ToLowerInvariant()
if ($actual -ne $collection[1]) { throw "Collection SHA-256: expected $($collection[1]); got $actual" }

if ($env:GITHUB_ENV) {
  "PORELO_WINDOWS_VERSION=$version" >> $env:GITHUB_ENV
  "PORELO_WINDOWS_RUN=$run" >> $env:GITHUB_ENV
}
$version
