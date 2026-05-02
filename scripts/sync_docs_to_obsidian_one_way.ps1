[CmdletBinding()]
param(
    [string]$VaultProjectPath = "D:\Learning Resources\Obsidian\Archive\物理学术竞赛\Main 13  The Singing Ruler",
    [string]$OutputSubdir = "Generated from Repo\docs",
    [switch]$DryRun,
    [switch]$NoPrune
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Escape-YamlDoubleQuoted {
    param([Parameter(Mandatory = $true)][string]$Text)

    return $Text.Replace("\", "\\").Replace('"', '\"')
}

function Copy-DocToObsidian {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$SourceFile,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$SyncedAt
    )

    $sourceText = Get-Content -LiteralPath $SourceFile.FullName -Encoding UTF8 -Raw
    $relativeSource = [System.IO.Path]::GetRelativePath($RepoRoot, $SourceFile.FullName).Replace("\", "/")
    $title = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile.Name)
    $frontMatter = @(
        "---",
        "type: repo-doc-snapshot",
        ("title: ""{0}""" -f (Escape-YamlDoubleQuoted $title)),
        ("source: ""{0}""" -f (Escape-YamlDoubleQuoted $relativeSource)),
        ("repo_root: ""{0}""" -f (Escape-YamlDoubleQuoted $RepoRoot.Replace("\", "/"))),
        ("synced_at: ""{0}""" -f $SyncedAt),
        "sync_direction: repo-to-obsidian",
        "tags:",
        "  - the-singing-ruler",
        "  - repo-doc",
        "  - codex-sync",
        "---",
        "",
        ("同步时间：{0}" -f $SyncedAt),
        "",
        ('> Source: `{0}`' -f $relativeSource),
        "",
        $sourceText
    ) -join [Environment]::NewLine

    if ($DryRun) {
        Write-Host "[dry-run] write $DestinationPath"
        return
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $DestinationPath) | Out-Null
    Write-Utf8NoBomText -Path $DestinationPath -Text $frontMatter
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$docsRoot = Join-Path $repoRoot "docs"
if (-not (Test-Path -LiteralPath $docsRoot)) {
    throw "Docs directory not found: $docsRoot"
}
if (-not (Test-Path -LiteralPath $VaultProjectPath)) {
    throw "Obsidian project path not found: $VaultProjectPath"
}

$targetRoot = Join-Path $VaultProjectPath $OutputSubdir
$syncedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
$sourceFiles = Get-ChildItem -LiteralPath $docsRoot -Filter "*.md" -File | Sort-Object Name
$expectedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
}

foreach ($file in $sourceFiles) {
    [void]$expectedNames.Add($file.Name)
    $destinationPath = Join-Path $targetRoot $file.Name
    Copy-DocToObsidian -SourceFile $file -DestinationPath $destinationPath -RepoRoot $repoRoot -SyncedAt $syncedAt
}

$indexPath = Join-Path $targetRoot "00 Docs Sync Index.md"
[void]$expectedNames.Add("00 Docs Sync Index.md")
$indexLines = New-Object System.Collections.Generic.List[string]
$indexLines.Add("---")
$indexLines.Add("type: repo-doc-sync-index")
$indexLines.Add("project: The Singing Ruler")
$indexLines.Add(("repo_root: ""{0}""" -f (Escape-YamlDoubleQuoted $repoRoot.Replace("\", "/"))))
$indexLines.Add(("synced_at: ""{0}""" -f $syncedAt))
$indexLines.Add("sync_direction: repo-to-obsidian")
$indexLines.Add("tags:")
$indexLines.Add("  - the-singing-ruler")
$indexLines.Add("  - repo-doc")
$indexLines.Add("  - codex-sync")
$indexLines.Add("---")
$indexLines.Add("")
$indexLines.Add("# Docs Sync Index")
$indexLines.Add("")
$indexLines.Add(("同步时间：{0}" -f $syncedAt))
$indexLines.Add("")
$indexLines.Add('本目录由仓库 `docs/` 单向同步生成。请不要在此目录直接编辑；如需修改内容，请改仓库 `docs/` 源文件后重新同步。')
$indexLines.Add("")
$indexLines.Add("## Synced Docs")
$indexLines.Add("")
foreach ($file in $sourceFiles) {
    $nameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $indexLines.Add(("- [[{0}|{1}]]" -f $nameWithoutExtension, $nameWithoutExtension))
}

if ($DryRun) {
    Write-Host "[dry-run] write $indexPath"
} else {
    Write-Utf8NoBomText -Path $indexPath -Text ($indexLines -join [Environment]::NewLine)
}

if (-not $NoPrune -and (Test-Path -LiteralPath $targetRoot)) {
    $existingMarkdownFiles = Get-ChildItem -LiteralPath $targetRoot -Filter "*.md" -File
    foreach ($existingFile in $existingMarkdownFiles) {
        if (-not $expectedNames.Contains($existingFile.Name)) {
            if ($DryRun) {
                Write-Host "[dry-run] remove stale $($existingFile.FullName)"
            } else {
                Remove-Item -LiteralPath $existingFile.FullName -Force
            }
        }
    }
}

Write-Host "==> Repo docs: $docsRoot"
Write-Host "==> Obsidian target: $targetRoot"
Write-Host "==> Synced at: $syncedAt"
Write-Host "==> Synced docs: $($sourceFiles.Count)"
Write-Host "==> Index: $indexPath"
