param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9_-]{2,47}$')]
    [string]$FixtureId,

    [string]$Patrol = "C:\Users\example\AppData\Local\Pub\Cache\bin\patrol.bat",
    [string]$Adb = "D:\app\Android\sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$bundlePath = Join-Path $projectRoot "patrol_test\test_bundle.dart"
$bundleAssertion = Join-Path $projectRoot "scripts\assert_patrol_test_bundle.ps1"
$packageId = "com.tntlikely.beecount.dev.debug"
$mainActivity = "$packageId/com.tntlikely.beecount.MainActivity"
$sentinelPath = "files/codex_data_sentinel"
$productionApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-dev-debug.apk"

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

if (-not (Test-Path -LiteralPath $Patrol -PathType Leaf)) {
    throw "Patrol executable not found: $Patrol"
}
if (-not (Test-Path -LiteralPath $Adb -PathType Leaf)) {
    throw "adb executable not found: $Adb"
}

Push-Location $projectRoot
try {
    & $bundleAssertion -Expected image-eval -Path $bundlePath

    $deviceRows = & $Adb devices
    if ($LASTEXITCODE -ne 0 -or -not ($deviceRows -match "^$([regex]::Escape($DeviceId))\s+device$")) {
        throw "Requested Android device is not connected and ready: $DeviceId"
    }

    $sentinelBefore = (& $Adb -s $DeviceId shell "run-as $packageId cat $sentinelPath" 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sentinelBefore)) {
        throw "Unable to read the required pre-run data sentinel from $DeviceId"
    }
    $sentinelHash = Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($sentinelBefore))
    Write-Host "Pre-run sentinel captured (SHA256 only): $sentinelHash"

    $originalBundle = [System.IO.File]::ReadAllBytes($bundlePath)
    $originalBundleHash = Get-Sha256Hex $originalBundle
    $patrolFailure = $null

    try {
        & $Patrol test `
            --no-uninstall `
            --target patrol_test/share_billing_confirmation_lifecycle_test.dart `
            -d $DeviceId `
            --flavor dev `
            --dart-define "BEECOUNT_SHARE_C2_FIXTURE_ID=$FixtureId"
        if ($LASTEXITCODE -ne 0) {
            throw "Patrol C2 failed with exit code $LASTEXITCODE"
        }
        & $bundleAssertion -Expected share-c2 -Path $bundlePath
        Write-Host "Patrol C2 completed for fixture: $FixtureId"
    }
    catch {
        $patrolFailure = $_
    }
    finally {
        [System.IO.File]::WriteAllBytes($bundlePath, $originalBundle)
        & $bundleAssertion -Expected image-eval -Path $bundlePath
        $restoredBundleHash = Get-Sha256Hex ([System.IO.File]::ReadAllBytes($bundlePath))
        if ($restoredBundleHash -ne $originalBundleHash) {
            throw "Patrol production bundle was not restored byte-for-byte"
        }

        flutter build apk --debug --flavor dev -t lib/main.dart
        if ($LASTEXITCODE -ne 0) {
            throw "Production Android APK restore build failed with exit code $LASTEXITCODE"
        }
        & $Adb -s $DeviceId install -r $productionApk
        if ($LASTEXITCODE -ne 0) {
            throw "Production Android APK restore install failed with exit code $LASTEXITCODE"
        }
        & $Adb -s $DeviceId shell am start -n $mainActivity
        if ($LASTEXITCODE -ne 0) {
            throw "Production Android entrypoint failed to start with exit code $LASTEXITCODE"
        }

        $sentinelAfter = (& $Adb -s $DeviceId shell "run-as $packageId cat $sentinelPath" 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $sentinelAfter -cne $sentinelBefore) {
            throw "Android data sentinel changed during C2; stop and investigate"
        }
        Write-Host "Production entrypoint restored; Android data sentinel is unchanged."
    }

    if ($null -ne $patrolFailure) {
        throw $patrolFailure
    }
}
finally {
    Pop-Location
}
