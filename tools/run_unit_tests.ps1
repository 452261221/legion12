param(
    [string]$GodotPath = "D:\godot.exe"
)

$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$ProjectName = Split-Path -Leaf $ProjectRoot
$UserDir = Join-Path $env:APPDATA ("Godot\app_userdata\{0}" -f $ProjectName)
$LogsDir = Join-Path $UserDir "logs"
$ResultPath = Join-Path $UserDir "unit_test_results.json"
$FallbackResultPath = Join-Path $ProjectRoot "tmp_unit_test_results.json"

if (-not (Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
}

if (Test-Path $ResultPath) {
    Remove-Item -LiteralPath $ResultPath -Force
}
if (Test-Path $FallbackResultPath) {
    Remove-Item -LiteralPath $FallbackResultPath -Force
}

$GodotExitCode = 0
$GodotLogPath = Join-Path $ProjectRoot "godot_unit_tests.log"
& $GodotPath --headless --log-file $GodotLogPath --path $ProjectRoot -s res://tools/run_unit_tests.gd
$GodotExitCode = $LASTEXITCODE

if (-not (Test-Path $ResultPath)) {
    if (Test-Path $FallbackResultPath) {
        $ResultPath = $FallbackResultPath
    }
    else {
        Write-Output ("unit test runner did not write a result file; godot exit code {0}: {1}" -f $GodotExitCode, $ResultPath)
        exit 2
    }
}

$Result = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json
if ($Result.ok) {
    Write-Output ("unit tests passed ({0} suites)" -f $Result.suite_count)
    exit 0
}

Write-Output ("unit tests failed: {0} failures across {1} suites" -f $Result.failure_count, $Result.suite_count)
foreach ($Suite in $Result.suites) {
    if ([int]$Suite.failure_count -le 0) {
        continue
    }
    Write-Output (" - {0}: {1} failures" -f $Suite.name, $Suite.failure_count)
}
exit 1
