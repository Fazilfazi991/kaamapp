[CmdletBinding()]
param(
    [ValidateSet('appbundle', 'apk')]
    [string]$Artifact = 'appbundle'
)

$ErrorActionPreference = 'Stop'

function ConvertTo-PlainText([Security.SecureString]$SecureValue) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

$storePassword = $null
$keyPassword = $null
try {
    $storePassword = Read-Host 'KAAM upload keystore password' -AsSecureString
    $keyPassword = Read-Host 'KAAM upload key password' -AsSecureString

    $env:KAAM_STORE_PASSWORD = ConvertTo-PlainText $storePassword
    $env:KAAM_KEY_PASSWORD = ConvertTo-PlainText $keyPassword

    $projectRoot = Split-Path -Parent $PSScriptRoot
    Push-Location $projectRoot
    try {
        flutter build $Artifact --release --flavor production -t lib/main.dart
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    Remove-Item Env:KAAM_STORE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:KAAM_KEY_PASSWORD -ErrorAction SilentlyContinue
    if ($null -ne $storePassword) { $storePassword.Dispose() }
    if ($null -ne $keyPassword) { $keyPassword.Dispose() }
}
