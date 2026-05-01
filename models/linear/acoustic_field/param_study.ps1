[CmdletBinding()]
param(
    [ValidateSet("timbre", "amplitude", "frequency", "all")]
    [string]$Study = "all",

    [ValidateSet("one_at_a_time")]
    [string]$Design = "one_at_a_time",

    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "full",

    [double[]]$ImpulseValuesNs = @(0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22),
    [double[]]$LFreeValuesCm = @(11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 29),
    [double[]]$X0Ratios = @(0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.85, 0.88, 0.90, 0.93, 0.95),
    [double[]]$WidthValuesCm = @(0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5),
    [double[]]$ThicknessValuesMm = @(0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3, 3.5, 4, 5),

    [string]$ComsolBin = $env:COMSOL_BIN,
    [string]$OutputStudyId = "",

    [ValidateRange(0, 65535)]
    [int]$LocalComsolPort = 0,

    [switch]$SkipMatlabPostprocess
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
. (Join-Path $repoRoot "scripts\comsol_common.ps1")

function Format-InvariantNumber {
    param(
        [Parameter(Mandatory = $true)][double]$Value,
        [string]$Format = "0.###"
    )

    return $Value.ToString($Format, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Test-IsClose {
    param(
        [Parameter(Mandatory = $true)][double]$Left,
        [Parameter(Mandatory = $true)][double]$Right,
        [double]$Tolerance = 1e-9
    )

    return [Math]::Abs($Left - $Right) -le $Tolerance
}

function Convert-ToToken {
    param(
        [Parameter(Mandatory = $true)][double]$Value,
        [string]$Format = "0.###"
    )

    $text = Format-InvariantNumber -Value $Value -Format $Format
    $text = $text -replace '-', 'm'
    $text = $text -replace '\.', 'p'
    return $text
}

function Set-ObjectPropertyValueLocal {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
    else {
        $prop.Value = $Value
    }
}

function Get-SelectedStudies {
    param([Parameter(Mandatory = $true)][string]$StudySelection)

    switch ($StudySelection) {
        "timbre" { return @("timbre") }
        "amplitude" { return @("amplitude") }
        "frequency" { return @("frequency") }
        "all" { return @("timbre", "amplitude", "frequency") }
        default { throw "Unsupported study selection: $StudySelection" }
    }
}

function Get-VariableStudyTags {
    param(
        [Parameter(Mandatory = $true)][string]$VariableName,
        [Parameter(Mandatory = $true)][string[]]$SelectedStudies
    )

    $capability = switch ($VariableName) {
        "baseline" { @("timbre", "amplitude", "frequency") }
        "J" { @("timbre", "amplitude", "frequency") }
        "L_free" { @("amplitude", "frequency") }
        "x0_ratio" { @("amplitude", "frequency") }
        "b" { @("amplitude", "frequency") }
        "h" { @("amplitude", "frequency") }
        default { throw "Unsupported primary variable: $VariableName" }
    }

    return @($capability | Where-Object { $SelectedStudies -contains $_ })
}

function Assert-PositiveScanValues {
    param(
        [Parameter(Mandatory = $true)][double[]]$Values,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$FailureDetail = ""
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        throw "Scan list '$Name' must contain at least one value."
    }

    $invalid = @($Values | Where-Object { $_ -le 0 })
    if ($invalid.Count -gt 0) {
        $detail = if ([string]::IsNullOrWhiteSpace($FailureDetail)) {
            "'$Name' must be strictly greater than zero."
        }
        else {
            $FailureDetail
        }
        throw ("Invalid scan list '{0}'. {1} Offending values: {2}" -f $Name, $detail, (($invalid | ForEach-Object {
                    Format-InvariantNumber -Value ([double]$_)
                }) -join ", "))
    }
}

function Assert-X0RatioValues {
    param([Parameter(Mandatory = $true)][double[]]$Values)

    if ($null -eq $Values -or $Values.Count -eq 0) {
        throw "Scan list 'X0Ratios' must contain at least one value."
    }

    $invalid = @($Values | Where-Object { $_ -le 0 -or $_ -ge 1 })
    if ($invalid.Count -gt 0) {
        throw ("Invalid scan list 'X0Ratios'. Ratios must satisfy 0 < ratio < 1. Offending values: {0}" -f (($invalid | ForEach-Object {
                    Format-InvariantNumber -Value ([double]$_)
                }) -join ", "))
    }
}

function Get-UniqueSortedValues {
    param([Parameter(Mandatory = $true)][double[]]$Values)

    return @($Values | Sort-Object -Unique)
}

function New-CaseRecord {
    param(
        [Parameter(Mandatory = $true)][string]$CaseId,
        [Parameter(Mandatory = $true)][bool]$IsBaseline,
        [Parameter(Mandatory = $true)][string]$PrimaryVariable,
        [Parameter(Mandatory = $true)][string[]]$StudyTags,
        [Parameter(Mandatory = $true)][double]$LFreeCm,
        [Parameter(Mandatory = $true)][double]$X0Ratio,
        [Parameter(Mandatory = $true)][double]$BCm,
        [Parameter(Mandatory = $true)][double]$HMm,
        [Parameter(Mandatory = $true)][double]$JNs
    )

    $x0Cm = [Math]::Round($LFreeCm * $X0Ratio, 6)
    return [pscustomobject][ordered]@{
        case_id = $CaseId
        is_baseline = $IsBaseline
        primary_variable = $PrimaryVariable
        study_tags = @($StudyTags)
        L_free_cm = [Math]::Round($LFreeCm, 6)
        x0_ratio = [Math]::Round($X0Ratio, 6)
        x0_cm = $x0Cm
        b_cm = [Math]::Round($BCm, 6)
        h_mm = [Math]::Round($HMm, 6)
        J_Ns = [Math]::Round($JNs, 6)
    }
}

function New-CaseConfigObject {
    param(
        [Parameter(Mandatory = $true)][object]$BaseConfig,
        [Parameter(Mandatory = $true)][object]$CaseRecord
    )

    $config = $BaseConfig | ConvertTo-Json -Depth 64 | ConvertFrom-Json
    $config.geometry.L_free = ("{0}[m]" -f (Format-InvariantNumber -Value ([double]$CaseRecord.L_free_cm / 100.0) -Format "0.00000"))
    $config.geometry.b = ("{0}[m]" -f (Format-InvariantNumber -Value ([double]$CaseRecord.b_cm / 100.0) -Format "0.00000"))
    $config.geometry.h = ("{0}[m]" -f (Format-InvariantNumber -Value ([double]$CaseRecord.h_mm / 1000.0) -Format "0.00000"))
    $config.excitation.x0 = ("{0}*L_free" -f (Format-InvariantNumber -Value ([double]$CaseRecord.x0_ratio) -Format "0.0000"))
    $config.excitation.J = ("{0}[N*s]" -f (Format-InvariantNumber -Value ([double]$CaseRecord.J_Ns) -Format "0.00000"))
    return $config
}

function Get-CaseOutputRoot {
    param(
        [Parameter(Mandatory = $true)][string]$StudyRoot,
        [Parameter(Mandatory = $true)][object]$CaseRecord
    )

    if ([bool]$CaseRecord.is_baseline) {
        return (Join-Path $StudyRoot "cases\baseline")
    }

    return (Join-Path (Join-Path $StudyRoot ("cases\" + [string]$CaseRecord.primary_variable)) ([string]$CaseRecord.case_id))
}

function Get-CaseBuildSummary {
    param(
        [Parameter(Mandatory = $true)][object]$CaseRecord,
        [Parameter(Mandatory = $true)][string]$CaseRoot
    )

    $summary = $CaseRecord | ConvertTo-Json -Depth 16 | ConvertFrom-Json
    Set-ObjectPropertyValueLocal -Object $summary -Name "output_root" -Value $CaseRoot
    Set-ObjectPropertyValueLocal -Object $summary -Name "case_manifest_path" -Value (Join-Path $CaseRoot "logs\linear_acoustic_field_matlab_manifest.json")
    Set-ObjectPropertyValueLocal -Object $summary -Name "case_status_path" -Value (Join-Path $CaseRoot "logs\linear_acoustic_field_matlab_status.json")
    Set-ObjectPropertyValueLocal -Object $summary -Name "case_log_path" -Value (Join-Path $CaseRoot "logs\linear_acoustic_field.log")
    Set-ObjectPropertyValueLocal -Object $summary -Name "params_resolved_path" -Value (Join-Path $CaseRoot "params_resolved.json")
    Set-ObjectPropertyValueLocal -Object $summary -Name "mph_path" -Value (Join-Path $CaseRoot "mph\linear_acoustic_field.mph")
    Set-ObjectPropertyValueLocal -Object $summary -Name "summary_json_path" -Value (Join-Path $CaseRoot "summary.json")
    Set-ObjectPropertyValueLocal -Object $summary -Name "summary_txt_path" -Value (Join-Path $CaseRoot "summary.txt")
    Set-ObjectPropertyValueLocal -Object $summary -Name "run_manifest_path" -Value (Join-Path $CaseRoot "run_manifest.txt")
    Set-ObjectPropertyValueLocal -Object $summary -Name "frequencies_csv_path" -Value (Join-Path $CaseRoot "data\frequencies.csv")
    Set-ObjectPropertyValueLocal -Object $summary -Name "tip_timeseries_csv_path" -Value (Join-Path $CaseRoot "data\tip_timeseries.csv")
    Set-ObjectPropertyValueLocal -Object $summary -Name "mode_shapes_csv_path" -Value (Join-Path $CaseRoot "data\mode_shapes.csv")
    Set-ObjectPropertyValueLocal -Object $summary -Name "mic_pressure_timeseries_csv_path" -Value (Join-Path $CaseRoot "data\mic_pressure_timeseries.csv")
    Set-ObjectPropertyValueLocal -Object $summary -Name "mic_pressure_fft_csv_path" -Value (Join-Path $CaseRoot "data\mic_pressure_fft.csv")
    Set-ObjectPropertyValueLocal -Object $summary -Name "q_estimate_json_path" -Value (Join-Path $CaseRoot "data\q_estimate.json")
    return $summary
}

function Get-ProvenanceSummary {
    param([Parameter(Mandatory = $true)][object[]]$Cases)

    $verifiedRealComsol = 0
    $withMph = 0
    $withLog = 0
    $withCsvBundle = 0

    foreach ($case in $Cases) {
        $hasMph = Test-Path -LiteralPath ([string]$case.mph_path)
        $hasLog = Test-Path -LiteralPath ([string]$case.case_log_path)
        $hasCsvBundle =
            (Test-Path -LiteralPath ([string]$case.frequencies_csv_path)) -and
            (Test-Path -LiteralPath ([string]$case.mode_shapes_csv_path)) -and
            (Test-Path -LiteralPath ([string]$case.mic_pressure_timeseries_csv_path))

        if ($hasMph) { $withMph += 1 }
        if ($hasLog) { $withLog += 1 }
        if ($hasCsvBundle) { $withCsvBundle += 1 }
        if ($hasMph -and $hasLog -and $hasCsvBundle) {
            $verifiedRealComsol += 1
        }
    }

    return [ordered]@{
        case_count_total = $Cases.Count
        case_count_with_mph = $withMph
        case_count_with_comsol_log = $withLog
        case_count_with_java_raw_csv_bundle = $withCsvBundle
        case_count_verified_real_comsol = $verifiedRealComsol
        all_cases_verified_real_comsol = ($verifiedRealComsol -eq $Cases.Count)
    }
}

Assert-PositiveScanValues -Values $ImpulseValuesNs -Name "ImpulseValuesNs"
Assert-PositiveScanValues -Values $LFreeValuesCm -Name "LFreeValuesCm"
Assert-PositiveScanValues -Values $WidthValuesCm -Name "WidthValuesCm" -FailureDetail "Zero or negative width would degenerate the beam section physically."
Assert-PositiveScanValues -Values $ThicknessValuesMm -Name "ThicknessValuesMm" -FailureDetail "Zero or negative thickness would degenerate the beam section physically."
Assert-X0RatioValues -Values $X0Ratios

$ImpulseValuesNs = Get-UniqueSortedValues -Values $ImpulseValuesNs
$LFreeValuesCm = Get-UniqueSortedValues -Values $LFreeValuesCm
$X0Ratios = Get-UniqueSortedValues -Values $X0Ratios
$WidthValuesCm = Get-UniqueSortedValues -Values $WidthValuesCm
$ThicknessValuesMm = Get-UniqueSortedValues -Values $ThicknessValuesMm

$baseline = [ordered]@{
    L_free_cm = 20.0
    x0_ratio = 0.85
    x0_cm = 17.0
    b_cm = 3.0
    h_mm = 1.0
    J_Ns = 0.08
}

$selectedStudies = Get-SelectedStudies -StudySelection $Study
$selectedVariables = [System.Collections.Generic.List[string]]::new()
if ($selectedStudies -contains "timbre") { $null = $selectedVariables.Add("J") }
if ($selectedStudies -contains "amplitude" -or $selectedStudies -contains "frequency") {
    foreach ($variable in @("L_free", "x0_ratio", "b", "h", "J")) {
        if (-not $selectedVariables.Contains($variable)) {
            $null = $selectedVariables.Add($variable)
        }
    }
}

$studyId = if ([string]::IsNullOrWhiteSpace($OutputStudyId)) {
    "study_{0}_{1}_{2}_{3}" -f $Study, $Design, $Quality, (Get-Date -Format "yyyyMMdd_HHmmss")
}
else {
    $OutputStudyId
}

$studyRoot = Join-Path $repoRoot ("outputs\linear\sweep\" + $studyId)
$logsDir = Join-Path $studyRoot "logs"
$tablesDir = Join-Path $studyRoot "tables"
$figuresDir = Join-Path $studyRoot "figures"
$caseConfigDir = Join-Path $logsDir "case_configs"

Initialize-CanonicalOutputRoot -OutputRoot $studyRoot
New-Item -ItemType Directory -Force -Path $studyRoot, $logsDir, $tablesDir, $figuresDir, (Join-Path $studyRoot "cases"), $caseConfigDir | Out-Null

$defaultConfigPath = Join-Path $PSScriptRoot "config\params.json"
$defaultConfig = Read-JsonFile -Path $defaultConfigPath
$ComsolBin = Resolve-ComsolBin -InputPath $ComsolBin

$caseRecords = @()
$baselineCase = New-CaseRecord `
    -CaseId "baseline" `
    -IsBaseline $true `
    -PrimaryVariable "baseline" `
    -StudyTags (Get-VariableStudyTags -VariableName "baseline" -SelectedStudies $selectedStudies) `
    -LFreeCm ([double]$baseline.L_free_cm) `
    -X0Ratio ([double]$baseline.x0_ratio) `
    -BCm ([double]$baseline.b_cm) `
    -HMm ([double]$baseline.h_mm) `
    -JNs ([double]$baseline.J_Ns)
$caseRecords += $baselineCase

foreach ($value in $ImpulseValuesNs) {
    if (Test-IsClose -Left ([double]$value) -Right ([double]$baseline.J_Ns)) {
        continue
    }

    if ($selectedVariables.Contains("J")) {
        $caseRecords += (New-CaseRecord `
                -CaseId ("J_{0}Ns" -f (Convert-ToToken -Value ([double]$value) -Format "0.###")) `
                -IsBaseline $false `
                -PrimaryVariable "J" `
                -StudyTags (Get-VariableStudyTags -VariableName "J" -SelectedStudies $selectedStudies) `
                -LFreeCm ([double]$baseline.L_free_cm) `
                -X0Ratio ([double]$baseline.x0_ratio) `
                -BCm ([double]$baseline.b_cm) `
                -HMm ([double]$baseline.h_mm) `
                -JNs ([double]$value))
    }
}

foreach ($value in $LFreeValuesCm) {
    if (-not $selectedVariables.Contains("L_free")) { continue }
    if (Test-IsClose -Left ([double]$value) -Right ([double]$baseline.L_free_cm)) { continue }
    $caseRecords += (New-CaseRecord `
            -CaseId ("L_free_{0}cm" -f (Convert-ToToken -Value ([double]$value) -Format "0.###")) `
            -IsBaseline $false `
            -PrimaryVariable "L_free" `
            -StudyTags (Get-VariableStudyTags -VariableName "L_free" -SelectedStudies $selectedStudies) `
            -LFreeCm ([double]$value) `
            -X0Ratio ([double]$baseline.x0_ratio) `
            -BCm ([double]$baseline.b_cm) `
            -HMm ([double]$baseline.h_mm) `
            -JNs ([double]$baseline.J_Ns))
}

foreach ($value in $X0Ratios) {
    if (-not $selectedVariables.Contains("x0_ratio")) { continue }
    if (Test-IsClose -Left ([double]$value) -Right ([double]$baseline.x0_ratio)) { continue }
    $caseRecords += (New-CaseRecord `
            -CaseId ("x0_ratio_{0}" -f (Convert-ToToken -Value ([double]$value) -Format "0.###")) `
            -IsBaseline $false `
            -PrimaryVariable "x0_ratio" `
            -StudyTags (Get-VariableStudyTags -VariableName "x0_ratio" -SelectedStudies $selectedStudies) `
            -LFreeCm ([double]$baseline.L_free_cm) `
            -X0Ratio ([double]$value) `
            -BCm ([double]$baseline.b_cm) `
            -HMm ([double]$baseline.h_mm) `
            -JNs ([double]$baseline.J_Ns))
}

foreach ($value in $WidthValuesCm) {
    if (-not $selectedVariables.Contains("b")) { continue }
    if (Test-IsClose -Left ([double]$value) -Right ([double]$baseline.b_cm)) { continue }
    $caseRecords += (New-CaseRecord `
            -CaseId ("b_{0}cm" -f (Convert-ToToken -Value ([double]$value) -Format "0.###")) `
            -IsBaseline $false `
            -PrimaryVariable "b" `
            -StudyTags (Get-VariableStudyTags -VariableName "b" -SelectedStudies $selectedStudies) `
            -LFreeCm ([double]$baseline.L_free_cm) `
            -X0Ratio ([double]$baseline.x0_ratio) `
            -BCm ([double]$value) `
            -HMm ([double]$baseline.h_mm) `
            -JNs ([double]$baseline.J_Ns))
}

foreach ($value in $ThicknessValuesMm) {
    if (-not $selectedVariables.Contains("h")) { continue }
    if (Test-IsClose -Left ([double]$value) -Right ([double]$baseline.h_mm)) { continue }
    $caseRecords += (New-CaseRecord `
            -CaseId ("h_{0}mm" -f (Convert-ToToken -Value ([double]$value) -Format "0.###")) `
            -IsBaseline $false `
            -PrimaryVariable "h" `
            -StudyTags (Get-VariableStudyTags -VariableName "h" -SelectedStudies $selectedStudies) `
            -LFreeCm ([double]$baseline.L_free_cm) `
            -X0Ratio ([double]$baseline.x0_ratio) `
            -BCm ([double]$baseline.b_cm) `
            -HMm ([double]$value) `
            -JNs ([double]$baseline.J_Ns))
}

$builtCases = @()
foreach ($caseRecord in $caseRecords) {
    $caseRoot = Get-CaseOutputRoot -StudyRoot $studyRoot -CaseRecord $caseRecord
    $caseConfigPath = Join-Path $caseConfigDir (([string]$caseRecord.case_id) + ".json")
    $caseConfig = New-CaseConfigObject -BaseConfig $defaultConfig -CaseRecord $caseRecord
    Write-JsonUtf8NoBomFile -Path $caseConfigPath -Data $caseConfig

    Write-Host ("==> acoustic parameter-study case: {0}" -f [string]$caseRecord.case_id)
    & (Join-Path $PSScriptRoot "run.ps1") `
        -ConfigPath $caseConfigPath `
        -Quality $Quality `
        -ComsolBin $ComsolBin `
        -OutputRoot $caseRoot `
        -LocalComsolPort $LocalComsolPort `
        -SkipMatlabPostprocess

    $builtCases += (Get-CaseBuildSummary -CaseRecord $caseRecord -CaseRoot $caseRoot)
}

$caseCountByVariable = [ordered]@{
    baseline = 1
    J = @($builtCases | Where-Object { $_.primary_variable -eq "J" }).Count
    L_free = @($builtCases | Where-Object { $_.primary_variable -eq "L_free" }).Count
    x0_ratio = @($builtCases | Where-Object { $_.primary_variable -eq "x0_ratio" }).Count
    b = @($builtCases | Where-Object { $_.primary_variable -eq "b" }).Count
    h = @($builtCases | Where-Object { $_.primary_variable -eq "h" }).Count
}

$pointCountByVariable = [ordered]@{
    J = $ImpulseValuesNs.Count
    L_free = $LFreeValuesCm.Count
    x0_ratio = $X0Ratios.Count
    b = $WidthValuesCm.Count
    h = $ThicknessValuesMm.Count
}

$studyManifestPath = Join-Path $studyRoot "study_manifest.json"
$rootLogPath = Join-Path $logsDir "linear_acoustic_param_study_matlab.log"
$rootManifestPath = Join-Path $logsDir "linear_acoustic_param_study_matlab_manifest.json"
$rootStatusPath = Join-Path $logsDir "linear_acoustic_param_study_matlab_status.json"
$rootScriptPath = Join-Path $studyRoot "run_matlab_postprocess.m"

$studyManifest = [ordered]@{
    manifest_version = 1
    created_at = (Get-Date).ToString("o")
    project_root = $repoRoot
    study_id = $studyId
    study_selection = $Study
    design = $Design
    quality = $Quality
    output_root = $studyRoot
    baseline_case_id = "baseline"
    baseline = $baseline
    scan_values = [ordered]@{
        impulse_values_ns = @($ImpulseValuesNs)
        l_free_values_cm = @($LFreeValuesCm)
        x0_ratios = @($X0Ratios)
        width_values_cm = @($WidthValuesCm)
        thickness_values_mm = @($ThicknessValuesMm)
    }
    case_count = $builtCases.Count
    case_count_by_variable = $caseCountByVariable
    point_count_by_variable = $pointCountByVariable
    cases = @($builtCases)
}
Write-JsonUtf8NoBomFile -Path $studyManifestPath -Data $studyManifest

$buildSummary = [ordered]@{
    model_line = "linear"
    model_id = "acoustic_param_study"
    study_id = $studyId
    study_selection = $Study
    design = $Design
    quality = $Quality
    output_root = $studyRoot
    baseline_case_id = "baseline"
    case_count = $builtCases.Count
    case_count_by_variable = $caseCountByVariable
    point_count_by_variable = $pointCountByVariable
    baseline = $baseline
    scan_values = $studyManifest.scan_values
    study_manifest_path = $studyManifestPath
    tables_dir = $tablesDir
    figures_dir = $figuresDir
    logs_dir = $logsDir
    provenance_check = (Get-ProvenanceSummary -Cases $builtCases)
    matlab_entry = "main_linear_acoustic_param_study_from_manifest"
    matlab_handoff_state = "pending"
}

Write-JsonUtf8NoBomFile -Path (Join-Path $studyRoot "summary.json") -Data $buildSummary
Write-SummaryTextFile -Path (Join-Path $studyRoot "run_manifest.txt") -Data ([pscustomobject]@{
        output_root = $studyRoot
        study_id = $studyId
        study_selection = $Study
        design = $Design
        quality = $Quality
    case_count = $builtCases.Count
        study_manifest = $studyManifestPath
        matlab_manifest = $rootManifestPath
        logs_dir = $logsDir
        tables_dir = $tablesDir
        figures_dir = $figuresDir
    })

New-CodexMatlabHandoffManifest `
    -ManifestPath $rootManifestPath `
    -ProjectRoot $repoRoot `
    -EntryFunction "main_linear_acoustic_param_study_from_manifest" `
    -OutputRoot $studyRoot `
    -ModelLine "linear" `
    -ModelId "acoustic_param_study" `
    -LogPath $rootLogPath `
    -StatusPath $rootStatusPath `
    -BuildWallclockSeconds "0" `
    -SourceScript "models/linear/acoustic_field/param_study.ps1" `
    -ExtraFields @{
        quality = $Quality
        study_selection = $Study
        design = $Design
        study_manifest_path = $studyManifestPath
    } | Out-Null

Write-CodexMatlabStatusFile `
    -StatusPath $rootStatusPath `
    -State "pending" `
    -ManifestPath $rootManifestPath `
    -EntryFunction "main_linear_acoustic_param_study_from_manifest" `
    -LogPath $rootLogPath `
    -Message "COMSOL study build completed. Continue with run_matlab_manifest(manifest_path) from the active MATLAB session."

$null = New-MatlabPostprocessScript `
    -ScriptPath $rootScriptPath `
    -ProjectRoot $repoRoot `
    -ManifestPaths @($rootManifestPath) `
    -Title "Singing ruler linear/acoustic parameter study MATLAB postprocess"

if ($SkipMatlabPostprocess) {
    Write-Host ("==> linear/acoustic_param_study build-only completed: {0}" -f $studyRoot)
    return
}

& (Join-Path $repoRoot "scripts\run_matlab_model.ps1") -ManifestPath $rootManifestPath -LocalComsolPort $LocalComsolPort
Write-Host ("==> linear/acoustic_param_study MATLAB handoff completed: {0}" -f $rootManifestPath)
