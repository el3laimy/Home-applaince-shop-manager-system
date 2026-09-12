[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string[]]$Files,
  [string]$TimestampUrl = 'http://timestamp.digicert.com'
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
$certificate = $null
try {
  $certificateBytes = [Convert]::FromBase64String(
    ($certificateBase64 -replace '\s', '')
  )
  [IO.File]::WriteAllBytes($certificatePath, $certificateBytes)
  $securePassword = ConvertTo-SecureString `
    $certificatePassword `
    -AsPlainText `
    -Force
  $certificate = Import-PfxCertificate `
    -FilePath $certificatePath `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -Password $securePassword
  if ($null -eq $certificate -or -not $certificate.HasPrivateKey) {
    throw 'The Windows signing certificate could not be imported with its private key.'
  }
  Write-Host "Imported signing certificate: $($certificate.Subject)"

  foreach ($file in $resolvedFiles) {
    $signArguments = @(
      'sign',
      '/sha1', $certificate.Thumbprint,
      '/s', 'My',
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
    Write-Host "Verifying signature: $file"
    & $signTool.FullName verify /pa /v $file
    if ($LASTEXITCODE -ne 0) {
      throw "Signature verification failed for $file ($LASTEXITCODE)."
    }
  }
} finally {
  if ($null -ne $certificate) {
    Remove-Item `
      "Cert:\CurrentUser\My\$($certificate.Thumbprint)" `
      -Force `
      -ErrorAction SilentlyContinue
  }
  Remove-Item $certificatePath -Force -ErrorAction SilentlyContinue
}
