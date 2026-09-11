[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDirectory,
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d+\.\d+\.\d+$')]
  [string]$Version
)

$ErrorActionPreference = 'Stop'

$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
if (-not (Test-Path -LiteralPath (Join-Path $source 'alikhlas_pos.exe'))) {
  throw "Flutter Windows release executable is missing from: $source"
}

$output = [System.IO.Path]::GetFullPath($OutputDirectory)
if ($source.TrimEnd('\') -eq $output.TrimEnd('\')) {
  throw 'The installer output directory must not be the Flutter Release directory.'
}
New-Item -ItemType Directory -Path $output -Force | Out-Null

$compiler = @(
  (Join-Path ${env:ProgramFiles(x86)} 'NSIS\makensis.exe'),
  (Join-Path $env:ProgramFiles 'NSIS\makensis.exe')
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($null -eq $compiler) { throw 'NSIS compiler was not installed.' }

& $compiler /VERSION
if ($LASTEXITCODE -ne 0) { throw "Unable to run NSIS compiler ($LASTEXITCODE)." }

$arguments = @(
  "/DSOURCE_DIR=$source",
  "/DOUTPUT_DIR=$output",
  "/DAPP_VERSION=$Version",
  'tool\alikhlas_pos.nsi'
)
& $compiler $arguments
if ($LASTEXITCODE -ne 0) { throw "NSIS failed with exit code $LASTEXITCODE." }

$installer = Join-Path $output "ALIkhlasPOS-Setup-$Version-x64.exe"
if (-not (Test-Path -LiteralPath $installer)) {
  throw "NSIS completed without producing: $installer"
}
Write-Host "Windows installer: $installer"
