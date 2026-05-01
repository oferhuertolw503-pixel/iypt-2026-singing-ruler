[CmdletBinding()]
param(
    [string]$ManifestRoot = "outputs",
    [string]$QueuePath = "outputs\automation\matlab_manifest_queue.json",
    [string]$ReportPath = "outputs\automation\matlab_manifest_queue_report.md",
    [switch]$IncludeHistory,
    [switch]$IncludeUnknownMatlabOnly,
    [switch]$Force,
    [ValidateRange(0, 100000)]
    [int]$MaxQueued = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "comsol_common.ps1")

function Resolve-RepoPath {
    param(
        [string]$RepoRoot,
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return (Join-Path $RepoRoot $Path)
}

function Write-Utf8NoBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Resolve-StatusPath {
    param(
        [object]$Manifest,
        [string]$ManifestPath,
        [string]$RepoRoot
    )

    $statusPath = ""
    if ($Manifest.PSObject.Properties["status_path"]) {
        $statusPath = [string]$Manifest.status_path
    }
    if (-not [string]::IsNullOrWhiteSpace($statusPath)) {
        return (Resolve-RepoPath -RepoRoot $RepoRoot -Path $statusPath)
    }

    $manifestDir = Split-Path -Parent $ManifestPath
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($ManifestPath)
    if ($stem -like "*_manifest") {
        $stem = $stem.Substring(0, $stem.Length - "_manifest".Length)
    }
    return (Join-Path $manifestDir ($stem + "_status.json"))
}

function Read-StatusState {
    param([string]$StatusPath)

    if ([string]::IsNullOrWhiteSpace($StatusPath) -or -not (Test-Path -LiteralPath $StatusPath)) {
        return "missing"
    }
    try {
        $status = Get-Content -LiteralPath $StatusPath -Encoding UTF8 -Raw | ConvertFrom-Json
        if ($status.PSObject.Properties["status"]) {
            return [string]$status.status
        }
    }
    catch {
    }
    return "unreadable"
}

function Get-RequiredCsvPaths {
    param([object]$Manifest)

    $outputRoot = [string]$Manifest.output_root
    if ([string]::IsNullOrWhiteSpace($outputRoot)) {
        return @()
    }

    $entryFunction = [string]$Manifest.entry_function
    $dataDirName = ""
    $requiredFiles = @()

    switch -Wildcard ($entryFunction) {
        "*3d_air_from_manifest" {
            $dataDirName = "data"
            $requiredFiles = @(
                "frequencies.csv",
                "structure_probe_timeseries.csv",
                "mode_shapes.csv",
                "mic_pressure_timeseries.csv",
                "impact_force_timeseries.csv"
            )
            break
        }
        "*acoustic_field_from_manifest" {
            $dataDirName = "data"
            $requiredFiles = @(
                "frequencies.csv",
                "tip_timeseries.csv",
                "mode_shapes.csv",
                "mic_pressure_timeseries.csv"
            )
            break
        }
        "*base_from_manifest" {
            $dataDirName = "results"
            $requiredFiles = @(
                "frequencies.csv",
                "tip_timeseries.csv",
                "mode_shapes.csv"
            )
            break
        }
        "*impact_response_from_manifest" {
            $dataDirName = "results"
            $requiredFiles = @(
                "frequencies.csv",
                "tip_timeseries.csv",
                "mode_shapes.csv"
            )
            break
        }
        default {
            return @()
        }
    }

    $dataRoot = Join-Path $outputRoot $dataDirName
    return @($requiredFiles | ForEach-Object { Join-Path $dataRoot $_ })
}

function New-QueueEntry {
    param(
        [string]$RepoRoot,
        [System.IO.FileInfo]$ManifestFile
    )

    $manifest = Get-Content -LiteralPath $ManifestFile.FullName -Encoding UTF8 -Raw | ConvertFrom-Json
    $statusPath = Resolve-StatusPath -Manifest $manifest -ManifestPath $ManifestFile.FullName -RepoRoot $RepoRoot
    $statusState = Read-StatusState -StatusPath $statusPath
    $requiredCsv = @(Get-RequiredCsvPaths -Manifest $manifest)
    $missingCsv = @($requiredCsv | Where-Object { -not (Test-Path -LiteralPath $_) })
    $mphPath = ""
    if ($manifest.PSObject.Properties["mph_path"]) {
        $mphPath = [string]$manifest.mph_path
    }

    $action = "queued"
    $reason = "matlab_only_or_unknown"
    if ($statusState -eq "completed" -and -not $Force) {
        $action = "skipped"
        $reason = "already_completed"
    } elseif ($requiredCsv.Count -gt 0 -and $missingCsv.Count -eq 0) {
        $action = "queued"
        $reason = "csv_ready"
    } elseif ($requiredCsv.Count -gt 0 -and $missingCsv.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($mphPath)) {
        $action = "skipped"
        $reason = "needs_comsol_csv"
    } elseif ($requiredCsv.Count -gt 0 -and $missingCsv.Count -gt 0) {
        $action = "skipped"
        $reason = "missing_csv"
    } elseif ($requiredCsv.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($mphPath)) {
        $action = "skipped"
        $reason = "comsol_dependent_unknown_csv_contract"
    } elseif ($requiredCsv.Count -eq 0 -and -not $IncludeUnknownMatlabOnly) {
        $action = "skipped"
        $reason = "unknown_matlab_contract"
    }

    [ordered]@{
        action = $action
        reason = $reason
        status = $statusState
        manifest_path = $ManifestFile.FullName
        entry_function = [string]$manifest.entry_function
        output_root = [string]$manifest.output_root
        status_path = $statusPath
        required_csv = @($requiredCsv)
        missing_csv = @($missingCsv)
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedManifestRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestRoot
$resolvedQueuePath = Resolve-RepoPath -RepoRoot $repoRoot -Path $QueuePath
$resolvedReportPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ReportPath

if (-not (Test-Path -LiteralPath $resolvedManifestRoot)) {
    throw "Manifest root not found: $resolvedManifestRoot"
}

$manifestFiles = @(Get-ChildItem -LiteralPath $resolvedManifestRoot -Recurse -Filter "*matlab_manifest.json" -File)
if (-not $IncludeHistory) {
    $historyRoot = Join-Path $repoRoot "outputs\history"
    $manifestFiles = @($manifestFiles | Where-Object { -not $_.FullName.StartsWith($historyRoot, [System.StringComparison]::OrdinalIgnoreCase) })
}

$entries = @()
foreach ($manifestFile in $manifestFiles) {
    try {
        $entries += New-QueueEntry -RepoRoot $repoRoot -ManifestFile $manifestFile
    }
    catch {
        $entries += [ordered]@{
            action = "skipped"
            reason = "manifest_read_error"
            status = "unknown"
            manifest_path = $manifestFile.FullName
            entry_function = ""
            output_root = ""
            status_path = ""
            required_csv = @()
            missing_csv = @()
            error = $_.ToString()
        }
    }
}

if ($MaxQueued -gt 0) {
    $queuedSeen = 0
    foreach ($entry in $entries) {
        if ($entry.action -eq "queued") {
            $queuedSeen += 1
            if ($queuedSeen -gt $MaxQueued) {
                $entry.action = "skipped"
                $entry.reason = "max_queued_limit"
            }
        }
    }
}

$queueDir = Split-Path -Parent $resolvedQueuePath
$reportDir = Split-Path -Parent $resolvedReportPath
New-Item -ItemType Directory -Force -Path $queueDir | Out-Null
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$queue = [ordered]@{
    generated_at = (Get-Date).ToString("o")
    project_root = $repoRoot
    queue_path = $resolvedQueuePath
    matlab_command = "cd('$($repoRoot.Replace('\','/'))'); addpath(genpath(fullfile(pwd,'matlab'))); run_pending_matlab_manifests;"
    matlab_batch_command = "cd('$($repoRoot.Replace('\','/'))'); addpath(genpath(fullfile(pwd,'matlab'))); run_matlab_manifest_queue('$($resolvedQueuePath.Replace('\','/'))');"
    entries = @($entries)
}

$queueJson = $queue | ConvertTo-Json -Depth 8
Write-Utf8NoBomText -Path $resolvedQueuePath -Text $queueJson

$queuedCount = @($entries | Where-Object { $_.action -eq "queued" }).Count
$skippedCount = @($entries | Where-Object { $_.action -eq "skipped" }).Count
$needsComsolCount = @($entries | Where-Object { $_.reason -eq "needs_comsol_csv" }).Count

$report = New-Object System.Collections.Generic.List[string]
$report.Add("# MATLAB Manifest Automation Queue")
$report.Add("")
$report.Add(("Generated: {0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")))
$report.Add("")
$report.Add(('Project root: `{0}`' -f $repoRoot))
$report.Add(('Queue path: `{0}`' -f $resolvedQueuePath))
$report.Add("")
$report.Add("## Summary")
$report.Add("")
$report.Add(("| queued | skipped | needs_comsol_csv |"))
$report.Add(("|---:|---:|---:|"))
$report.Add(("| {0} | {1} | {2} |" -f $queuedCount, $skippedCount, $needsComsolCount))
$report.Add("")
$report.Add("## Automatic MATLAB Batch Command")
$report.Add("")
$report.Add("The full workflow script runs this automatically:")
$report.Add("")
$report.Add('```matlab')
$report.Add($queue.matlab_batch_command)
$report.Add('```')
$report.Add("")
$report.Add("## Manual Fallback MATLAB Command")
$report.Add("")
$report.Add("Only use this if you intentionally want an already-open MATLAB session:")
$report.Add("")
$report.Add('```matlab')
$report.Add($queue.matlab_command)
$report.Add('```')
$report.Add("")
$report.Add("## Entries")
$report.Add("")
$report.Add("| action | reason | status | entry_function | manifest |")
$report.Add("|---|---|---|---|---|")
foreach ($entry in $entries) {
    $rel = Resolve-Path -LiteralPath $entry.manifest_path -Relative
    $report.Add(('| {0} | {1} | {2} | `{3}` | `{4}` |' -f $entry.action, $entry.reason, $entry.status, $entry.entry_function, $rel))
}

Write-Utf8NoBomText -Path $resolvedReportPath -Text ($report -join [Environment]::NewLine)

Write-Host "==> Wrote MATLAB queue: $resolvedQueuePath"
Write-Host "==> Wrote report: $resolvedReportPath"
Write-Host "==> Queued: $queuedCount; skipped: $skippedCount; needs_comsol_csv: $needsComsolCount"
Write-Host ""
Write-Host "Automatic MATLAB batch command:"
Write-Host $queue.matlab_batch_command
