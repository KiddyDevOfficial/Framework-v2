#Requires -Version 5.1
<#
.SYNOPSIS
    Installs Framework into a Roblox / Rojo project.

.DESCRIPTION
    Modes:
      wally  - Add leonardhoarau/framework to wally.toml, mount Packages in Rojo, run wally install (default).
      local  - Link this repo via Rojo path or Wally path dependency (no registry publish needed).
      rbxm   - Build framework.rbxm and copy it into the target project.

.EXAMPLE
    .\install.ps1 C:\Games\MyPlace
    .\install.ps1 -Target . -Mode local
    .\install.ps1 -Mode rbxm -Target ..\MyGame
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Target = (Get-Location).Path,

    [ValidateSet('wally', 'local', 'rbxm')]
    [string] $Mode = 'wally',

    [string] $Version = '',

    [string] $ProjectFile = ''
)

$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$PatchScript = Join-Path $PSScriptRoot 'patch-rojo-project.py'

function Write-Info([string] $Message) {
    Write-Host "[framework] $Message" -ForegroundColor Cyan
}

function Write-Ok([string] $Message) {
    Write-Host "[framework] $Message" -ForegroundColor Green
}

function Write-Warn([string] $Message) {
    Write-Host "[framework] $Message" -ForegroundColor Yellow
}

function Get-PythonCommand {
    foreach ($name in @('python', 'python3', 'py')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            if ($name -eq 'py') {
                return @{ Exe = $cmd.Source; Args = @('-3') }
            }
            return @{ Exe = $cmd.Source; Args = @() }
        }
    }
    return $null
}

function Invoke-PatchRojoProject {
    param(
        [string] $ProjectPath,
        [switch] $Packages,
        [string] $FrameworkSrc
    )

    $python = Get-PythonCommand
    if ($python) {
        $args = @($python.Args + $PatchScript, $ProjectPath)
        if ($Packages) { $args += '--packages' }
        if ($FrameworkSrc) { $args += '--framework-src'; $args += $FrameworkSrc }

        & $python.Exe @args
        if ($LASTEXITCODE -ne 0) {
            throw "patch-rojo-project.py exited with code $LASTEXITCODE"
        }
        return
    }

    Invoke-PatchRojoProjectFallback -ProjectPath $ProjectPath -Packages:$Packages -FrameworkSrc $FrameworkSrc
}

function Invoke-PatchRojoProjectFallback {
    param(
        [string] $ProjectPath,
        [switch] $Packages,
        [string] $FrameworkSrc
    )

    $content = Get-Content $ProjectPath -Raw
    $changed = $false

    if ($Packages -and $content -notmatch '"Packages"\s*:') {
        if ($content -match '"ReplicatedStorage"\s*:\s*\{') {
            $content = [regex]::Replace(
                $content,
                '("ReplicatedStorage"\s*:\s*\{)',
                "`${1}`r`n      `"Packages`": { `"`$path`": `"Packages`" },",
                1
            )
            Write-Info "Added ReplicatedStorage.Packages in $(Split-Path -Leaf $ProjectPath)"
            $changed = $true
        }
        else {
            throw 'Could not find ReplicatedStorage in project file. Add Packages manually or install Python 3 for automatic patching.'
        }
    }

    if ($FrameworkSrc) {
        $projectDir = Split-Path $ProjectPath -Parent
        $rel = Get-RelativePath $projectDir $FrameworkSrc
        $escaped = [regex]::Escape($rel)
        if ($content -match '"Framework"\s*:\s*\{[^}]*"\$path"\s*:\s*"' + $escaped + '"') {
            return
        }

        if ($content -match '"ReplicatedStorage"\s*:\s*\{') {
            $content = [regex]::Replace(
                $content,
                '("ReplicatedStorage"\s*:\s*\{)',
                "`${1}`r`n      `"Framework`": { `"`$path`": `"$rel`" },",
                1
            )
            Write-Info "Mounted ReplicatedStorage.Framework -> $rel"
            $changed = $true
        }
        else {
            throw 'Could not find ReplicatedStorage in project file. Install Python 3 or add Framework mount manually.'
        }
    }

    if ($changed) {
        Set-Content -Path $ProjectPath -Value $content -NoNewline
    }
}

