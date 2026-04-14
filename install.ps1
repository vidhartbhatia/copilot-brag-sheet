# install.ps1 — Install copilot-brag-sheet as a Copilot CLI extension
#
# Usage:
#   irm https://raw.githubusercontent.com/vidhartbhatia/copilot-brag-sheet/main/install.ps1 | iex
#   # or: git clone ... && .\install.ps1

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/vidhartbhatia/copilot-brag-sheet.git"
$ExtName = "copilot-brag-sheet"
$CopilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $env:USERPROFILE ".copilot" }
$TargetDir = Join-Path $CopilotHome "extensions" $ExtName

Write-Host "Installing $ExtName..."

# Check for git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is required but not found."
    exit 1
}

# Check for node
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js 18+ is required but not found."
    exit 1
}

# Clean previous install
if (Test-Path $TargetDir) {
    Write-Host "Removing previous installation..."
    Remove-Item $TargetDir -Recurse -Force
}

# Detect if running from cloned repo
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }
$LocalExtension = Join-Path $ScriptDir "extension.mjs"

if (Test-Path $LocalExtension) {
    # Running from cloned repo — copy files
    Write-Host "Copying from local repo..."
    New-Item -ItemType Directory -Path (Join-Path $TargetDir "lib") -Force | Out-Null
    Copy-Item (Join-Path $ScriptDir "extension.mjs") $TargetDir
    Copy-Item (Join-Path $ScriptDir "package.json") $TargetDir
    Copy-Item (Join-Path $ScriptDir "lib" "*.mjs") (Join-Path $TargetDir "lib")
} else {
    # Running via irm | iex — clone fresh
    Write-Host "Cloning from GitHub..."
    git clone --depth 1 --quiet $RepoUrl $TargetDir
    # Remove non-essential files
    Remove-Item (Join-Path $TargetDir ".git") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $TargetDir ".github") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $TargetDir "test") -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "✅ Installed to: $TargetDir" -ForegroundColor Green

# ── Setup ────────────────────────────────────────────────────────────────────
# Build config interactively. All prompts are optional (default: skip).

$ConfigDir = if ($env:WORK_TRACKER_DIR) { $env:WORK_TRACKER_DIR }
             else { Join-Path $env:LOCALAPPDATA "copilot-brag-sheet" }
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

$config = @{}

# Microsoft preset
Write-Host ""
$msResponse = Read-Host "Are you a Microsoft employee? (enables Connect review formatting) [y/N]"
if ($msResponse -match '^[Yy]$') {
    $config["preset"] = "microsoft"
    Write-Host "  ✅ Microsoft preset enabled" -ForegroundColor Green
}

# Git history
Write-Host ""
$gitResponse = Read-Host "Enable git history for your work log? (local version control) [Y/n]"
if ($gitResponse -notmatch '^[Nn]$') {
    $config["git"] = @{ enabled = $true; push = $false }
    Write-Host "  ✅ Git history enabled (local only)" -ForegroundColor Green

    # Optional remote
    Write-Host ""
    $remoteUrl = Read-Host "Sync to a remote repo? (paste GitHub/ADO URL, or press Enter to skip)"
    if ($remoteUrl) {
        $config["git"]["push"] = $true
        Write-Host "  ✅ Remote sync enabled: $remoteUrl" -ForegroundColor Green
        # Save remote URL for the extension to pick up
        $remoteUrl | Set-Content (Join-Path $ConfigDir ".git-remote-pending") -Encoding UTF8
    }
}

# Write config
if ($config.Count -gt 0) {
    $config | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $ConfigDir "config.json") -Encoding UTF8
    Write-Host ""
    Write-Host "  Config saved to: $ConfigDir\config.json"
}

Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run /clear in the Copilot CLI or restart it"
Write-Host "  2. Start a session — you'll see '📊 Work logger active'"
Write-Host ""
Write-Host "To uninstall: Remove-Item '$TargetDir' -Recurse -Force"
