# Proves both rejection of an untrusted signing key and startup of the signed, installed MSIX.
# Run with PowerShell 7 on a Windows runner with permission to trust a public certificate.
#Requires -Version 7.0
param(
  [Parameter(Mandatory)][string] $Msix,
  [Parameter(Mandatory)][string] $Cer
)

$ErrorActionPreference = 'Stop'

function Invoke-AppxOperation([string] $Operation, [string] $Value) {
  # Appx needs Windows PowerShell; a separate job also bounds deployment calls that can stall.
  $job = Start-Job -PSVersion 5.1 -ArgumentList $Operation, $Value -ScriptBlock {
    param($Operation, $Value)
    $ErrorActionPreference = 'Stop'
    switch ($Operation) {
      'Get' { Get-AppxPackage -Name ai.porelo.frontend }
      'Add' { Add-AppxPackage -Path $Value }
      'Remove' { Remove-AppxPackage -Package $Value }
      default { throw "Asked for Get, Add or Remove; got '$Operation'" }
    }
  }
  try {
    if (-not (Wait-Job $job -Timeout 60)) {
      throw "Asked Appx to $Operation '$Value' within 60 s; got job state $($job.State) at the deadline"
    }
    Receive-Job $job -ErrorAction Stop
    if ($job.State -ne 'Completed') {
      throw "Asked Appx to $Operation '$Value'; got job state $($job.State): $($job.ChildJobs[0].JobStateInfo.Reason)"
    }
  } finally {
    Remove-Job $job -Force
  }
}

function Get-InstalledProcesses([string] $Executable) {
  @(Get-Process -Name porelo_frontend -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $Executable })
}

$Msix = (Resolve-Path -LiteralPath $Msix).Path
$Cer = (Resolve-Path -LiteralPath $Cer).Path
$archive = [IO.Compression.ZipFile]::OpenRead($Msix)
try {
  $entry = $archive.GetEntry('AppxManifest.xml')
  if (-not $entry) { throw "Asked for AppxManifest.xml in '$Msix'; got no entry" }
  $reader = [IO.StreamReader]::new($entry.Open())
  try { [xml] $manifest = $reader.ReadToEnd() } finally { $reader.Dispose() }
} finally { $archive.Dispose() }
$identity = $manifest.Package.Identity
$application = @($manifest.Package.Applications.Application)
if ($identity.Name -ne 'ai.porelo.frontend' -or $identity.Publisher -ne 'CN=porelo.ai' -or
    $application.Count -ne 1 -or $application[0].Id -ne 'PoreloInterface' -or
    $application[0].Executable -ne 'porelo_frontend.exe') {
  throw "Asked for ai.porelo.frontend, CN=porelo.ai and PoreloInterface/porelo_frontend.exe; got $($identity.OuterXml) $($manifest.Package.Applications.OuterXml)"
}
$version = [version]::Parse($identity.Version)
$publicCertificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($Cer)
$thumbprint = $publicCertificate.Thumbprint
try {
  if ($publicCertificate.Subject -ne $identity.Publisher) {
    throw "Asked for certificate subject '$($identity.Publisher)'; got '$($publicCertificate.Subject)'"
  }
  $signer = (Get-AuthenticodeSignature -LiteralPath $Msix).SignerCertificate
  if (-not $signer -or $signer.Thumbprint -ne $thumbprint) {
    throw "Asked for MSIX signer $thumbprint from '$Cer'; got '$($signer.Thumbprint)'"
  }
} finally { $publicCertificate.Dispose() }
$trustedPath = "Cert:\LocalMachine\TrustedPeople\$thumbprint"
if (Test-Path $trustedPath) {
  throw "Asked for no existing certificate at '$trustedPath'; got an existing certificate"
}
$existing = @(Invoke-AppxOperation Get '')
if ($existing.Count -ne 0) {
  throw "Asked for no installed ai.porelo.frontend; got $($existing.PackageFullName -join ', ')"
}
$kit = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe" -ErrorAction SilentlyContinue |
  Sort-Object FullName | Select-Object -Last 1
