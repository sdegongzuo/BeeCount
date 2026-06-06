param(
  [string]$Device = "emulator-5554",
  [string]$Package = "com.tntlikely.beecount.dev.debug",
  [string]$Adb = "D:\app\Android\sdk\platform-tools\adb.exe",
  [string]$SourceDir = ""
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
function Join-CodePointString {
  param([int[]]$Codes)
  return -join ($Codes | ForEach-Object { [char]$_ })
}

if ([string]::IsNullOrWhiteSpace($SourceDir)) {
  # Keep this script ASCII-safe for Windows PowerShell 5, which may decode
  # UTF-8-without-BOM scripts as the system ANSI code page.
  $singleCaseDirName = Join-CodePointString -Codes @(0x5355, 0x6761)
  $SourceDir = Join-Path "image" $singleCaseDirName
}

$source = Resolve-Path -LiteralPath (Join-Path $root $SourceDir)
$target = "app_flutter/image_billing_eval/input"

$single = Join-CodePointString -Codes @(0x5355, 0x6761)
$alipay = Join-CodePointString -Codes @(0x652F, 0x4ED8, 0x5B9D)
$wechat = Join-CodePointString -Codes @(0x5FAE, 0x4FE1)
$meituan = Join-CodePointString -Codes @(0x7F8E, 0x56E2)
$jd = Join-CodePointString -Codes @(0x4EAC, 0x4E1C)
$pinduoduo = Join-CodePointString -Codes @(0x62FC, 0x591A, 0x591A)
$unionpay = Join-CodePointString -Codes @(0x4E91, 0x95EA, 0x4ED8)
$suffix = "-" + $single + ".jpg"

$samples = @(
  @{ Local = $alipay + $suffix; Remote = "alipay_etc_single.jpg" },
  @{ Local = $alipay + "-" + $single + "2.jpg"; Remote = "alipay_mimo_token_single.jpg" },
  @{ Local = $alipay + "-" + $single + "3.jpg"; Remote = "alipay_taobao_flash_single.jpg" },
  @{ Local = $alipay + "-" + $single + "4.jpg"; Remote = "alipay_tmall_single.jpg" },
  @{ Local = $wechat + $suffix; Remote = "wechat_pinduoduo_single.jpg" },
  @{ Local = $wechat + "-" + $single + "2.jpg"; Remote = "wechat_yangguofu_single.jpg" },
  @{ Local = $meituan + $suffix; Remote = "meituan_xiaoxiang_single.jpg" },
  @{ Local = $meituan + "-" + $single + "2.jpg"; Remote = "meituan_xiaoxiang_digital_single.jpg" },
  @{ Local = $meituan + "-" + $single + "3.jpg"; Remote = "meituan_xiaoxiang_monthpay_single.jpg" },
  @{ Local = $jd + $suffix; Remote = "jd_platform_single.jpg" },
  @{ Local = $jd + "-" + $single + "2.jpg"; Remote = "jd_multi_order_single.jpg" },
  @{ Local = $pinduoduo + $suffix; Remote = "pinduoduo_membership_single.jpg" },
  @{ Local = $pinduoduo + "-" + $single + "2.jpg"; Remote = "pinduoduo_hardware_single.jpg" },
  @{ Local = $pinduoduo + "-" + $single + "3.jpg"; Remote = "pinduoduo_tool_single.jpg" },
  @{ Local = $unionpay + $suffix; Remote = "unionpay_xicha_single.jpg" },
  @{ Local = $unionpay + "-" + $single + "2.jpg"; Remote = "unionpay_pinduoduo_single.jpg" },
  @{ Local = $unionpay + "-" + $single + "3.jpg"; Remote = "unionpay_kfc_single.jpg" },
  @{ Local = $unionpay + "-" + $single + "4.jpg"; Remote = "unionpay_ele_single.jpg" }
)

& $Adb -s $Device shell run-as $Package mkdir -p $target
foreach ($sample in $samples) {
  $localPath = Join-Path $source $sample.Local
  if (-not (Test-Path -LiteralPath $localPath)) {
    Write-Warning "sample not found: $localPath"
    continue
  }

  $tempPath = "/data/local/tmp/beecount_eval_$($sample.Remote)"
  Write-Host "push $($sample.Local) -> $($sample.Remote)"
  & $Adb -s $Device push $localPath $tempPath
  & $Adb -s $Device shell run-as $Package cp $tempPath "$target/$($sample.Remote)"
}

Write-Host "Pushed samples to $Package/$target"
