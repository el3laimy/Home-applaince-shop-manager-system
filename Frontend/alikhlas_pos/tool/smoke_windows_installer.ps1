[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$OlderInstaller,
  [Parameter(Mandatory = $true)]
  [string]$CurrentInstaller,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d+\.\d+\.\d+$')]
  [string]$ExpectedVersion
)

$ErrorActionPreference = 'Stop'
$older = (Resolve-Path -LiteralPath $OlderInstaller).Path
$current = (Resolve-Path -LiteralPath $CurrentInstaller).Path
$installDirectory = Join-Path $env:LOCALAPPDATA 'Programs\ALIkhlas POS'
$executable = Join-Path $installDirectory 'alikhlas_pos.exe'
$uninstaller = Join-Path $installDirectory 'Uninstall.exe'
$registryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ALIkhlasPOS-v2-5B7C2A10-59F8-4BB7-ACDA-7E3207B2A2A4'
$desktopShortcut = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Desktop)) 'إخلاص POS.lnk'
$startMenuShortcut = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) 'إخلاص POS\إخلاص POS.lnk'
$databasePath = Join-Path $env:APPDATA 'ALIkhlasPOS\ALIkhlasPOS v2\alikhlas_v2.db'
$installed = $false

function Invoke-AndRequireSuccess {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @(),
    [int]$TimeoutMilliseconds = 60000
  )
  $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru
  if (-not $process.WaitForExit($TimeoutMilliseconds)) {
    $process.Kill($true)
    throw "Timed out while running: $FilePath"
  }
  if ($process.ExitCode -ne 0) {
    throw "Command failed with exit code $($process.ExitCode): $FilePath"
  }
}

function Install-Package {
  param([Parameter(Mandatory = $true)][string]$Path)
  Invoke-AndRequireSuccess -FilePath $Path -Arguments @('/S')
  $script:installed = $true
}

function Invoke-SmokeCheck {
  if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Installed executable is missing: $executable"
  }
  Invoke-AndRequireSuccess -FilePath $executable -Arguments @('--installer-smoke-check') -TimeoutMilliseconds 30000
}

function Remove-Package {
  if (-not (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
    throw "Installed uninstaller is missing: $uninstaller"
  }
  Invoke-AndRequireSuccess -FilePath $uninstaller -Arguments @('/S')
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  while ((Test-Path -LiteralPath $installDirectory) -and [DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 250
  }
  if (Test-Path -LiteralPath $installDirectory) {
    throw "Uninstaller did not finish removing: $installDirectory"
  }
  $script:installed = $false
}

try {
  if (Test-Path -LiteralPath $installDirectory) {
    throw "Acceptance runner was not clean: $installDirectory already exists."
  }
  if (Test-Path -LiteralPath $databasePath) {
    throw "Acceptance runner already contains application data: $databasePath"
  }

  Install-Package -Path $older
  Invoke-SmokeCheck
  foreach ($requiredPath in @($uninstaller, $desktopShortcut, $startMenuShortcut, $registryPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
      throw "Installer did not create required path: $requiredPath"
    }
  }

  if (-not (Test-Path -LiteralPath $databasePath -PathType Leaf)) {
    throw "Installed application did not create its database at: $databasePath"
  }
  $database = Get-Item -LiteralPath $databasePath
  $sentinel = Join-Path $database.DirectoryName 'installer-data-sentinel'
  Set-Content -LiteralPath $sentinel -Value 'preserve-me' -Encoding utf8NoBOM

  Install-Package -Path $current
  $displayVersion = (Get-ItemProperty -LiteralPath $registryPath).DisplayVersion
  if ($displayVersion -ne $ExpectedVersion) {
    throw "Installer upgrade kept version $displayVersion instead of $ExpectedVersion."
  }
  Invoke-SmokeCheck
  if (-not (Test-Path -LiteralPath $database.FullName -PathType Leaf) -or
      (Get-Content -LiteralPath $sentinel -Raw).Trim() -ne 'preserve-me') {
    throw 'Application data did not survive the installer upgrade.'
  }

  Remove-Package
  foreach ($removedPath in @($installDirectory, $desktopShortcut, $startMenuShortcut, $registryPath)) {
    if (Test-Path -LiteralPath $removedPath) {
      throw "Uninstaller left installed program state behind: $removedPath"
    }
  }
  if (-not (Test-Path -LiteralPath $database.FullName -PathType Leaf) -or
      (Get-Content -LiteralPath $sentinel -Raw).Trim() -ne 'preserve-me') {
    throw 'Uninstaller removed application data.'
  }

  Install-Package -Path $current
  Invoke-SmokeCheck
  if (-not (Test-Path -LiteralPath $database.FullName -PathType Leaf) -or
      (Get-Content -LiteralPath $sentinel -Raw).Trim() -ne 'preserve-me') {
    throw 'Application data did not survive reinstall.'
  }
  Remove-Package

  Write-Host "Windows installer acceptance passed; version $ExpectedVersion launched and data survived upgrade, removal, and reinstall."
}
finally {
  if ($installed -and (Test-Path -LiteralPath $uninstaller -PathType Leaf)) {
    Start-Process -FilePath $uninstaller -ArgumentList @('/S') -Wait | Out-Null
  }
}
