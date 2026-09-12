[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string[]]$Files,
  [string]$TimestampUrl = 'http://timestamp.digicert.com',
  [switch]$AllowUntrustedCertificate
)

$ErrorActionPreference = 'Stop'

$certificateBase64 = $env:WINDOWS_SIGNING_CERTIFICATE_BASE64
$certificatePassword = $env:WINDOWS_SIGNING_CERTIFICATE_PASSWORD
if ([string]::IsNullOrWhiteSpace($certificateBase64)) {
  throw 'WINDOWS_SIGNING_CERTIFICATE_BASE64 is required.'
}
if ([string]::IsNullOrWhiteSpace($certificatePassword)) {
  throw 'WINDOWS_SIGNING_CERTIFICATE_PASSWORD is required.'
}

$resolvedFiles = @(
  foreach ($file in $Files) {
    $resolved = (Resolve-Path -LiteralPath $file).Path
    if ([IO.Path]::GetExtension($resolved) -ne '.exe') {
      throw "Windows release signing accepts executable files only: $resolved"
    }
    $resolved
  }
)

$sdkBin = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
$signTool = Get-ChildItem -LiteralPath $sdkBin -Directory |
  Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
  Sort-Object { [version]$_.Name } -Descending |
  ForEach-Object { Get-Item (Join-Path $_.FullName 'x64\signtool.exe') -ErrorAction SilentlyContinue } |
  Select-Object -First 1
if ($null -eq $signTool) { throw 'Windows SDK signtool.exe was not found.' }
Write-Host "Using signtool: $($signTool.FullName)"

$certificatePath = Join-Path $env:RUNNER_TEMP 'alikhlas-release-signing.pfx'
try {
  $certificateBytes = [Convert]::FromBase64String(
    ($certificateBase64 -replace '\s', '')
  )
  [IO.File]::WriteAllBytes($certificatePath, $certificateBytes)
  $certificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new(
    $certificatePath,
    $certificatePassword,
    [Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
  )
  if ($null -eq $certificate -or -not $certificate.HasPrivateKey) {
    throw 'The Windows signing certificate could not be opened with its private key.'
  }
  Write-Host "Opened signing certificate: $($certificate.Subject)"

  foreach ($file in $resolvedFiles) {
    $signArguments = @(
      'sign',
      '/f', $certificatePath,
      '/p', $certificatePassword,
      '/fd', 'SHA256'
    )
    if (-not [string]::IsNullOrWhiteSpace($TimestampUrl)) {
      $signArguments += @('/tr', $TimestampUrl, '/td', 'SHA256')
    }
    $signArguments += $file
    Write-Host "Signing: $file"
    & $signTool.FullName $signArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to sign $file ($LASTEXITCODE)."
    }
    Write-Host "Verifying Authenticode signature: $file"
    $signature = Get-AuthenticodeSignature -FilePath $file
    if (
      -not $AllowUntrustedCertificate -and
      $signature.Status -ne 'Valid'
    ) {
      throw "Authenticode signature verification failed for $file ($($signature.Status))."
    }
    if (
      $AllowUntrustedCertificate -and
      ($signature.Status -eq 'NotSigned' -or $signature.Status -eq 'HashMismatch')
    ) {
      throw "The test Authenticode signature is missing or invalid for $file ($($signature.Status))."
    }
    if ($signature.SignerCertificate.Thumbprint -ne $certificate.Thumbprint) {
      throw "The Authenticode signer does not match the imported certificate: $file"
    }
    if (
      -not [string]::IsNullOrWhiteSpace($TimestampUrl) -and
      $null -eq $signature.TimeStamperCertificate
    ) {
      throw "The Authenticode signature does not contain a timestamp: $file"
    }
  }
} finally {
  Remove-Item $certificatePath -Force -ErrorAction SilentlyContinue
}
