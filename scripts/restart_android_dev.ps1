param(
    [string]$DeviceId = "emulator-5554",
    [int]$WaitSeconds = 180
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Flutter = "D:\dev\flutter\flutter\bin\flutter.bat"
$Adb = "D:\app\Android\sdk\platform-tools\adb.exe"
$OutLog = Join-Path $Root "flutter-run.out.log"
$ErrLog = Join-Path $Root "flutter-run.err.log"

Write-Host "Checking Android device $DeviceId..."
$devices = & $Adb devices
if (-not ($devices -match "^$([regex]::Escape($DeviceId))\s+device$")) {
    $devices | ForEach-Object { Write-Host $_ }
    throw "Android device '$DeviceId' is not connected."
}

Write-Host "Stopping old flutter run sessions..."
Get-CimInstance Win32_Process |
    Where-Object {
        $_.CommandLine -match "flutter_tools\.snapshot.*run --flavor dev" -or
        $_.CommandLine -match "flutter\.bat.*run.*--flavor.*dev"
    } |
    ForEach-Object {
        try {
            Stop-Process -Id $_.ProcessId -Force
            Write-Host "Stopped PID $($_.ProcessId)"
        } catch {
            Write-Host "Could not stop PID $($_.ProcessId): $($_.Exception.Message)"
        }
    }

Clear-Content $OutLog -ErrorAction SilentlyContinue
Clear-Content $ErrLog -ErrorAction SilentlyContinue

Write-Host "Starting flutter run..."
Start-Process `
    -FilePath $Flutter `
    -ArgumentList @("run", "--flavor", "dev", "-d", $DeviceId) `
    -WorkingDirectory $Root `
    -RedirectStandardOutput $OutLog `
    -RedirectStandardError $ErrLog `
    -WindowStyle Hidden

$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    $out = if (Test-Path $OutLog) { Get-Content $OutLog -Raw -ErrorAction SilentlyContinue } else { "" }
    $err = if (Test-Path $ErrLog) { Get-Content $ErrLog -Raw -ErrorAction SilentlyContinue } else { "" }

    if ($out -match "A Dart VM Service") {
        Write-Host "Flutter dev app restarted successfully."
        Get-Content $OutLog -Tail 40
        exit 0
    }

    if ($out -match "BUILD FAILED|Gradle task .* failed|Error:" -or $err -match "BUILD FAILED|Exception|Error:") {
        Write-Host "Flutter restart failed. Recent output:"
        Get-Content $OutLog -Tail 120 -ErrorAction SilentlyContinue
        Get-Content $ErrLog -Tail 120 -ErrorAction SilentlyContinue
        exit 1
    }
}

Write-Host "Flutter run is still starting. Recent output:"
Get-Content $OutLog -Tail 80 -ErrorAction SilentlyContinue
Get-Content $ErrLog -Tail 80 -ErrorAction SilentlyContinue
exit 2
