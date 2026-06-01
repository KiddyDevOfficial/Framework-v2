#Requires -Version 5.1
<#
.SYNOPSIS
    One-time setup: global `framework-install` command + Cursor task for any workspace.

.EXAMPLE
    .\scripts\setup-cursor.ps1
#>
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CliDir = Join-Path $env:LOCALAPPDATA 'framework-cli'
$ShimPath = Join-Path $CliDir 'framework-install.cmd'

function Write-Info([string] $Message) {
    Write-Host "[setup] $Message" -ForegroundColor Cyan
}

function Write-Ok([string] $Message) {
    Write-Host "[setup] $Message" -ForegroundColor Green
}

# User env: FRAMEWORK_ROOT
[Environment]::SetEnvironmentVariable('FRAMEWORK_ROOT', $RepoRoot, 'User')
$env:FRAMEWORK_ROOT = $RepoRoot
Write-Ok "FRAMEWORK_ROOT = $RepoRoot"

# Global shim on PATH
if (-not (Test-Path $CliDir)) {
    New-Item -ItemType Directory -Path $CliDir | Out-Null
}

$shimContent = @"
@echo off
setlocal EnableExtensions
set "FRAMEWORK_ROOT=$RepoRoot"
powershell -NoProfile -ExecutionPolicy Bypass -File "%FRAMEWORK_ROOT%\scripts\cursor-install.ps1" %*
"@

Set-Content -Path $ShimPath -Value $shimContent -Encoding ASCII
Write-Ok "Shim: $ShimPath"

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$CliDir*") {
  $newPath = if ($userPath) { "$userPath;$CliDir" } else { $CliDir }
  [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
  $env:Path = "$env:Path;$CliDir"
  Write-Ok 'Added %LOCALAPPDATA%\framework-cli to user PATH'
}
else {
  Write-Info 'framework-cli already on PATH'
}

# Cursor user task (any opened project / workspace folder)
$cursorUser = Join-Path $env:APPDATA 'Cursor\User'
if (-not (Test-Path $cursorUser)) {
  New-Item -ItemType Directory -Path $cursorUser | Out-Null
}

$tasksPath = Join-Path $cursorUser 'tasks.json'
$task = [ordered]@{
  label = 'Install Framework (current project)'
  type  = 'shell'
  command = 'framework-install'
  options = [ordered]@{
    cwd = '${workspaceFolder}'
  }
  presentation = [ordered]@{
    reveal = 'always'
    panel  = 'shared'
    focus  = $true
  }
  problemMatcher = @()
}

$tasks = @{ version = '2.0.0'; tasks = @($task) }

if (Test-Path $tasksPath) {
  $raw = Get-Content $tasksPath -Raw
  try {
    $existing = $raw | ConvertFrom-Json
    $list = @()
    if ($existing.tasks) {
      $list = @($existing.tasks | Where-Object { $_.label -ne $task.label })
    }
    $tasks.tasks = @($list) + @($task)
  }
  catch {
    Write-Warning "Could not parse $tasksPath - writing fresh tasks.json"
  }
}

($tasks | ConvertTo-Json -Depth 10) | Set-Content -Path $tasksPath -Encoding UTF8
Write-Ok "Cursor task: $tasksPath"

Write-Host ''
Write-Host 'Done. In any project opened in Cursor:' -ForegroundColor Green
Write-Host '  1. Open integrated terminal (cwd = project root)' -ForegroundColor DarkGray
Write-Host '  2. Run:  framework-install' -ForegroundColor White
Write-Host '     Or:   Ctrl+Shift+P -> Tasks: Run Task -> Install Framework (current project)' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'Restart the terminal (or Cursor) once so PATH / FRAMEWORK_ROOT apply.' -ForegroundColor Yellow
