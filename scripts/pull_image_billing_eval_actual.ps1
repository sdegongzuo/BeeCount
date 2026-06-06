param(
  [string]$Device = "emulator-5554",
  [string]$Package = "com.tntlikely.beecount.dev.debug",
  [string]$Adb = "D:\app\Android\sdk\platform-tools\adb.exe",
  [string]$OutputDir = "build\image_billing_eval"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$output = Join-Path $root $OutputDir
New-Item -ItemType Directory -Force $output | Out-Null

$source = "app_flutter/image_billing_eval/output/latest_actual.json"
$target = Join-Path $output "latest_actual.json"

$process = New-Object System.Diagnostics.Process
$process.StartInfo.FileName = $Adb
$process.StartInfo.Arguments = "-s $Device exec-out run-as $Package cat $source"
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.RedirectStandardOutput = $true
$process.StartInfo.RedirectStandardError = $true

$fileStream = [System.IO.File]::Open(
  $target,
  [System.IO.FileMode]::Create,
  [System.IO.FileAccess]::Write,
  [System.IO.FileShare]::None
)

try {
  [void]$process.Start()
  $process.StandardOutput.BaseStream.CopyTo($fileStream)
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  $exitCode = $process.ExitCode
}
finally {
  $fileStream.Dispose()
  $process.Dispose()
}

if ($exitCode -ne 0) {
  throw "Failed to read $Package/$source. $stderr"
}

Write-Host "Pulled actual result to $target"
