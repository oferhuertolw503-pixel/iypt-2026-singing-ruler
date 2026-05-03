[CmdletBinding()]
param(
    [string]$VaultProjectPath = "",
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

function ConvertFrom-EscapedUnicode {
    param([Parameter(Mandatory = $true)][string]$Text)

    return [regex]::Replace($Text, "\\u([0-9A-Fa-f]{4})", {
        param($match)
        return [string][char][Convert]::ToInt32($match.Groups[1].Value, 16)
    })
}

function Get-RelativePathCompat {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    if ([System.IO.Path].GetMethod("GetRelativePath", [type[]]@([string], [string]))) {
        return [System.IO.Path]::GetRelativePath($BasePath, $TargetPath)
    }

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath)
    $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath)
    if (-not $baseFullPath.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $baseFullPath += [System.IO.Path]::DirectorySeparatorChar
    }

    $baseUri = [System.Uri]::new($baseFullPath)
    $targetUri = [System.Uri]::new($targetFullPath)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace("/", "\")
}

function Get-DocsCategory {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    if ($RelativePath -eq "AGENT_CONTEXT.md") {
        return "Agent Entry"
    }
    if ($RelativePath -like "rules/*") {
        return "Rules"
    }
    if ($RelativePath -like "human_archive/*") {
        return "Human Archive"
    }
    return "Workflow Docs"
}

function Copy-DocToObsidian {
    param(
        [Parameter(Mandatory = $true)][System.IO.FileInfo]$SourceFile,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$SyncedAt,
        [Parameter(Mandatory = $true)][string]$Category
    )

    $sourceText = Get-Content -LiteralPath $SourceFile.FullName -Encoding UTF8 -Raw
    $relativeSource = (Get-RelativePathCompat -BasePath $RepoRoot -TargetPath $SourceFile.FullName).Replace("\", "/")
    $title = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile.Name)
    $frontMatter = @(
        "---",
        "type: repo-doc-snapshot",
        ("title: ""{0}""" -f (Escape-YamlDoubleQuoted $title)),
        ("source: ""{0}""" -f (Escape-YamlDoubleQuoted $relativeSource)),
        ("repo_root: ""{0}""" -f (Escape-YamlDoubleQuoted $RepoRoot.Replace("\", "/"))),
        ("synced_at: ""{0}""" -f $SyncedAt),
        "sync_direction: repo-to-obsidian",
        ("docs_category: ""{0}""" -f $Category),
        "tags:",
        "  - the-singing-ruler",
        "  - repo-doc",
        "  - codex-sync",
        "---",
        "",
        ((ConvertFrom-EscapedUnicode "\u540c\u6b65\u65f6\u95f4\uff1a") + $SyncedAt),
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
if ([string]::IsNullOrWhiteSpace($VaultProjectPath)) {
    $physicsCompetition = ConvertFrom-EscapedUnicode "\u7269\u7406\u5b66\u672f\u7ade\u8d5b"
    $VaultProjectPath = Join-Path `
        (Join-Path "D:\Learning Resources\Obsidian\Archive" $physicsCompetition) `
        "Main 13  The Singing Ruler"
}
if (-not (Test-Path -LiteralPath $VaultProjectPath)) {
    throw "Obsidian project path not found: $VaultProjectPath"
}

$targetRoot = Join-Path $VaultProjectPath $OutputSubdir
$syncedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")

# Recurse into all subdirectories (rules/, human_archive/, etc.)
$sourceFiles = Get-ChildItem -LiteralPath $docsRoot -Filter "*.md" -Recurse -File | Sort-Object FullName
$expectedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
}

# Group files for index
$indexGroups = [ordered]@{
    "Agent Entry"    = [System.Collections.Generic.List[string]]::new()
    "Rules"          = [System.Collections.Generic.List[string]]::new()
    "Workflow Docs"  = [System.Collections.Generic.List[string]]::new()
    "Human Archive"  = [System.Collections.Generic.List[string]]::new()
}

foreach ($file in $sourceFiles) {
    $relativePath = Get-RelativePathCompat -BasePath $docsRoot -TargetPath $file.FullName
    $category = Get-DocsCategory -RelativePath $relativePath

    # Mirror subdirectory structure in target
    $relativeTarget = if ($file.Directory.FullName -eq $docsRoot) {
        $file.Name
    } else {
        $subDir = Get-RelativePathCompat -BasePath $docsRoot -TargetPath $file.Directory.FullName
        Join-Path $subDir $file.Name
    }

    [void]$expectedNames.Add($relativeTarget)
    $destinationPath = Join-Path $targetRoot $relativeTarget
    Copy-DocToObsidian -SourceFile $file -DestinationPath $destinationPath -RepoRoot $repoRoot -SyncedAt $syncedAt -Category $category

    # Add to index group
    $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $indexGroups[$category].Add("- [[$nameWithoutExt|$nameWithoutExt]]")
}

# Write sync index
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
$indexLines.Add((ConvertFrom-EscapedUnicode "\u540c\u6b65\u65f6\u95f4\uff1a") + $syncedAt)
$indexLines.Add("")
$indexLines.Add((ConvertFrom-EscapedUnicode "\u672c\u76ee\u5f55\u7531\u4ed3\u5e93 `docs/` \u5355\u5411\u540c\u6b65\u751f\u6210\u3002\u8bf7\u4e0d\u8981\u5728\u6b64\u76ee\u5f55\u76f4\u63a5\u7f16\u8f91\uff1b\u5982\u9700\u4fee\u6539\u5185\u5bb9\uff0c\u8bf7\u6539\u4ed3\u5e93 `docs/` \u6e90\u6587\u4ef6\u540e\u91cd\u65b0\u540c\u6b65\u3002"))
$indexLines.Add("")

foreach ($groupName in $indexGroups.Keys) {
    $files = $indexGroups[$groupName]
    if ($files.Count -eq 0) {
        continue
    }
    $indexLines.Add(("### {0}" -f $groupName))
    $indexLines.Add("")
    foreach ($link in $files) {
        $indexLines.Add($link)
    }
    $indexLines.Add("")
}

if ($DryRun) {
    Write-Host "[dry-run] write $indexPath"
} else {
    Write-Utf8NoBomText -Path $indexPath -Text ($indexLines -join [Environment]::NewLine)
}

# Prune stale files (files in target not in source)
if (-not $NoPrune -and (Test-Path -LiteralPath $targetRoot)) {
    $existingFiles = Get-ChildItem -LiteralPath $targetRoot -Filter "*.md" -Recurse -File
    foreach ($existingFile in $existingFiles) {
        $relativeExisting = Get-RelativePathCompat -BasePath $targetRoot -TargetPath $existingFile.FullName
        if (-not $expectedNames.Contains($relativeExisting)) {
            if ($DryRun) {
                Write-Host "[dry-run] remove stale $relativeExisting"
            } else {
                Remove-Item -LiteralPath $existingFile.FullName -Force
            }
        }
    }
}

Write-Host "==> Repo docs: $docsRoot (recursive)"
Write-Host "==> Obsidian target: $targetRoot"
Write-Host "==> Synced at: $syncedAt"
Write-Host "==> Synced docs: $($sourceFiles.Count)"
Write-Host "==> Index: $indexPath"
Write-Host "==> Groups: $($indexGroups.Keys -join ', ')"
