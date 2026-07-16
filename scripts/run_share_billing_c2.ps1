param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,63}$')]
    [string]$FixtureId,

    [switch]$UserConfirmedUnlocked,

    [string]$Patrol = "C:\Users\example\AppData\Local\Pub\Cache\bin\patrol.bat",
    [string]$Adb = "D:\app\Android\sdk\platform-tools\adb.exe",

    [ValidateSet("confirmation", "classification")]
    [string]$Scenario = "confirmation"
)

$ErrorActionPreference = "Stop"
if (-not $UserConfirmedUnlocked) {
    throw "UserConfirmedUnlocked is required before any Android C2 operation"
}

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$bundlePath = Join-Path $projectRoot "patrol_test\test_bundle.dart"
$bundleAssertion = Join-Path $projectRoot "scripts\assert_patrol_test_bundle.ps1"
$packageId = "com.tntlikely.beecount.dev.debug"
$mainActivity = "$packageId/com.tntlikely.beecount.MainActivity"
$sentinelPath = "files/codex_data_sentinel"
$productionApk = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-dev-debug.apk"
$recoveryRoot = Join-Path $projectRoot ".codex_tmp\c2-recovery"
$patrolTarget = if ($Scenario -eq "classification") {
    "patrol_test/pending_classification_personal_rule_c2_test.dart"
}
else {
    "patrol_test/share_billing_confirmation_lifecycle_test.dart"
}
$patrolBundleMarker = if ($Scenario -eq "classification") {
    "classification-c2"
}
else {
    "share-c2"
}

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Invoke-RecoveryStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Errors
    )

    try {
        & $Action
        Write-Host "Recovery step completed: $Name"
    }
    catch {
        $message = "${Name}: $($_.Exception.Message)"
        [void]$Errors.Add($message)
        Write-Warning $message
    }
}

if (-not (Test-Path -LiteralPath $Patrol -PathType Leaf)) {
    throw "Patrol executable not found: $Patrol"
}
if (-not (Test-Path -LiteralPath $Adb -PathType Leaf)) {
    throw "adb executable not found: $Adb"
}
$Patrol = (Resolve-Path -LiteralPath $Patrol).Path
$Adb = (Resolve-Path -LiteralPath $Adb).Path

