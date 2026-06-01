#Requires -Version 5.1
<#
.SYNOPSIS
    Install Framework into the current directory (Cursor terminal / any cwd).

.EXAMPLE
    framework-install
    framework-install -Mode wally
#>
[CmdletBinding()]
param(
    [ValidateSet('wally', 'local', 'rbxm')]
    [string] $Mode = 'local',

    [string] $Version = '',

    [string] $ProjectFile = ''
)

$ErrorActionPreference = 'Stop'

function Resolve-FrameworkRoot {
    if ($env:FRAMEWORK_ROOT -and (Test-Path (Join-Path $env:FRAMEWORK_ROOT 'scripts\install-framework.ps1'))) {
        return (Resolve-Path $env:FRAMEWORK_ROOT).Path
    }

    $fromScript = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    if (Test-Path (Join-Path $fromScript 'scripts\install-framework.ps1')) {
        return $fromScript
    }

    throw @"
FRAMEWORK_ROOT is not set and this script is not inside the Framework repo.
Run once from Framework-v2:
  .\scripts\setup-cursor.ps1
Or set FRAMEWORK_ROOT to your Framework-v2 folder.
"@
}

$repoRoot = Resolve-FrameworkRoot
$target = (Get-Location).Path
$installer = Join-Path $repoRoot 'scripts\install-framework.ps1'

if (-not (Test-Path $installer)) {
    throw "Installer not found: $installer"
}

$params = @{
    Target = $target
    Mode   = $Mode
}
if ($Version) { $params.Version = $Version }
if ($ProjectFile) { $params.ProjectFile = $ProjectFile }

& $installer @params
