[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("linear_base", "linear_impact_response", "linear_acoustic_field", "linear_acoustic_field_3d_air", "linear_all", "linear_acoustic_param_study")]
    [string]$Target,

    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "full",

    [string]$ConfigPath = "",
    [string]$BaseConfigPath = "",
    [string]$ImpactConfigPath = "",
    [string]$AcousticConfigPath = "",

    [ValidateSet("timbre", "amplitude", "frequency", "all")]
    [string]$Study = "all",

    [ValidateSet("one_at_a_time")]
    [string]$Design = "one_at_a_time",

    [double[]]$ImpulseValuesNs = @(0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22),
    [double[]]$LFreeValuesCm = @(11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 29),
    [double[]]$X0Ratios = @(0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.85, 0.88, 0.90, 0.93, 0.95),
    [double[]]$WidthValuesCm = @(0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5),
    [double[]]$ThicknessValuesMm = @(0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3, 3.5, 4, 5),

    [string]$ComsolBin = $env:COMSOL_BIN,

    [string]$OutputStudyId = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "comsol_common.ps1")

function Read-JsonUtf8 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Assert-ExistingPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Message`nMissing path: $Path"
    }
}

function Get-ManifestPathForLinearTarget {
    param([Parameter(Mandatory = $true)][string]$ModelId)

    switch ($ModelId) {
        "base" { return (Join-Path $repoRoot "outputs\linear\base\logs\linear_base_matlab_manifest.json") }
        "impact_response" { return (Join-Path $repoRoot "outputs\linear\impact_response\logs\linear_impact_response_matlab_manifest.json") }
        "acoustic_field" { return (Join-Path $repoRoot "outputs\linear\acoustic_field\logs\linear_acoustic_field_matlab_manifest.json") }
        "acoustic_field_3d_air" { return (Join-Path $repoRoot "outputs\linear\acoustic_field_3d_air\logs\linear_acoustic_field_3d_air_matlab_manifest.json") }
        default { throw "Unsupported linear model id: $ModelId" }
    }
}

function Get-LatestStudyManifestPath {
    param([datetime]$RunStart)

    $studiesRoot = Join-Path $repoRoot "outputs\linear\sweep"
    Assert-ExistingPath -Path $studiesRoot -Message "Parameter-study output root was not created."

    $latest = Get-ChildItem -LiteralPath $studiesRoot -Directory -Filter "study_*" -ErrorAction Stop |
        Where-Object { $_.LastWriteTime -ge $RunStart.AddSeconds(-2) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $latest) {
        $latest = Get-ChildItem -LiteralPath $studiesRoot -Directory -Filter "study_*" -ErrorAction Stop |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }
    if ($null -eq $latest) {
        throw "No acoustic parameter-study output directory was found."
    }

    return (Join-Path $latest.FullName "logs\linear_acoustic_param_study_matlab_manifest.json")
}

function Get-MphPathsFromManifest {
    param([Parameter(Mandatory = $true)][object]$Manifest)

    $paths = New-Object System.Collections.Generic.List[string]
    if ($Manifest.PSObject.Properties["mph_path"] -and -not [string]::IsNullOrWhiteSpace([string]$Manifest.mph_path)) {
        $paths.Add([string]$Manifest.mph_path)
    }
    if ($Manifest.PSObject.Properties["study_manifest_path"] -and (Test-Path -LiteralPath ([string]$Manifest.study_manifest_path))) {
        $studyManifest = Read-JsonUtf8 -Path ([string]$Manifest.study_manifest_path)
        foreach ($case in @($studyManifest.cases)) {
            if ($case.PSObject.Properties["mph_path"] -and -not [string]::IsNullOrWhiteSpace([string]$case.mph_path)) {
                $paths.Add([string]$case.mph_path)
            }
        }
    }
    return @($paths.ToArray())
}

function New-PostprocessBundle {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string[]]$ManifestPaths,
        [Parameter(Mandatory = $true)][string]$Title,
        [switch]$UseManifestAsAuthority
    )

    $resolvedManifestPaths = @()
    foreach ($manifestPath in $ManifestPaths) {
        Assert-ExistingPath -Path $manifestPath -Message "MATLAB handoff manifest was not generated."
        $resolvedManifestPaths += (Resolve-Path -LiteralPath $manifestPath).Path
    }

    $script = New-MatlabPostprocessScript `
        -ScriptPath $ScriptPath `
        -ProjectRoot $repoRoot `
        -ManifestPaths $resolvedManifestPaths `
        -Title $Title

    $mphPaths = New-Object System.Collections.Generic.List[string]
    foreach ($manifestPath in $resolvedManifestPaths) {
        $manifest = Read-JsonUtf8 -Path $manifestPath
        $statusPath = [string]$manifest.status_path
        if (-not [string]::IsNullOrWhiteSpace($statusPath)) {
            $statusMessage = if ($UseManifestAsAuthority) {
                "COMSOL build completed. Continue with run_matlab_manifest(manifest_path) from the active MATLAB session."
            }
            else {
                "COMSOL build completed. Run the generated MATLAB postprocess script from MATLAB: {0}" -f $script
            }
            Write-CodexMatlabStatusFile `
                -StatusPath $statusPath `
                -State "pending" `
                -ManifestPath $manifestPath `
                -EntryFunction ([string]$manifest.entry_function) `
                -LogPath ([string]$manifest.log_path) `
                -Message $statusMessage
        }
        foreach ($mphPath in @(Get-MphPathsFromManifest -Manifest $manifest)) {
            Assert-ExistingPath -Path $mphPath -Message "COMSOL model was not generated."
            $mphPaths.Add($mphPath)
        }
    }

    return [pscustomobject]@{
        ScriptPath = $script
        ManifestPaths = $resolvedManifestPaths
        MphPaths = @($mphPaths.ToArray())
        UseManifestAsAuthority = [bool]$UseManifestAsAuthority
    }
}

function Write-PostprocessInstructions {
    param([Parameter(Mandatory = $true)][object]$Bundle)

    Write-Host ""
    Write-Host "COMSOL model(s):"
    foreach ($mphPath in @($Bundle.MphPaths)) {
        Write-Host $mphPath
    }
    Write-Host ""
    Write-Host "MATLAB handoff manifest(s):"
    foreach ($manifestPath in @($Bundle.ManifestPaths)) {
        Write-Host $manifestPath
    }
    Write-Host ""
    if ($Bundle.PSObject.Properties["UseManifestAsAuthority"] -and $Bundle.UseManifestAsAuthority) {
        Write-Host "Formal MATLAB postprocess path:"
        Write-Host "Use the handoff manifest as the authority for MATLAB postprocess."
        Write-Host ""
        Write-Host "Run this in MATLAB:"
        Write-Host ("cd('{0}')" -f (($repoRoot) -replace '\\','/'))
        Write-Host "addpath(genpath(fullfile(pwd, 'matlab')))"
        Write-Host "setenv('TSR_COMSOL_PORT', '2038')"
        Write-Host ("run_matlab_manifest('{0}')" -f (($Bundle.ManifestPaths[0]) -replace '\\','/'))
    }
    else {
        Write-Host "MATLAB postprocess script:"
        Write-Host $Bundle.ScriptPath
        Write-Host ""
        Write-Host "Run this in MATLAB:"
        Write-Host (Format-MatlabRunCommand -ScriptPath $Bundle.ScriptPath)
    }
}

function New-LinearPostprocessBundle {
    param(
        [Parameter(Mandatory = $true)][string]$ModelId,
        [Parameter(Mandatory = $true)][string]$Title,
        [switch]$UseManifestAsAuthority
    )

    $outputLeaf = switch ($ModelId) {
        "base" { "base" }
        "impact_response" { "impact_response" }
        "acoustic_field" { "acoustic_field" }
        "acoustic_field_3d_air" { "acoustic_field_3d_air" }
        default { throw "Unsupported linear model id: $ModelId" }
    }

    return New-PostprocessBundle `
        -ScriptPath (Join-Path $repoRoot "outputs\linear\$outputLeaf\run_matlab_postprocess.m") `
        -ManifestPaths @((Get-ManifestPathForLinearTarget -ModelId $ModelId)) `
        -Title $Title `
        -UseManifestAsAuthority:$UseManifestAsAuthority
}

$runStart = Get-Date

switch ($Target) {
    "linear_base" {
        $args = @{
            Model = "base"
            Quality = $Quality
            ComsolBin = $ComsolBin
            SkipMatlabPostprocess = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $args.BaseConfigPath = $ConfigPath
        }
        & (Join-Path $repoRoot "models\linear\run.ps1") @args
        $bundle = New-LinearPostprocessBundle -ModelId "base" -Title "Singing ruler linear/base MATLAB postprocess"
        Write-PostprocessInstructions -Bundle $bundle
    }
    "linear_impact_response" {
        $args = @{
            Model = "impact_response"
            Quality = $Quality
            ComsolBin = $ComsolBin
            SkipMatlabPostprocess = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $args.ImpactConfigPath = $ConfigPath
        }
        & (Join-Path $repoRoot "models\linear\run.ps1") @args
        $bundle = New-LinearPostprocessBundle -ModelId "impact_response" -Title "Singing ruler linear/impact_response MATLAB postprocess"
        Write-PostprocessInstructions -Bundle $bundle
    }
    "linear_acoustic_field" {
        $args = @{
            Model = "acoustic_field"
            Quality = $Quality
            ComsolBin = $ComsolBin
            SkipMatlabPostprocess = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $args.AcousticConfigPath = $ConfigPath
        }
        & (Join-Path $repoRoot "models\linear\run.ps1") @args
        $bundle = New-LinearPostprocessBundle -ModelId "acoustic_field" -Title "Singing ruler linear/acoustic_field MATLAB postprocess"
        Write-PostprocessInstructions -Bundle $bundle
    }
    "linear_acoustic_field_3d_air" {
        $args = @{
            Model = "acoustic_field_3d_air"
            Quality = $Quality
            ComsolBin = $ComsolBin
            SkipMatlabPostprocess = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
            $args.Acoustic3DAirConfigPath = $ConfigPath
        }
        & (Join-Path $repoRoot "models\linear\run.ps1") @args
        $bundle = New-LinearPostprocessBundle -ModelId "acoustic_field_3d_air" -Title "Singing ruler linear/acoustic_field_3d_air MATLAB postprocess" -UseManifestAsAuthority
        Write-PostprocessInstructions -Bundle $bundle
    }
    "linear_all" {
        $args = @{
            Model = "ALL"
            Quality = $Quality
            ComsolBin = $ComsolBin
            SkipMatlabPostprocess = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($BaseConfigPath)) {
            $args.BaseConfigPath = $BaseConfigPath
        }
        if (-not [string]::IsNullOrWhiteSpace($ImpactConfigPath)) {
            $args.ImpactConfigPath = $ImpactConfigPath
        }
        if (-not [string]::IsNullOrWhiteSpace($AcousticConfigPath)) {
            $args.AcousticConfigPath = $AcousticConfigPath
        }
        & (Join-Path $repoRoot "models\linear\run.ps1") @args
        $null = New-LinearPostprocessBundle -ModelId "base" -Title "Singing ruler linear/base MATLAB postprocess"
        $null = New-LinearPostprocessBundle -ModelId "impact_response" -Title "Singing ruler linear/impact_response MATLAB postprocess"
        $null = New-LinearPostprocessBundle -ModelId "acoustic_field" -Title "Singing ruler linear/acoustic_field MATLAB postprocess"
        $bundle = New-PostprocessBundle `
            -ScriptPath (Join-Path $repoRoot "outputs\linear\run_matlab_postprocess_all.m") `
            -ManifestPaths @(
                (Get-ManifestPathForLinearTarget -ModelId "base"),
                (Get-ManifestPathForLinearTarget -ModelId "impact_response"),
                (Get-ManifestPathForLinearTarget -ModelId "acoustic_field")
            ) `
            -Title "Singing ruler linear/all MATLAB postprocess"
        Write-PostprocessInstructions -Bundle $bundle
    }
    "linear_acoustic_param_study" {
        $args = @{
            Study = $Study
            Design = $Design
            Quality = $Quality
            ImpulseValuesNs = $ImpulseValuesNs
            LFreeValuesCm = $LFreeValuesCm
            X0Ratios = $X0Ratios
            WidthValuesCm = $WidthValuesCm
            ThicknessValuesMm = $ThicknessValuesMm
            ComsolBin = $ComsolBin
            SkipMatlabPostprocess = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($OutputStudyId)) {
            $args.OutputStudyId = $OutputStudyId
        }
        & (Join-Path $repoRoot "models\linear\acoustic_field\param_study.ps1") @args
        $manifestPath = Get-LatestStudyManifestPath -RunStart $runStart
        $manifest = Read-JsonUtf8 -Path $manifestPath
        $scriptRoot = [string]$manifest.output_root
        $bundle = New-PostprocessBundle `
            -ScriptPath (Join-Path $scriptRoot "run_matlab_postprocess.m") `
            -ManifestPaths @($manifestPath) `
            -Title "Singing ruler linear/acoustic parameter study MATLAB postprocess" `
            -UseManifestAsAuthority
        Write-PostprocessInstructions -Bundle $bundle
    }
}