Push-Location $projectRoot
try {
    & $bundleAssertion -Expected image-eval -Path $bundlePath

    $deviceState = (& $Adb -s $DeviceId get-state 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $deviceState -ne "device") {
        throw "Requested Android device is not connected and ready: $DeviceId"
    }
    $bootCompleted = (& $Adb -s $DeviceId shell getprop sys.boot_completed 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $bootCompleted -ne "1") {
        throw "Requested Android device has not completed boot: $DeviceId"
    }

    $sentinelBefore = (& $Adb -s $DeviceId shell "run-as $packageId cat $sentinelPath" 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sentinelBefore)) {
        throw "Unable to read the required pre-run data sentinel from $DeviceId"
    }
    $sentinelHash = Get-Sha256Hex ([System.Text.Encoding]::UTF8.GetBytes($sentinelBefore))
    Write-Host "Pre-run sentinel captured (SHA256 only): $sentinelHash"

    flutter build apk --debug --flavor dev -t lib/main.dart
    if ($LASTEXITCODE -ne 0) {
        throw "Production Android recovery APK build failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $productionApk -PathType Leaf)) {
        throw "Production Android recovery APK was not produced: $productionApk"
    }
    $productionApkInfo = Get-Item -LiteralPath $productionApk
    if ($productionApkInfo.Length -le 0) {
        throw "Production Android recovery APK is empty: $productionApk"
    }
    $runKey = "$FixtureId-$([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))-$([guid]::NewGuid().ToString('N'))"
    $recoveryDirectory = Join-Path $recoveryRoot $runKey
    $recoveryApk = Join-Path $recoveryDirectory "app-dev-debug-main.apk"
    New-Item -ItemType Directory -Path $recoveryDirectory -Force | Out-Null
    Copy-Item -LiteralPath $productionApk -Destination $recoveryApk
    if (-not (Test-Path -LiteralPath $recoveryApk -PathType Leaf)) {
        throw "Production Android recovery APK copy was not produced: $recoveryApk"
    }
    $productionApkHash = Get-Sha256Hex ([System.IO.File]::ReadAllBytes($productionApk))
    $recoveryApkHash = Get-Sha256Hex ([System.IO.File]::ReadAllBytes($recoveryApk))
    if ($recoveryApkHash -ne $productionApkHash) {
        throw "Recovery APK hash does not match the prebuilt production APK"
    }
    Write-Host "Prebuilt production recovery APK retained at: $recoveryApk"
    Write-Host "Prebuilt production recovery APK SHA256: $recoveryApkHash"

    $originalBundle = [System.IO.File]::ReadAllBytes($bundlePath)
    $originalBundleHash = Get-Sha256Hex $originalBundle
    $patrolFailure = $null
    $recoveryErrors = [System.Collections.Generic.List[string]]::new()
    $originalPath = $env:PATH
    $adbDirectory = [System.IO.Path]::GetDirectoryName($Adb)

    try {
        $env:PATH = "$adbDirectory;$originalPath"
        & $Patrol test `
            --no-uninstall `
            --target $patrolTarget `
            -d $DeviceId `
            --flavor dev `
            --dart-define "BEECOUNT_SHARE_C2_FIXTURE_ID=$FixtureId"
        if ($LASTEXITCODE -ne 0) {
            throw "Patrol C2 failed with exit code $LASTEXITCODE"
        }
        & $bundleAssertion -Expected $patrolBundleMarker -Path $bundlePath
        Write-Host "Patrol $Scenario C2 completed for fixture: $FixtureId"
    }
    catch {
        $patrolFailure = $_.Exception.Message
    }
    finally {
        $env:PATH = $originalPath
        Invoke-RecoveryStep -Name "bundle-bytes-and-markers" -Errors $recoveryErrors -Action {
            [System.IO.File]::WriteAllBytes($bundlePath, $originalBundle)
            & $bundleAssertion -Expected image-eval -Path $bundlePath
            $restoredBundleHash = Get-Sha256Hex ([System.IO.File]::ReadAllBytes($bundlePath))
            if ($restoredBundleHash -ne $originalBundleHash) {
                throw "Patrol production bundle was not restored byte-for-byte"
            }
        }
        Invoke-RecoveryStep -Name "install-prebuilt-main-apk" -Errors $recoveryErrors -Action {
            & $Adb -s $DeviceId install -r $recoveryApk
            if ($LASTEXITCODE -ne 0) {
                throw "Prebuilt production APK restore install failed with exit code $LASTEXITCODE"
            }
        }
        Invoke-RecoveryStep -Name "start-production-main-activity" -Errors $recoveryErrors -Action {
            & $Adb -s $DeviceId shell am start -n $mainActivity
            if ($LASTEXITCODE -ne 0) {
                throw "Production Android entrypoint failed to start with exit code $LASTEXITCODE"
            }
        }
        Invoke-RecoveryStep -Name "verify-post-run-sentinel" -Errors $recoveryErrors -Action {
            $sentinelAfter = (& $Adb -s $DeviceId shell "run-as $packageId cat $sentinelPath" 2>&1 | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or $sentinelAfter -cne $sentinelBefore) {
                throw "Android data sentinel changed during C2; stop and investigate"
            }
        }
    }

    $failures = [System.Collections.Generic.List[string]]::new()
    if ($null -ne $patrolFailure) {
        [void]$failures.Add("patrol: $patrolFailure")
    }
    foreach ($recoveryError in $recoveryErrors) {
        [void]$failures.Add($recoveryError)
    }
    if ($failures.Count -gt 0) {
        throw "Android C2 runner failed:`n - $($failures -join "`n - ")"
    }
    Write-Host "Production entrypoint restored; Android data sentinel is unchanged."
}
finally {
    Pop-Location
}
