# The Windows machine's part of tool/play_story.sh, copied there beside the play's folder. Each mode is
# one stage, run over ssh by the driver, except `test`, which the `play` mode starts in the person's desktop session:
# on Windows there is no virtual display, and a window started from an ssh session has no desktop to show on.
#
#   prepare  checks the packages against SHA256SUMS and fetches Flutter VERSION where it is missing
#   window   installs the window's MSIX, starts it and removes it again, as tool/windows-install-check.ps1 does
#   planner  unpacks porelo-planner's Windows ZIP into the play's folder, where the window's path finds it
#   play     runs `test` in the desktop session as a scheduled task of the play's own, at most MINUTES
#   test     runs the story's test with flutter test -d windows, its output and exit code into the play's folder
#   clean    takes away what the play made: the task, its processes, the window's package, the play's folder
#Requires -Version 7.0
param(
  [Parameter(Mandatory)][ValidateSet('prepare', 'window', 'planner', 'play', 'test', 'clean')][string] $Mode,
  [Parameter(Mandatory)][string] $Run,
  [string] $Story = '',
  [string] $Flutter = '',
  [int] $Minutes = 60
)

$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $Run) { $Run = (Resolve-Path -LiteralPath $Run).Path } elseif ($Mode -eq 'clean') { 'Nothing of the play is left'; exit 0 }
$packages = Join-Path $Run 'packages'
$flutterHome = Join-Path $env:LOCALAPPDATA "porelo-frontend\flutter-$Flutter"
$task = 'porelo-play-' + (Split-Path -Leaf $Run)

# The one file of the packages matching [pattern], or nothing where there is none; two are refused.
function Get-Package([string] $Pattern) {
  $found = @(Get-ChildItem -LiteralPath $packages -Filter $Pattern -File -ErrorAction SilentlyContinue)
  if ($found.Count -gt 1) { throw "Asked for one package $Pattern; got $($found.Name -join ', ')" }
  $found | Select-Object -First 1
}

