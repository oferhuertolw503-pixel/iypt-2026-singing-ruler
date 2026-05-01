[CmdletBinding()]
param(
    [string]$ManifestRoot = "outputs",
    [string]$QueuePath = "outputs\automation\matlab_manifest_queue.json",
    [string]$QueueReportPath = "outputs\automation\matlab_manifest_queue_report.md",
    [string]$FinalReportPath = "outputs\automation\matlab_full_automation_report.md",
    [string]$MatlabExe = "",
    [switch]$IncludeHistory,
    [switch]$IncludeUnknownMatlabOnly,
    [switch]$Force,
    [ValidateRange(0, 100000)]
    [int]$MaxQueued = 0,
    [switch]$SkipMatlabRun
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

function Read-JsonOrNull {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return Get-Content -LiteralPath $Path -Encoding UTF8 -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

function Write-Utf8NoBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Get-EntryCount {
    param(
        [object[]]$Entries,
        [string]$Property,
        [string]$Value
    )

    return @($Entries | Where-Object { [string]$_.$Property -eq $Value }).Count
}

function Write-FinalReport {
    param(
        [string]$Path,
        [string]$RepoRoot,
        [string]$QueuePath,
        [string]$QueueReportPath,
        [object]$Queue,
        [object[]]$RunResults,
        [string]$MatlabExit,
        [string]$MatlabLogPath,
        [string]$GitStatus
    )

    $reportDir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

    $entries = @()
    if ($null -ne $Queue -and $Queue.PSObject.Properties["entries"]) {
        $entries = @($Queue.entries)
    }

    $queued = Get-EntryCount -Entries $entries -Property "action" -Value "queued"
    $skipped = Get-EntryCount -Entries $entries -Property "action" -Value "skipped"
    $needsComsol = Get-EntryCount -Entries $entries -Property "reason" -Value "needs_comsol_csv"
    $completed = Get-EntryCount -Entries $RunResults -Property "result" -Value "completed"
    $failed = Get-EntryCount -Entries $RunResults -Property "result" -Value "failed"
    $runSkipped = Get-EntryCount -Entries $RunResults -Property "result" -Value "skipped"

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# MATLAB Full Automation Report")
    $lines.Add("")
    $lines.Add(("Generated: {0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")))
    $lines.Add("")
    $lines.Add(('Project root: `{0}`' -f $RepoRoot))
    $lines.Add(('Queue: `{0}`' -f $QueuePath))
    $lines.Add(('Queue report: `{0}`' -f $QueueReportPath))
    $lines.Add(('MATLAB log: `{0}`' -f $MatlabLogPath))
    $lines.Add("")
    $lines.Add("## Summary")
    $lines.Add("")
    $lines.Add("| queued | skipped | needs_comsol_csv | completed | failed | run_skipped | matlab_exit |")
    $lines.Add("|---:|---:|---:|---:|---:|---:|---|")
    $lines.Add(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} |" -f $queued, $skipped, $needsComsol, $completed, $failed, $runSkipped, $MatlabExit))
    $lines.Add("")
    $lines.Add("## Boundary")
    $lines.Add("")
    $lines.Add("- MATLAB batch is run automatically by this script.")
    $lines.Add('- COMSOL, LiveLink, `mphstart`, and `ModelUtil` are not started by default.')
    $lines.Add('- COMSOL-dependent manifests without CSV are marked `needs_comsol_csv` and skipped.')
    $lines.Add("")
    $lines.Add("## Run Results")
    $lines.Add("")
    $lines.Add("| result | action | reason | manifest | message |")
    $lines.Add("|---|---|---|---|---|")
    foreach ($result in $RunResults) {
        $manifest = [string]$result.manifest_path
        $message = ([string]$result.message).Replace("|", "\|").Replace("`r", " ").Replace("`n", " ")
        $lines.Add(('| {0} | {1} | {2} | `{3}` | {4} |' -f $result.result, $result.action, $result.reason, $manifest, $message))
    }
    $lines.Add("")
    $lines.Add("## Git Status")
    $lines.Add("")
    $lines.Add('```text')
    if ([string]::IsNullOrWhiteSpace($GitStatus)) {
        $lines.Add("(clean or unavailable)")
    } else {
        $lines.Add($GitStatus.TrimEnd())
    }
    $lines.Add('```')

    Write-Utf8NoBomText -Path $Path -Text ($lines -join [Environment]::NewLine)
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedQueuePath = Resolve-RepoPath -RepoRoot $repoRoot -Path $QueuePath
$resolvedQueueReportPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $QueueReportPath
$resolvedFinalReportPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $FinalReportPath
$resolvedMatlabExe = Resolve-MatlabExe -InputPath $MatlabExe
$automationDir = Split-Path -Parent $resolvedFinalReportPath
New-Item -ItemType Directory -Force -Path $automationDir | Out-Null

Write-Host "==> Preparing MATLAB automation queue"
$prepareArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $PSScriptRoot "prepare_matlab_automation_queue.ps1"),
    "-ManifestRoot", $ManifestRoot,
    "-QueuePath", $resolvedQueuePath,
    "-ReportPath", $resolvedQueueReportPath
)
if ($IncludeHistory) { $prepareArgs += "-IncludeHistory" }
if ($IncludeUnknownMatlabOnly) { $prepareArgs += "-IncludeUnknownMatlabOnly" }
if ($Force) { $prepareArgs += "-Force" }
if ($MaxQueued -gt 0) { $prepareArgs += @("-MaxQueued", [string]$MaxQueued) }