function Get-FrameworkVersion {
    $wallyPath = Join-Path $RepoRoot 'wally.toml'
    if (-not (Test-Path $wallyPath)) {
        throw "Could not read version: missing $wallyPath"
    }
    $content = Get-Content $wallyPath -Raw
    if ($content -match '(?m)^version\s*=\s*"([^"]+)"') {
        return $Matches[1]
    }
    throw 'Could not parse version from wally.toml'
}

function Resolve-TargetPath([string] $Path) {
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (-not (Test-Path $resolved)) {
        throw "Target path does not exist: $resolved"
    }
    return (Resolve-Path $resolved).Path
}

function Find-ProjectFile([string] $Dir, [string] $Preferred) {
    if ($Preferred) {
        $full = Join-Path $Dir $Preferred
        if (-not (Test-Path $full)) {
            throw "Project file not found: $full"
        }
        return (Resolve-Path $full).Path
    }

    $default = Join-Path $Dir 'default.project.json'
    if (Test-Path $default) {
        return (Resolve-Path $default).Path
    }

    $candidates = @(Get-ChildItem -Path $Dir -Filter '*.project.json' -File | Sort-Object Name)
    if ($candidates.Count -eq 0) {
        return $null
    }
    return $candidates[0].FullName
}

function Get-RelativePath([string] $From, [string] $To) {
    $fromUri = (New-Object System.Uri ($From.TrimEnd('\') + '\'))
    $toUri = New-Object System.Uri $To
    $relative = $fromUri.MakeRelativeUri($toUri).ToString()
    return [System.Uri]::UnescapeDataString($relative) -replace '\\', '/'
}

function Set-WallyFrameworkDependency {
    param(
        [string] $WallyPath,
        [string] $Mode,
        [string] $Version,
        [string] $TargetDir
    )

    $lines = @(Get-Content $WallyPath)
    $frameworkLine = if ($Mode -eq 'local') {
        $relativeRepo = Get-RelativePath $TargetDir $RepoRoot
        "Framework = { path = `"$relativeRepo`" }"
    }
    else {
        "Framework = `"leonardhoarau/framework@^$Version`""
    }

    $out = New-Object System.Collections.Generic.List[string]
    $inDependencies = $false
    $replaced = $false
    $inserted = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*\[dependencies\]\s*$') {
            $inDependencies = $true
            $out.Add($line)
            continue
        }

        if ($inDependencies -and $line -match '^\s*\[') {
            if (-not $replaced -and -not $inserted) {
                $out.Add($frameworkLine)
                $inserted = $true
            }
            $inDependencies = $false
        }

        if ($inDependencies -and $line -match '^\s*Framework\s*=') {
            $out.Add($frameworkLine)
            $replaced = $true
            continue
        }

        $out.Add($line)
    }

    if (-not $replaced -and -not $inserted) {
        if (-not ($out | Where-Object { $_ -match '^\s*\[dependencies\]\s*$' })) {
            if ($out.Count -gt 0 -and $out[$out.Count - 1] -ne '') {
                $out.Add('')
            }
            $out.Add('[dependencies]')
        }
        $out.Add($frameworkLine)
    }

    Set-Content -Path $wallyPath -Value ($out -join "`n")
}

function Ensure-WallyToml([string] $TargetDir) {
    $wallyPath = Join-Path $TargetDir 'wally.toml'
    if (Test-Path $wallyPath) {
        return $wallyPath
    }

    Write-Info 'Creating wally.toml'
    @'
[package]
name = "owner/project"
version = "0.1.0"
realm = "shared"

[dependencies]
'@ | Set-Content -Path $wallyPath -Encoding UTF8

    return $wallyPath
}

function Invoke-Tool([string] $Name, [string[]] $ToolArguments, [string] $WorkingDirectory) {
    $exe = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $exe) {
        throw "$Name is not on PATH. Install tools with 'aftman install' in the Framework repo, or add $Name to PATH."
    }
    Write-Info "$Name $($ToolArguments -join ' ')"
    Push-Location $WorkingDirectory
    try {
        & $exe.Source @ToolArguments
        if ($LASTEXITCODE -ne 0) {
            throw "$Name exited with code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Install-WallyMode {
    param(
        [string] $TargetDir,
        [string] $Version,
        [string] $ProjectPath,
        [string] $DependencyMode
    )

    $wallyPath = Ensure-WallyToml $TargetDir
    Set-WallyFrameworkDependency -WallyPath $wallyPath -Mode $DependencyMode -Version $Version -TargetDir $TargetDir

    if ($ProjectPath) {
        Invoke-PatchRojoProject -ProjectPath $ProjectPath -Packages
    }
    else {
        Write-Warn 'No *.project.json found — add ReplicatedStorage.Packages with "$path": "Packages" yourself.'
    }

    Invoke-Tool 'wally' @('install') $TargetDir
}

function Install-RbxmMode {
    param(
        [string] $TargetDir
    )

    $outName = 'framework.rbxm'
    $built = Join-Path $RepoRoot $outName
    $packageProject = Join-Path $RepoRoot 'package.project.json'

    Invoke-Tool 'rojo' @('build', $packageProject, '-o', $outName) $RepoRoot

    $vendor = Join-Path $TargetDir 'vendor'
    if (-not (Test-Path $vendor)) {
        New-Item -ItemType Directory -Path $vendor | Out-Null
    }

    $dest = Join-Path $vendor $outName
    Copy-Item -Path $built -Destination $dest -Force
    Write-Ok "Copied to $dest"
    Write-Warn 'Import: drag vendor/framework.rbxm into ReplicatedStorage in Studio, or add a Rojo mount for that file.'
}

# --- main ---

$TargetDir = Resolve-TargetPath $Target
$resolvedVersion = if ($Version) { $Version } else { Get-FrameworkVersion }
$projectPath = Find-ProjectFile $TargetDir $ProjectFile

Write-Info "Target: $TargetDir"
Write-Info "Mode: $Mode"
Write-Info "Framework version: $resolvedVersion"

switch ($Mode) {
    'wally' {
        Install-WallyMode -TargetDir $TargetDir -Version $resolvedVersion -ProjectPath $projectPath -DependencyMode 'wally'
        Write-Ok 'Installed via Wally.'
        Write-Host ''
        Write-Host '  local Framework = require(game:GetService("ReplicatedStorage").Packages.Framework)' -ForegroundColor DarkGray
    }
    'local' {
        if ($projectPath) {
            $frameworkSrc = Join-Path $RepoRoot 'src\Framework'
            Invoke-PatchRojoProject -ProjectPath $projectPath -FrameworkSrc $frameworkSrc
            Write-Ok 'Linked Framework source via Rojo (no Wally).'
            Write-Host ''
            Write-Host '  local Framework = require(game:GetService("ReplicatedStorage").Framework)' -ForegroundColor DarkGray
        }
        else {
            Install-WallyMode -TargetDir $TargetDir -Version $resolvedVersion -ProjectPath $null -DependencyMode 'local'
            Write-Ok 'Installed via Wally path dependency (this repo).'
            Write-Host ''
            Write-Host '  local Framework = require(game:GetService("ReplicatedStorage").Packages.Framework)' -ForegroundColor DarkGray
        }
    }
    'rbxm' {
        Install-RbxmMode -TargetDir $TargetDir
    }
}

Write-Host ''
