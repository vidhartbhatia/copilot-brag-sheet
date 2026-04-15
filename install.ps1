<#
.SYNOPSIS
    Install copilot-brag-sheet as a Copilot CLI extension.

.DESCRIPTION
    One-liner:  irm https://raw.githubusercontent.com/vidhartbhatia/copilot-brag-sheet/main/install.ps1 | iex
    From repo:  .\install.ps1

.NOTES
    Requires: git, Node.js 18+
#>

$ErrorActionPreference = "Stop"

$RepoUrl    = "https://github.com/vidhartbhatia/copilot-brag-sheet.git"
$ExtName    = "copilot-brag-sheet"
$CopilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $env:USERPROFILE ".copilot" }
$TargetDir   = Join-Path $CopilotHome "extensions" $ExtName

# ── Checks ───────────────────────────────────────────────────────────────────
Write-Host "Installing $ExtName..." -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is required but not found."; exit 1
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js 18+ is required but not found."; exit 1
}

$nodeMajor = [int](node -e "process.stdout.write(String(process.versions.node.split('.')[0]))")
if ($nodeMajor -lt 18) {
    Write-Error "Node.js 18+ required (found v$(node --version))"; exit 1
}

# ── Install ──────────────────────────────────────────────────────────────────
if (Test-Path $TargetDir) {
    Write-Host "Updating existing installation..."
    Remove-Item $TargetDir -Recurse -Force
}

# Detect if running from cloned repo
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$LocalExtension = Join-Path $ScriptDir "extension.mjs"

if (Test-Path $LocalExtension) {
    New-Item -ItemType Directory -Path (Join-Path $TargetDir "lib") -Force | Out-Null
    Copy-Item (Join-Path $ScriptDir "extension.mjs") $TargetDir
    Copy-Item (Join-Path $ScriptDir "package.json") $TargetDir
    Copy-Item (Join-Path $ScriptDir "lib" "*.mjs") (Join-Path $TargetDir "lib")
} else {
    git clone --depth 1 --quiet $RepoUrl $TargetDir
    # Clean non-essential files
    foreach ($item in @(".git", ".github", "test", "docs", "bin", "AGENTS.md", "CONTRIBUTING.md", "ROADMAP.md", "CODEOWNERS")) {
        $path = Join-Path $TargetDir $item
        if (Test-Path $path) { Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host "  ✅ Extension installed to $TargetDir" -ForegroundColor Green

# ── Config ───────────────────────────────────────────────────────────────────
$ConfigDir = if ($env:WORK_TRACKER_DIR) { $env:WORK_TRACKER_DIR }
             else { Join-Path $env:LOCALAPPDATA "copilot-brag-sheet" }
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

$config = @{ git = @{ enabled = $true; push = $false } }

# Only run interactive setup if we have a console
$isInteractive = [Environment]::UserInteractive -and $Host.Name -ne 'ServerRemoteHost'

if ($isInteractive) {
    Write-Host ""
    $msResponse = Read-Host "Are you a Microsoft employee? (enables Connect review formatting) [y/N]"
    if ($msResponse -match '^[Yy]$') {
        $config["preset"] = "microsoft"
        Write-Host "  ✅ Microsoft preset enabled" -ForegroundColor Green
    }

    Write-Host ""
    $gitResponse = Read-Host "Enable git history for your work log? (local version control) [Y/n]"
    if ($gitResponse -match '^[Nn]$') {
        $config["git"]["enabled"] = $false
    } else {
        Write-Host "  ✅ Git history enabled (local only)" -ForegroundColor Green

        Write-Host ""
        $remoteUrl = Read-Host "Sync to a remote repo? (paste GitHub/ADO URL, or press Enter to skip)"
        if ($remoteUrl) {
            $config["git"]["push"] = $true
            $remoteUrl | Set-Content (Join-Path $ConfigDir ".git-remote-pending") -Encoding UTF8
            Write-Host "  ✅ Remote sync enabled: $remoteUrl" -ForegroundColor Green
        }
    }
} else {
    Write-Host "  ⚠️  Non-interactive mode — using defaults. Edit config.json to customize." -ForegroundColor Yellow
}

$config | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $ConfigDir "config.json") -Encoding UTF8

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "🎉 copilot-brag-sheet installed!" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:"
Write-Host "    1. Run /clear in the Copilot CLI (or restart it)"
Write-Host "    2. Start a session — you'll see '📊 Work logger active'"
Write-Host "    3. Say 'brag' to save an accomplishment"
Write-Host ""
Write-Host "  Data stored at:  $ConfigDir"
Write-Host "  Extension at:    $TargetDir"
Write-Host ""
Write-Host "  Uninstall:  Remove-Item '$TargetDir' -Recurse -Force"