& powershell @prepareArgs
if ($LASTEXITCODE -ne 0) {
    throw "Queue preparation failed with exit code $LASTEXITCODE"
}

$queue = Read-JsonOrNull -Path $resolvedQueuePath
if ($null -eq $queue) {
    throw "Failed to read generated queue: $resolvedQueuePath"
}

$matlabLogPath = Join-Path $automationDir ("matlab_full_automation_{0}.log" -f (Get-Date).ToString("yyyyMMdd_HHmmss"))
$matlabExit = "skipped"
$runResults = @()

if (-not $SkipMatlabRun) {
    $queueArg = $resolvedQueuePath.Replace("\", "/")
    $repoArg = $repoRoot.Replace("\", "/")
    $batchCommand = "cd('$repoArg'); addpath(genpath(fullfile(pwd,'matlab'))); results = run_matlab_manifest_queue('$queueArg');"

    Write-Host "==> Running MATLAB batch queue"
    & $resolvedMatlabExe -batch $batchCommand *> $matlabLogPath
    $exitCode = $LASTEXITCODE
    $matlabExit = [string]$exitCode

    if ($exitCode -ne 0) {
        Write-Warning "MATLAB batch returned exit code $exitCode. See $matlabLogPath"
    }

    $latestResult = Get-ChildItem -LiteralPath (Split-Path -Parent $resolvedQueuePath) -Filter "matlab_manifest_queue_result_*.json" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -ne $latestResult) {
        $parsedResults = Read-JsonOrNull -Path $latestResult.FullName
        if ($null -ne $parsedResults) {
            $runResults = @($parsedResults)
        }
    }
}

if ($runResults.Count -eq 0 -and $queue.PSObject.Properties["entries"]) {
    $runResults = @($queue.entries | ForEach-Object {
        [pscustomobject]@{
            manifest_path = [string]$_.manifest_path
            action = [string]$_.action
            reason = [string]$_.reason
            result = if ([string]$_.action -eq "queued") { "not_run" } else { "skipped" }
            message = if ($SkipMatlabRun) { "MATLAB run skipped by parameter." } else { "No MATLAB result JSON was produced." }
        }
    })
}

$gitStatus = ""
try {
    $gitStatus = (& git -C $repoRoot status --short | Out-String)
}
catch {
    $gitStatus = "git status unavailable: $($_.Exception.Message)"
}

Write-FinalReport `
    -Path $resolvedFinalReportPath `
    -RepoRoot $repoRoot `
    -QueuePath $resolvedQueuePath `
    -QueueReportPath $resolvedQueueReportPath `
    -Queue $queue `
    -RunResults $runResults `
    -MatlabExit $matlabExit `
    -MatlabLogPath $matlabLogPath `
    -GitStatus $gitStatus

Write-Host "==> Wrote final report: $resolvedFinalReportPath"
Write-Host "==> MATLAB exit: $matlabExit"
