param(
    [Parameter(Mandatory = $true)][string]$RequestPath,
    [Parameter(Mandatory = $true)][string]$ResponsePath,
    [Parameter(Mandatory = $true)][string]$ApiKey,
    [string]$BaseUrl = "https://api.deepseek.com/chat/completions",
    [string[]]$ExtraHeader = @(),
    [int]$ConnectTimeoutSeconds = 10,
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"

$requestBody = Get-Content -Path $RequestPath -Raw -Encoding UTF8
$tempBodyPath = [System.IO.Path]::GetTempFileName()
$tempCodePath = [System.IO.Path]::GetTempFileName()

try {
    $curlArgs = @(
        "--silent",
        "--show-error",
        "--location",
        "--connect-timeout", "$ConnectTimeoutSeconds",
        "--max-time", "$TimeoutSeconds",
        "--output", $tempBodyPath,
        "--write-out", "%{http_code}",
        $BaseUrl,
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer $ApiKey",
        "--data-binary", "@$RequestPath"
    )
    foreach ($headerLine in $ExtraHeader) {
        if (-not [string]::IsNullOrWhiteSpace($headerLine)) {
            $curlArgs += @("-H", $headerLine)
        }
    }
    $statusCode = & curl.exe @curlArgs
    $responseBody = ""
    if (Test-Path $tempBodyPath) {
        $responseBody = Get-Content -Path $tempBodyPath -Raw -Encoding UTF8
    }
    $result = @{
        ok = $true
        status_code = [int]$statusCode
        body = $responseBody
    }
    if ([int]$statusCode -lt 200 -or [int]$statusCode -ge 300) {
        $result.ok = $false
        $result.error = "http_error"
    }
    $result | ConvertTo-Json -Depth 20 | Set-Content -Path $ResponsePath -Encoding UTF8
}
catch {
    @{
        ok = $false
        error = "helper_exception"
        message = $_.Exception.Message
    } | ConvertTo-Json -Depth 20 | Set-Content -Path $ResponsePath -Encoding UTF8
    exit 1
}
finally {
    if (Test-Path $tempBodyPath) {
        Remove-Item -Path $tempBodyPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $tempCodePath) {
        Remove-Item -Path $tempCodePath -Force -ErrorAction SilentlyContinue
    }
}
