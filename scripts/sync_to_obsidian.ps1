# sync_to_obsidian.ps1
# Sync project documents and data to Obsidian vault.
# Usage: .\scripts\sync_to_obsidian.ps1
# Configure paths below for each project.

param(
    [string]$OBSIDIAN_VAULT = "D:\Learning Resources\Obsidian\Archive\物理学术竞赛\Main 13  The Singing Ruler\Generated from Repo"
)

$ErrorActionPreference = "Stop"

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot

# ---- Paths to sync ----
$syncMap = @(
    # Source (relative to project root)     -> Destination (relative to vault)
    @{Src = "docs/00_项目导航/*.md";           Dst = "docs/00_项目导航/"},
    @{Src = "docs/01_理论推导/*.md";           Dst = "docs/01_理论推导/"},
    @{Src = "docs/02_仿真方案/*.md";           Dst = "docs/02_仿真方案/"},
    @{Src = "docs/04_报告与PPT/*.md";          Dst = "docs/04_报告与PPT/"},
    @{Src = "README.md";                    Dst = ""},
    @{Src = "CLAUDE.md";                    Dst = ""},
    @{Src = "CLAUDE.md";                    Dst = ""},
    @{Src = "outputs/unified_v2_4mat/tables/conclusion_master_table.csv"; Dst = "outputs/unified_v2_4mat/tables/"},
    @{Src = "outputs/unified_v2_4mat/animation/*.gif";  Dst = "outputs/unified_v2_4mat/animation/"},
    @{Src = "outputs/steel_gnl_on_v2/tables/conclusion_master_table.csv";  Dst = "outputs/steel_gnl_on_v2/tables/"},
    @{Src = "outputs/steel_gnl_off_v2/tables/conclusion_master_table.csv"; Dst = "outputs/steel_gnl_off_v2/tables/"},
    @{Src = "the_singing_ruler_unified/src/Linear_Acoustic_Field_3D_Air.java.template"; Dst = "src/"},
    @{Src = "the_singing_ruler_unified/tools/run_case.py";  Dst = "tools/"},
    @{Src = "the_singing_ruler_unified/tools/run_requested_full.py"; Dst = "tools/"},
    @{Src = "matlab/plot/animate_ruler_vibration.m"; Dst = "matlab/plot/"},
    @{Src = "matlab/extract/analyze_mode_types.m";  Dst = "matlab/extract/"}
)

# ---- Sync each entry ----
$synced = 0
$skipped = 0

foreach ($entry in $syncMap) {
    $srcPath = Join-Path $PROJECT_ROOT $entry.Src
    $dstDir  = Join-Path $OBSIDIAN_VAULT $entry.Dst

    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    $files = Get-ChildItem $srcPath -ErrorAction SilentlyContinue
    if (-not $files) {
        Write-Host "SKIP (no files): $($entry.Src)" -ForegroundColor Yellow
        $skipped++
        continue
    }

    foreach ($f in $files) {
        $dstFile = Join-Path $dstDir $f.Name
        $srcTime = $f.LastWriteTime
        $dstTime = (Get-Item $dstFile -ErrorAction SilentlyContinue).LastWriteTime

        if ($dstTime -and $dstTime -ge $srcTime) {
            # Already up to date
            continue
        }

        Copy-Item $f.FullName $dstFile -Force
        Write-Host "SYNC: $($f.Name) -> $($entry.Dst)" -ForegroundColor Green
        $synced++
    }
}

Write-Host ""
Write-Host "Done: $synced files synced, $skipped entries skipped." -ForegroundColor Cyan
Write-Host "Vault: $OBSIDIAN_VAULT"
