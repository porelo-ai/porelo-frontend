# Proves both rejection of an untrusted signing key and startup of the signed, installed MSIX, of any
# Porelo app tool/windows-package.ps1 packed. Run with PowerShell 7 on a Windows runner with permission to
# trust a public certificate. Another repository calls it at a pinned commit; the parameters are that
# contract:
#
#   -Msix <file>, -Cer <file>   the signed package and the public certificate it was signed with.
#   -ExpectedIdentity <name>    optional: the package's identity name must be this one.
#   -Alias <name.exe>           optional: the app is started through this app execution alias, from a
#                               fresh empty folder; without it, through its tile.
#   -ReadyScript <file>         optional: run after the start with -Seconds <time left>; returns once the
#                               app is ready and throws otherwise. Without it, a window seen or the
#                               process alive for 5 s is ready.
#   -Leftovers <path[]>         what the started app writes outside its package. Each must not exist
#                               before the check, which refuses otherwise; each is removed after it.
#
# The identity, the application and its executable are read from the package's own manifest. Whatever
# the check made or the app wrote is removed again, and anything left is named.
#Requires -Version 7.0
param(
  [Parameter(Mandatory)][string] $Msix,
  [Parameter(Mandatory)][string] $Cer,
  [string] $ExpectedIdentity,
  [ValidatePattern('^[A-Za-z0-9._-]+\.exe$')]
  [string] $Alias,
  [string] $ReadyScript,
  [Parameter(Mandatory)][AllowEmptyCollection()][string[]] $Leftovers
)

$ErrorActionPreference = 'Stop'

function Invoke-AppxOperation([string] $Operation, [string] $Value) {
  # Appx needs Windows PowerShell; a separate job also bounds deployment calls that can stall.
  $job = Start-Job -PSVersion 5.1 -ArgumentList $Operation, $Value, $script:identityName -ScriptBlock {
    param($Operation, $Value, $IdentityName)
    $ErrorActionPreference = 'Stop'
    switch ($Operation) {
      'Get' { Get-AppxPackage -Name $IdentityName }
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
  @(Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($Executable)) -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $Executable })
}

function Get-SdkTool([string] $Tool) {
  # By the SDK's version, not its name: `10.0.9...` sorts after `10.0.22621.0` as a string.
  $found = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\$Tool" -ErrorAction SilentlyContinue |
    Where-Object { $_.Directory.Parent.Name -as [version] } |
    Sort-Object { [version] $_.Directory.Parent.Name } | Select-Object -Last 1
  if (-not $found) { throw "Asked for $Tool from the Windows SDK; got none on this machine" }
  $found.FullName
}

# A path the app writes, with its environment variables filled in, as a full path.
function Expand-Leftover([string] $Path) {
  $expanded = [Environment]::ExpandEnvironmentVariables($Path)
  if ($expanded -match '%') { throw "Asked for a leftover path with known variables; got '$Path'" }
  [IO.Path]::GetFullPath($expanded)
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
if ($application.Count -ne 1 -or -not $application[0].Executable) {
  throw "Asked for one application with an executable; got $($manifest.Package.Applications.OuterXml)"
}
if ($ExpectedIdentity -and $identity.Name -ne $ExpectedIdentity) {
  throw "Asked for identity $ExpectedIdentity; got $($identity.Name)"
}
$script:identityName = $identity.Name
$leftoverPaths = @($Leftovers | ForEach-Object { Expand-Leftover $_ })
$present = @($leftoverPaths | Where-Object { Test-Path -LiteralPath $_ })
if ($present.Count) {
  throw "Asked for none of the app's own files before the check; got '$($present -join "', '")'"
}
if ($ReadyScript) { $ReadyScript = (Resolve-Path -LiteralPath $ReadyScript).Path }
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
  throw "Asked for no installed $($identity.Name); got $($existing.PackageFullName -join ', ')"
}
$signtool = Get-SdkTool 'signtool.exe'
$copy = Join-Path ([IO.Path]::GetTempPath()) "porelo-untrusted-$([guid]::NewGuid()).msix"
$throwaway = $null
$trustAttempted = $false
$deploymentAttempted = $false
$executable = $null
$started = $false
$workDir = $null
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
    throw "Asked for installed $($identity.Name) version $version; got '$($installed.Version -join ', ')' ($($installed.Count) packages)"
  }
  $package = $installed[0]
  $executable = Join-Path $package.InstallLocation $application[0].Executable
  $watch = [Diagnostics.Stopwatch]::StartNew()
  if ($Alias) {
    # As a person's terminal finds it: the user's WindowsApps first, and nothing of this checkout.
    $windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    $env:PATH = "$windowsApps;$env:SystemRoot\System32;$env:SystemRoot"
    $found = @(& "$env:SystemRoot\System32\where.exe" $Alias 2>$null)
    $aliasPath = Join-Path $windowsApps $Alias
    if ($LASTEXITCODE -ne 0 -or $found.Count -eq 0 -or $found[0] -ne $aliasPath) {
      throw "Asked where to find $Alias at '$aliasPath'; got '$($found -join "', '")'"
    }
    $workDir = Join-Path ([IO.Path]::GetTempPath()) "porelo-alias-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $workDir | Out-Null
    $activation = "the alias $Alias"
    Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/d', '/c', $Alias -WorkingDirectory $workDir `
      -RedirectStandardOutput (Join-Path $workDir 'out.txt') -RedirectStandardError (Join-Path $workDir 'err.txt') -NoNewWindow
  } else {
    $activation = "shell:AppsFolder\$($package.PackageFamilyName)!$($application[0].Id)"
    Start-Process explorer.exe -ArgumentList $activation
  }
  $alive = $null
  $aliveSince = $null
  $observed = 'no process from the install folder'
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
  $running = @(Get-InstalledProcesses $executable)
  if ($Alias -and $running.Count -ne 1) {
    throw "Asked for one process from '$executable' through $activation; got $($running.Count)"
  }
  if ($ReadyScript) {
    $left = [Math]::Max(1, [int] (60 - $watch.Elapsed.TotalSeconds))
    & $ReadyScript -Seconds $left
    "Ready by '$ReadyScript'"
  }
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
  # The throwaway certificate goes with its key container; the trusted public one has no key.
  if ($throwaway) {
    $path = "Cert:\CurrentUser\My\$($throwaway.Thumbprint)"
    try {
      if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -DeleteKey -Force
        if (Test-Path -LiteralPath $path) { throw "Asked to remove '$path'; got an existing item" }
        "Removed $path with its key"
      }
    } catch { $cleanupFailures.Add("Remove '$path': $_") }
  }
  # The app's own files only once it was started: before, any of them is somebody else's. One flat list: the
  # leftovers given as an element of the list would be one array, removed and tested as one path.
  $cleanupPaths = [System.Collections.Generic.List[string]]::new()
  if ($trustAttempted -and $trustedPath) { $cleanupPaths.Add($trustedPath) }
  if ($copy) { $cleanupPaths.Add($copy) }
  if ($workDir) { $cleanupPaths.Add($workDir) }
  if ($deploymentAttempted) { foreach ($leftover in $leftoverPaths) { $cleanupPaths.Add($leftover) } }
  foreach ($path in $cleanupPaths) {
    if (-not $path) { continue }
    try {
      if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
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
