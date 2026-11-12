# The trial app is ready once it wrote its file: the install check's -ReadyScript for it.
param([Parameter(Mandatory)][int] $Seconds)

$ErrorActionPreference = 'Stop'
$file = Join-Path $env:LOCALAPPDATA 'porelo-windows-trial\started.txt'
$watch = [Diagnostics.Stopwatch]::StartNew()
while ($watch.Elapsed.TotalSeconds -lt $Seconds) {
  if (Test-Path -LiteralPath $file) { "the trial app wrote '$file'"; exit 0 }
  Start-Sleep -Milliseconds 200
}
throw "Asked the trial app to write '$file' within $Seconds s; got no file"
