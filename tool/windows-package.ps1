# Packs a Porelo app's Windows build: a ZIP to unpack and start, and an MSIX to install, with a
# SHA256SUMS over what this run made. The window calls it after tool/windows-prepare.ps1; another
# repository's Windows build checks out this repository's tool/ at a pinned commit and calls it with its
# own app. The parameters below are that contract: a change to them is a change another repository pins.
#
#   -Source <dir>       the built folder; packed into the ZIP. Exactly one of -Source and -Zip.
#   -Zip <file>         a ZIP made elsewhere, taken as it is; named <Prefix>-<Version>-windows-x64.zip.
#   -Prefix <name>      the files' name prefix, for example porelo-frontend. Required.
#   -Version <v>        x.y.z, or x.y.z~snapshot.n from a branch. Required.
#   -Run <n>            0 to 65535; GITHUB_RUN_NUMBER, else 0. Equal to n of a snapshot version.
#                       The MSIX version is x.y.z.<Run>, four numbers as an MSIX takes them.
#   -Packaging <dir>    holds AppxManifest.xml.in (@VERSION@ filled in) and assets/; packaging/windows.
#                       The app's identity, publisher, executable, names and alias come from it.
#   -TestedExecutable <file>
#                       optional: the file of its name in the ZIP and in the MSIX has its SHA-256.
#   -Out <dir>          where the ZIP, the MSIX, porelo-msix.cer and SHA256SUMS go; build/windows-zip.
#   -RequireSigning     stop before packing where a signing secret is empty, naming it.
#   -ExpectedSignerThumbprint
#                       the certificate the MSIX must be signed with; the production key by default.
#
# Relative paths are taken from the working directory, never from this script's folder.
#
# The MSIX is signed only where WINDOWS_SIGNING_PFX (the certificate with its key, base64) and
# WINDOWS_SIGNING_PFX_PASSWORD are set. Elsewhere it is packed and left unsigned, which proves the
# manifest and the layout, and it is said so. The key goes into this user's certificate store only for
# `signtool`, and it and its key container are taken out whatever happens; it is never a file, and its
# password never on a command line.
#Requires -Version 7.0
param(
  [string] $Source,
  [string] $Zip,
  [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
  [string] $Prefix,
  [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+(~snapshot\.\d+)?$')]
  [string] $Version,
  [ValidateRange(0, 65535)]
  [int] $Run = $(if ($env:GITHUB_RUN_NUMBER) { [int] $env:GITHUB_RUN_NUMBER } else { 0 }),
  [string] $Packaging = 'packaging/windows',
  [string] $TestedExecutable,
  [string] $Out = 'build/windows-zip',
  [switch] $RequireSigning,
  [ValidatePattern('^[A-Fa-f0-9]{40}$')]
  [string] $ExpectedSignerThumbprint = '8BD1F34465EDC9B11A162B39C6644231851DEE24'
)

$ErrorActionPreference = 'Stop'

function Get-SdkTool([string] $Tool) {
  # By the SDK's version, not its name: `10.0.9...` sorts after `10.0.22621.0` as a string.
  $found = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\$Tool" -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Parent.Name -as [version] } |
    Sort-Object { [version] $_.Directory.Parent.Name } | Select-Object -Last 1
  if (-not $found) { throw "Asked for $Tool from the Windows SDK; got none on this machine" }
  $found.FullName
}

function Get-Sha256([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }

# The files of a folder by their path in it, `/` between the parts, as a package lists them.
function Get-Files([string] $Folder) {
  $root = (Resolve-Path -LiteralPath $Folder).Path.TrimEnd('\', '/')
  @(Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
      $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    } | Sort-Object)
}

# The MSIX's own files, its block map, signature and content types left out, its manifest, and the
# SHA-256 of the tested executable in it.
function Read-Msix([string] $Path) {
  $archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
  try {
    $names = @($archive.Entries | ForEach-Object { [Uri]::UnescapeDataString($_.FullName) } |
      Where-Object { $_ -notin '[Content_Types].xml', 'AppxBlockMap.xml', 'AppxSignature.p7x' -and
        -not $_.StartsWith('AppxMetadata/') -and -not $_.EndsWith('/') } | Sort-Object)
    $entry = $archive.GetEntry('AppxManifest.xml')
    if (-not $entry) { throw "Asked for AppxManifest.xml in '$Path'; got no entry" }
    $reader = [IO.StreamReader]::new($entry.Open())
    try { [xml] $manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
    $tested = $null
    if ($TestedExecutable) {
      $testedEntry = $archive.GetEntry([IO.Path]::GetFileName($TestedExecutable))
      if (-not $testedEntry) { throw "Asked for $([IO.Path]::GetFileName($TestedExecutable)) in '$Path'; got no entry" }
      $stream = $testedEntry.Open()
      try {
        $tested = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
      } finally { $stream.Dispose() }
    }
    [pscustomobject] @{ Names = $names; Manifest = $manifest; Tested = $tested }
  } finally { $archive.Dispose() }
}

function Assert-Msix([string] $Path, [string[]] $Expected, [xml] $Template, [string] $MsixVersion, [string] $When) {
  $read = Read-Msix $Path
  $missing = @($Expected | Where-Object { $_ -notin $read.Names })
  $extra = @($read.Names | Where-Object { $_ -notin $Expected })
  if ($missing.Count -or $extra.Count) {
    throw "Asked $When for the MSIX to hold the ZIP's files, its manifest and assets; missing '$($missing -join ', ')', extra '$($extra -join ', ')'"
  }
  $packed = $read.Manifest.Package.Identity
  $wanted = $Template.Package.Identity
  if ($packed.Name -ne $wanted.Name -or $packed.Publisher -ne $wanted.Publisher -or $packed.Version -ne $MsixVersion) {
    throw "Asked $When for identity $($wanted.Name), $($wanted.Publisher), $MsixVersion; got $($packed.Name), $($packed.Publisher), $($packed.Version)"
  }
  if ($TestedExecutable -and $read.Tested -ne $script:testedHash) {
    throw "Asked $When for the tested $([IO.Path]::GetFileName($TestedExecutable)) ($script:testedHash); got $($read.Tested)"
  }
}

if ([bool] $Source -eq [bool] $Zip) { throw 'Asked for exactly one of -Source and -Zip' }
$snapshot = [regex]::Match($Version, '~snapshot\.(\d+)$')
if ($snapshot.Success -and [int] $snapshot.Groups[1].Value -ne $Run) {
  throw "Asked for run $Run; the version $Version names run $($snapshot.Groups[1].Value)"
}
if ($RequireSigning) {
  foreach ($secret in 'WINDOWS_SIGNING_PFX', 'WINDOWS_SIGNING_PFX_PASSWORD') {
    if (-not [Environment]::GetEnvironmentVariable($secret)) { throw "Asked to sign; $secret is empty" }
  }
}
$template = Join-Path $Packaging 'AppxManifest.xml.in'
$assets = Join-Path $Packaging 'assets'
if (-not (Test-Path -PathType Leaf $template)) { throw "Asked for '$template'; got no file" }
if (-not (Test-Path -PathType Container $assets)) { throw "Asked for '$assets'; got no folder" }
$script:testedHash = $null
if ($TestedExecutable) { $script:testedHash = Get-Sha256 $TestedExecutable }

$base = $Version -replace '~snapshot\.\d+$', ''
$msixVersion = "$base.$Run"
$name = "$Prefix-$Version-windows-x64"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$zipFile = Join-Path $Out "$name.zip"
$msix = Join-Path $Out "$name.msix"
$certificateFile = Join-Path $Out 'porelo-msix.cer'

$layout = Join-Path ([IO.Path]::GetTempPath()) "porelo-msix-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $layout | Out-Null
try {
  if ($Source) {
    # The ZIP: the built folder as it is.
    Compress-Archive -Path (Join-Path $Source '*') -DestinationPath $zipFile -Force
  } else {
    if ([IO.Path]::GetFileName($Zip) -ne "$name.zip") { throw "Asked for a ZIP named $name.zip; got '$Zip'" }
    if ((Resolve-Path -LiteralPath $Zip).Path -ne [IO.Path]::GetFullPath($zipFile)) { Copy-Item -LiteralPath $Zip $zipFile -Force }
  }
  # The MSIX: the ZIP's files, the manifest and its logos.
  Expand-Archive -LiteralPath $zipFile -DestinationPath $layout
  $files = Get-Files $layout
  if ($TestedExecutable) {
    $inZip = Join-Path $layout ([IO.Path]::GetFileName($TestedExecutable))
    if (-not (Test-Path -PathType Leaf $inZip)) { throw "Asked for $([IO.Path]::GetFileName($TestedExecutable)) in the ZIP; got none" }
    if ((Get-Sha256 $inZip) -ne $script:testedHash) {
      throw "Asked for the tested $([IO.Path]::GetFileName($TestedExecutable)) ($script:testedHash) in the ZIP; got $(Get-Sha256 $inZip)"
    }
  }
  Copy-Item -Recurse $assets (Join-Path $layout 'assets')
  $filled = (Get-Content -Raw $template).Replace('@VERSION@', $msixVersion)
  [xml] $templateXml = $filled
  $filled | Set-Content -Encoding utf8 (Join-Path $layout 'AppxManifest.xml')
  $expected = @(Get-Files $layout)

  $makeappx = Get-SdkTool 'makeappx.exe'
  & $makeappx pack /d $layout /p $msix /o /h SHA256
  if ($LASTEXITCODE -ne 0) { throw "MakeAppx refused the package (exit $LASTEXITCODE)" }
} finally {
  Remove-Item -Recurse -Force -LiteralPath $layout -ErrorAction SilentlyContinue
}
Assert-Msix $msix $expected $templateXml $msixVersion 'after packing'
"packed the ZIP's $($files.Count) files into $msix, version $msixVersion"

$made = @("$name.zip")
if ($env:WINDOWS_SIGNING_PFX) {
  # The key is never written to a file and its password never goes on a command line: the PFX is read
  # from the environment into memory, put in this user's certificate store for the one signing, found
  # there by its thumbprint, and taken out again, its key container with it, whatever happened.
  $signtool = Get-SdkTool 'signtool.exe'
  $loaded = $null
  $cause = $null
  $store = $null
  $added = $false
  $leftovers = [Collections.Generic.List[string]]::new()
  try {
    $flags = [Security.Cryptography.X509Certificates.X509KeyStorageFlags]'UserKeySet,PersistKeySet'
    $loaded = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
      [Convert]::FromBase64String($env:WINDOWS_SIGNING_PFX), $env:WINDOWS_SIGNING_PFX_PASSWORD, $flags)
    # A subject can be copied: pin the production key by default, or the trial's explicit thumbprint.
    if ($loaded.Thumbprint -ne $ExpectedSignerThumbprint) {
      throw "Asked for signing certificate $ExpectedSignerThumbprint; WINDOWS_SIGNING_PFX holds $($loaded.Thumbprint)"
    }
    $store = [Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
    $store.Open('ReadWrite')
    # A certificate this user had before is left in the store; only one this run put there is taken out.
    if (-not $store.Certificates.Find('FindByThumbprint', $loaded.Thumbprint, $false).Count) {
      $store.Add($loaded)
      $added = $true
    }
    if ($env:PORELO_WINDOWS_FAIL_BEFORE_SIGNING -eq 'yes') { throw 'Asked to fail before SignTool, as the trial does' }
    & $signtool sign /fd SHA256 /s My /sha1 $loaded.Thumbprint $msix
    if ($LASTEXITCODE -ne 0) { throw "SignTool did not sign the MSIX (exit $LASTEXITCODE)" }
    $signature = Get-AuthenticodeSignature $msix
    # Not trusted here is expected of a key not installed on this machine; a broken or missing signature is not.
    if ($signature.Status -in 'HashMismatch', 'NotSigned', 'Incompatible', 'NotSupportedFileFormat') {
      throw "Asked for a signed MSIX; got signature status $($signature.Status)"
    }
    $signer = $signature.SignerCertificate
    if ($signer.Thumbprint -ne $ExpectedSignerThumbprint) {
      throw "the MSIX is signed by $($signer.Subject), thumbprint $($signer.Thumbprint), not $ExpectedSignerThumbprint"
    }
    # The public half beside it, for a person to trust once on their machine.
    [IO.File]::WriteAllBytes($certificateFile, $loaded.Export('Cert'))
    "signed by $($signer.Subject), thumbprint $($signer.Thumbprint)"
  } catch {
    $cause = $_
    throw
  } finally {
    # Each removal is tried even when another fails, so the run names everything left.
    if ($added) {
      try { $store.Remove($loaded) } catch { $leftovers.Add("the certificate in CurrentUser\My: $_") }
    }
    if ($store) { $store.Close() }
    if ($loaded) {
      try {
        $key = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($loaded)
        if (-not $key) { $key = [Security.Cryptography.X509Certificates.ECDsaCertificateExtensions]::GetECDsaPrivateKey($loaded) }
        if ($key -is [Security.Cryptography.RSACng] -or $key -is [Security.Cryptography.ECDsaCng]) {
          $key.Key.Delete()
        } elseif ($key -is [Security.Cryptography.RSACryptoServiceProvider]) {
          $key.PersistKeyInCsp = $false
          $key.Clear()
        } else {
          throw "a key of kind '$($key.GetType().FullName)', which this script cannot delete"
        }
      } catch { $leftovers.Add("the signing key's container: $_") }
      $loaded.Dispose()
    }
    if ($leftovers.Count) {
      # Said with the failure that came first, which this error replaces.
      $first = if ($cause) { "; the signing had failed before: $cause" } else { '' }
      Write-Error "Asked to leave no signing key behind; left $($leftovers -join '; ')$first"
    }
  }
  Assert-Msix $msix $expected $templateXml $msixVersion 'after signing'
  $made += "$name.msix", 'porelo-msix.cer'
} else {
  # An unsigned MSIX installs nowhere, so it is not offered: packing it proved the manifest.
  Remove-Item -Force $msix
  'no WINDOWS_SIGNING_PFX here: the MSIX was packed to prove it, and is not kept unsigned'
}

# What this run made, nothing else in -Out. Written with `\n` alone: `Set-Content` ends lines with
# `\r\n` on Windows, and `sha256sum -c` then looks for a file whose name ends in `\r`.
$sums = $made | ForEach-Object { "$(Get-Sha256 (Join-Path $Out $_))  $_`n" }
$sumsFile = Join-Path (Resolve-Path -LiteralPath $Out).Path 'SHA256SUMS'
[IO.File]::WriteAllText($sumsFile, ($sums -join ''))
if ([IO.File]::ReadAllText($sumsFile).Contains("`r")) {
  throw 'SHA256SUMS has a carriage return in it; sha256sum -c would not find the files'
}
Get-Content $sumsFile
