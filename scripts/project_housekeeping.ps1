[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$KeepBuildRuns = 2,
    [int]$KeepStudyRuns = 1,
    [switch]$IncludeRuntimeStudyCache,
    [switch]$ArchiveLegacyLinearRuntime
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Remove-OldChildren {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Filter,
        [Parameter(Mandatory = $true)][int]$Keep,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Root)) {
        return
    }

    $targets = @(Get-ChildItem -LiteralPath $Root -Directory -Filter $Filter -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)

    if ($targets.Count -le $Keep) {
        return
    }

    $targets | Select-Object -Skip $Keep | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($_.FullName, $Label)) {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
        }
    }
}

$buildRoots = @(
    (Join-Path $repoRoot "models\linear\base\artifacts\build"),
    (Join-Path $repoRoot "models\linear\impact_response\artifacts\build"),
    (Join-Path $repoRoot "models\linear\acoustic_field\artifacts\build")
)

foreach ($buildRoot in $buildRoots) {
    Remove-OldChildren -Root $buildRoot -Filter "run_*" -Keep $KeepBuildRuns -Label "Remove old build run directory"
}

Remove-OldChildren `
    -Root (Join-Path $repoRoot "outputs\linear\sweep") `
    -Filter "study_*" `
    -Keep $KeepStudyRuns `
    -Label "Remove old acoustic parameter-study output"

if ($IncludeRuntimeStudyCache) {
    Remove-OldChildren `
        -Root (Join-Path $repoRoot "runtime\comsol\linear\acoustic_param_study") `
        -Filter "study_*" `
        -Keep $KeepStudyRuns `
        -Label "Remove old acoustic parameter-study runtime cache"
}

if ($ArchiveLegacyLinearRuntime) {
    $runtimeLinearRoot = Join-Path $repoRoot "runtime\comsol\linear"
    $runtimeArchiveRoot = Join-Path $repoRoot "runtime\archive\linear"
    $allowed = @("base", "impact_response", "acoustic_field", "acoustic_param_study", "app")

    if (Test-Path -LiteralPath $runtimeLinearRoot) {
        New-Item -ItemType Directory -Force -Path $runtimeArchiveRoot | Out-Null
        Get-ChildItem -LiteralPath $runtimeLinearRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($allowed -contains $_.Name) {
                return
            }

            $destination = Join-Path $runtimeArchiveRoot $_.Name
            if ($PSCmdlet.ShouldProcess($_.FullName, "Archive legacy runtime directory")) {
                if (Test-Path -LiteralPath $destination) {
                    Remove-Item -LiteralPath $destination -Recurse -Force
                }
                Move-Item -LiteralPath $_.FullName -Destination $destination
            }
        }
    }
}
