# sync_to_obsidian_generic.ps1 — Reusable Obsidian vault sync for any project
#
# SETUP (once per project):
#   1. Copy this script to <project>/scripts/
#   2. Edit the two variables below
#   3. Run: .\scripts\sync_to_obsidian_generic.ps1
#
# The vault directory structure mirrors the project structure.
# Add entries to $syncMap to include additional files/folders.

param(
    # Obsidian vault root path
    [string]$OBSIDIAN_VAULT = "D:\Learning Resources\Obsidian\Archive\物理学术竞赛\Main 13  The Singing Ruler\Generated from Repo"
)

$ErrorActionPreference = "Continue"
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot

# ============================================================
# CONFIGURATION — Edit this array for each project
# Each entry: @{Src = "relative/path/from/project/root"; Dst = "relative/path/from/vault/root"}
# Use *.md, *.csv, *.gif wildcards. Directories are auto-created.
# ============================================================

$syncMap = @(
    # --- Documents ---
    @{Src = "README.md";        Dst = ""},
    @{Src = "CLAUDE.md";        Dst = ""},
    @{Src = "docs/reports/*.md"; Dst = "docs/reports/"},

    # --- Simulation outputs (conclusion tables, animations) ---
    @{Src = "outputs/*/tables/conclusion_master_table.csv"; Dst = "outputs/"},
    @{Src = "outputs/*/animation/*.gif"; Dst = "outputs/"},

    # --- Source code (key files only) ---
    @{Src = "src/*.java";        Dst = "src/"},
    @{Src = "tools/*.py";        Dst = "tools/"},
    @{Src = "matlab/**/*.m";     Dst = "matlab/"}
)

# ============================================================
# END CONFIGURATION
# ============================================================

function Sync-FileSafe($srcPattern, $dstRelDir) {
    $srcFull = Join-Path $PROJECT_ROOT $srcPattern
    $dstFull = Join-Path $OBSIDIAN_VAULT $dstRelDir

    if (-not (Test-Path $dstFull)) {
        New-Item -ItemType Directory -Path $dstFull -Force | Out-Null
    }

    $files = Get-ChildItem $srcFull -ErrorAction SilentlyContinue
    if (-not $files) { return @() }

    $results = @()
    foreach ($f in $files) {
        if ($f.PSIsContainer) { continue }
        $dst = Join-Path $dstFull $f.Name
        Copy-Item $f.FullName $dst -Force
        $results += "$($f.Name) -> $dstRelDir"
    }
    return $results
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Obsidian Vault Sync" -ForegroundColor Cyan
Write-Host " Project: $PROJECT_ROOT" -ForegroundColor Cyan
Write-Host " Vault:   $OBSIDIAN_VAULT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$totalFiles = 0
foreach ($entry in $syncMap) {
    $results = Sync-FileSafe $entry.Src $entry.Dst
    foreach ($r in $results) {
        Write-Host "  SYNC  $r" -ForegroundColor Green
        $totalFiles++
    }
}

Write-Host ""
Write-Host "Done: $totalFiles files synced." -ForegroundColor Cyan
Write-Host ""

# Optional: open Obsidian vault
# Start-Process "obsidian://open?vault=$OBSIDIAN_VAULT"