if (-not $kit) { throw 'Asked for Windows SDK makeappx.exe; got no matching SDK tool' }
$signtool = Join-Path $kit.DirectoryName 'signtool.exe'
if (-not (Test-Path $signtool)) { throw "Asked for '$signtool'; got no file" }
$copy = Join-Path ([IO.Path]::GetTempPath()) "porelo-untrusted-$([guid]::NewGuid()).msix"
$throwaway = $null
$trustAttempted = $false
$deploymentAttempted = $false
$executable = $null
$failure = $null
$cleanupFailures = [Collections.Generic.List[string]]::new()
try {
  $trustAttempted = $true
  Import-Certificate -FilePath $Cer -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null
  if (-not (Test-Path $trustedPath)) {
    throw "Asked to import '$Cer' into TrustedPeople; got no certificate at '$trustedPath'"
  }

  # The same publisher with another key must fail even while the intended public certificate is trusted.
  Copy-Item -LiteralPath $Msix -Destination $copy
  $throwaway = New-SelfSignedCertificate -Type CodeSigningCert -Subject $identity.Publisher -CertStoreLocation Cert:\CurrentUser\My
  if ($throwaway.Thumbprint -eq $thumbprint -or $throwaway.GetPublicKeyString() -eq $signer.GetPublicKeyString()) {
    throw "Asked for a different signing key; got certificate $($throwaway.Thumbprint)"
  }
  $signing = Start-Process -FilePath $signtool -ArgumentList @('sign', '/fd', 'SHA256', '/s', 'My', '/sha1', $throwaway.Thumbprint, ('"{0}"' -f $copy)) -NoNewWindow -PassThru
  try {
    if (-not $signing.WaitForExit(30000)) {
      $signing.Kill()
      throw 'Asked SignTool to re-sign the copy within 30 s; got a running process at the deadline'
    }
    if ($signing.ExitCode -ne 0) { throw "Asked SignTool to re-sign the copy; got exit $($signing.ExitCode)" }
  } finally { $signing.Dispose() }
  $copySigner = (Get-AuthenticodeSignature -LiteralPath $copy).SignerCertificate
  if ($copySigner.Thumbprint -ne $throwaway.Thumbprint) {
    throw "Asked for copy signer $($throwaway.Thumbprint); got '$($copySigner.Thumbprint)'"
  }
  $deploymentAttempted = $true
  $refusal = $null
  try { Invoke-AppxOperation Add $copy } catch { $refusal = $_ }
  $unexpected = @(Invoke-AppxOperation Get '')
  if (-not $refusal -or $unexpected.Count -ne 0) {
    throw "Asked Add-AppxPackage to refuse the wrong-key copy; got error '$refusal' and installed packages '$($unexpected.PackageFullName -join ', ')'"
  }
  # A timeout is not evidence that Windows rejected the signing key.
  if ($refusal.Exception.Message -notmatch '0x800B0109|0x800B010A') {
    throw "Asked for an untrusted-certificate refusal (0x800B0109 or 0x800B010A); got $refusal"
  }
  "Wrong-key copy refused: $refusal"

  Invoke-AppxOperation Add $Msix
  $installed = @(Invoke-AppxOperation Get '')
  if ($installed.Count -ne 1 -or [version]$installed[0].Version -ne $version) {
    throw "Asked for installed ai.porelo.frontend version $version; got '$($installed.Version -join ', ')' ($($installed.Count) packages)"
  }
  $package = $installed[0]
  $executable = Join-Path $package.InstallLocation 'porelo_frontend.exe'
  $activation = "shell:AppsFolder\$($package.PackageFamilyName)!$($application[0].Id)"
  Start-Process explorer.exe -ArgumentList $activation
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $alive = $null
  $aliveSince = $null
  $observed = 'no process from the install folder'
  $started = $false
  while ($watch.Elapsed.TotalSeconds -lt 30) {
    $processes = @(Get-InstalledProcesses $executable)
    if ($processes.Count -gt 0) {
      $process = $processes[0]
      $observed = "process $($process.Id) from '$($process.Path)'"
      if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
        "Started through ${activation}: window seen on $observed"
        $started = $true
        break
      }
      if ($alive -ne $process.Id) {
        $alive = $process.Id
        $aliveSince = $watch.Elapsed.TotalSeconds
      }
      if ($watch.Elapsed.TotalSeconds - $aliveSince -ge 5) {
        "Started through ${activation}: no window seen; $observed alive for 5 s"
        $started = $true
        break
      }
    } else {
      $alive = $null
      $aliveSince = $null
    }
    Start-Sleep -Milliseconds 200
  }
  if (-not $started) { throw "Asked '$activation' to start '$executable' within 30 s; got $observed" }
} catch {
  $failure = $_
} finally {
  # Each cleanup is attempted even when another fails, so the failure names every leftover.
  if ($executable) {
    try {
      foreach ($process in @(Get-InstalledProcesses $executable)) {
        Stop-Process -Id $process.Id -Force
        if (-not $process.WaitForExit(5000)) { throw "Asked process $($process.Id) to stop within 5 s; got a running process" }
        "Stopped process $($process.Id) from '$executable'"
      }
    } catch { $cleanupFailures.Add("Stop '$executable': $_") }
  }
  if ($deploymentAttempted) {
    try {
      foreach ($package in @(Invoke-AppxOperation Get '')) {
        Invoke-AppxOperation Remove $package.PackageFullName
        "Removed package $($package.PackageFullName)"
      }
      $remaining = @(Invoke-AppxOperation Get '')
      if ($remaining.Count) { throw "Asked for no installed package; got '$($remaining.PackageFullName -join ', ')'" }
    } catch { $cleanupFailures.Add("Remove installed package: $_") }
  }
  foreach ($path in @(
    $(if ($trustAttempted) { $trustedPath }),
    $(if ($throwaway) { "Cert:\CurrentUser\My\$($throwaway.Thumbprint)" }),
    $copy
  )) {
    if (-not $path) { continue }
    try {
      if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        if (Test-Path -LiteralPath $path) { throw "Asked to remove '$path'; got an existing item" }
        "Removed $path"
      }
    } catch { $cleanupFailures.Add("Remove '$path': $_") }
  }
  if ($throwaway) { $throwaway.Dispose() }
}
if ($failure) { Write-Host "Install check failed: $failure" }
if ($cleanupFailures.Count) { throw "Asked for complete cleanup; got: $($cleanupFailures -join '; ')" }
if ($failure) { throw $failure }