switch ($Mode) {
  'prepare' {
    # Checked again where it is used: what arrived is what was checked on the driver's side.
    foreach ($line in Get-Content -LiteralPath (Join-Path $packages 'SHA256SUMS')) {
      if ($line -notmatch '^([0-9a-f]{64}) [ *]([A-Za-z0-9._+-]+)$') { throw "Asked for '<sha256>  <file>' in SHA256SUMS; got '$line'" }
      $file = Join-Path $packages $Matches[2]
      if (-not (Test-Path -LiteralPath $file)) { continue }
      $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $file).Hash.ToLowerInvariant()
      if ($actual -ne $Matches[1]) { throw "Asked for $($Matches[2]) with sha256 $($Matches[1]); got $actual" }
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $Run 'src') | Out-Null
    tar.exe -xf (Join-Path $Run 'src.zip') -C (Join-Path $Run 'src')
    if ($LASTEXITCODE) { throw "Asked tar to unpack the checkout; got exit $LASTEXITCODE" }
    if (-not (Test-Path -LiteralPath (Join-Path $flutterHome 'bin\flutter.bat'))) {
      $base = 'https://storage.googleapis.com/flutter_infra_release/releases'
      $release = (Invoke-RestMethod "$base/releases_windows.json").releases |
        Where-Object { $_.version -eq $Flutter -and $_.channel -eq 'stable' } | Select-Object -First 1
      if (-not $release) { throw "Asked for Flutter $Flutter among the stable releases; it is not listed" }
      $zip = Join-Path $env:TEMP "flutter-$Flutter.zip"
      Invoke-WebRequest -Uri "$base/$($release.archive)" -OutFile $zip
      $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
      if ($actual -ne $release.sha256) { Remove-Item -LiteralPath $zip; throw "Asked for Flutter with sha256 $($release.sha256); got $actual" }
      $part = "$flutterHome.part"
      if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Recurse -Force }
      New-Item -ItemType Directory -Force -Path $part | Out-Null
      tar.exe -xf $zip -C $part
      if ($LASTEXITCODE) { throw "Asked tar to unpack Flutter; got exit $LASTEXITCODE" }
      Remove-Item -LiteralPath $zip
      Move-Item -LiteralPath (Join-Path $part 'flutter') -Destination $flutterHome
      Remove-Item -LiteralPath $part -Recurse -Force
    }
    "Flutter $Flutter at $flutterHome"
  }
  'window' {
    $msix = Get-Package 'porelo-frontend*.msix'
    $cer = Get-Package '*.cer'
    if (-not $msix -or -not $cer) { throw "Asked the packages for the window's MSIX and its certificate; got '$((Get-ChildItem $packages).Name -join ', ')'" }
    & (Join-Path $Run 'src\tool\windows-install-check.ps1') -Msix $msix.FullName -Cer $cer.FullName
  }
  'planner' {
    $zip = Get-Package 'porelo-planner*windows*.zip'
    if (-not $zip) { throw "Asked the packages for porelo-planner's Windows ZIP; got '$((Get-ChildItem $packages).Name -join ', ')'" }
    $into = Join-Path $Run 'planner'
    New-Item -ItemType Directory -Force -Path $into | Out-Null
    tar.exe -xf $zip.FullName -C $into
    if ($LASTEXITCODE) { throw "Asked tar to unpack $($zip.Name); got exit $LASTEXITCODE" }
    $exe = @(Get-ChildItem -LiteralPath $into -Recurse -Filter 'porelo-planner.exe' -File)
    if ($exe.Count -ne 1) { throw "Asked $($zip.Name) for one porelo-planner.exe; got $($exe.Count)" }
    # Where the test and the window find it: its folder first on the window's path.
    Set-Content -LiteralPath (Join-Path $Run 'planner.txt') -Value $exe[0].FullName
    "porelo-planner at $($exe[0].FullName)"
  }
  'play' {
    $self = $PSCommandPath
    $arguments = "-NoProfile -NonInteractive -File `"$self`" -Mode test -Run `"$Run`" -Story $Story -Flutter $Flutter"
    $action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument $arguments -WorkingDirectory $Run
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
    Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $task
    $exit = Join-Path $Run 'exit'
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $exit)) {
      if ($watch.Elapsed.TotalMinutes -ge $Minutes) {
        Stop-ScheduledTask -TaskName $task
        Set-Content -LiteralPath $exit -Value 124
        break
      }
      Start-Sleep -Seconds 5
    }
    "The test ended with $(Get-Content -LiteralPath $exit) after $([int]$watch.Elapsed.TotalMinutes) minutes"
  }
  'test' {
    $status = 1
    try {
      Set-Location (Join-Path $Run 'src')
      $planner = if (Test-Path (Join-Path $Run 'planner.txt')) { (Get-Content (Join-Path $Run 'planner.txt')).Trim() } else { '' }
      $env:PATH = "$(if ($planner) { (Split-Path $planner) + ';' })$flutterHome\bin;$env:PATH"
      $env:PORELO_STORY_PLANNER = $planner
      $env:PORELO_STORY_STEPS = Join-Path $Run 'noted.txt'
      $env:PORELO_REHEARSAL_SHOTS = Join-Path $Run 'pictures'
      flutter pub get *> (Join-Path $Run 'pub-get.log')
      dart pub get --directory=packages/porelo_host *>> (Join-Path $Run 'pub-get.log')
      flutter test -d windows --machine "integration_test\${Story}_test.dart" 1> (Join-Path $Run 'results.json') 2> (Join-Path $Run 'run.log')
      $status = $LASTEXITCODE
    } catch {
      $_ | Out-File -Append (Join-Path $Run 'run.log')
    } finally {
      Set-Content -LiteralPath (Join-Path $Run 'exit') -Value $status
    }
  }
  'clean' {
    # Each part is tried even when another fails, so the failure names every leftover.
    $left = [Collections.Generic.List[string]]::new()
    try {
      if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $task -Confirm:$false }
    } catch { $left.Add("the scheduled task ${task}: $_") }
    foreach ($process in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($Run) })) {
      try { Stop-Process -Id $process.Id -Force } catch { $left.Add("process $($process.Id) from $($process.Path): $_") }
    }
    $installed = @(powershell.exe -NoProfile -Command 'Get-AppxPackage -Name ai.porelo.frontend | ForEach-Object PackageFullName')
    foreach ($package in $installed | Where-Object { $_ }) {
      powershell.exe -NoProfile -Command "Remove-AppxPackage -Package '$package'"
      if ($LASTEXITCODE) { $left.Add("the window's package $package") }
    }
    Start-Sleep -Seconds 2
    try { Remove-Item -LiteralPath $Run -Recurse -Force } catch { $left.Add("the play's folder ${Run}: $_") }
    if ($left.Count) { throw "Asked for nothing left of the play; left: $($left -join '; ')" }
    "Nothing of the play is left"
  }
}
