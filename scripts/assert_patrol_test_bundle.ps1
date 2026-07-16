param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("image-eval", "share-c2", "classification-c2")]
    [string]$Expected,

    [string]$Path = "patrol_test/test_bundle.dart"
)

$ErrorActionPreference = "Stop"
$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$content = [System.IO.File]::ReadAllText($resolvedPath)

$targets = @{
    "image-eval" = @(
        "import 'image_billing_eval_test.dart' as __image_billing_eval_test;",
        "group('.image_billing_eval_test', __image_billing_eval_test.main);"
    )
    "share-c2" = @(
        "import 'share_billing_confirmation_lifecycle_test.dart' as __share_billing_confirmation_lifecycle_test;",
        "group('.share_billing_confirmation_lifecycle_test', __share_billing_confirmation_lifecycle_test.main);"
    )
    "classification-c2" = @(
        "import 'pending_classification_personal_rule_c2_test.dart' as __pending_classification_personal_rule_c2_test;",
        "group('.pending_classification_personal_rule_c2_test', __pending_classification_personal_rule_c2_test.main);"
    )
}

foreach ($marker in $targets[$Expected]) {
    if (-not $content.Contains($marker)) {
        throw "Patrol test bundle does not contain expected $Expected marker: $marker"
    }
}

foreach ($unexpected in $targets.Keys | Where-Object { $_ -ne $Expected }) {
    foreach ($marker in $targets[$unexpected]) {
        if ($content.Contains($marker)) {
            throw "Patrol test bundle still contains unexpected $unexpected marker: $marker"
        }
    }
}

Write-Host "Patrol test bundle target verified: $Expected"
