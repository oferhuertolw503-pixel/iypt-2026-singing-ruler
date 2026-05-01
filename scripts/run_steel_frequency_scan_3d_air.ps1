[CmdletBinding()]
param(
    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "coarse",

    [string]$StudyId = "",

    [double[]]$LFreeValuesCm = @(10, 14, 18, 22, 26),
    [double[]]$ThicknessValuesMm = @(1, 2, 3, 4, 5),

    [string]$ComsolBin = $env:COMSOL_BIN,
    [string]$RuntimeRoot = "",

    [switch]$PrepareOnly,
    [switch]$SkipExisting
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $repoRoot "scripts\comsol_common.ps1")

function ConvertTo-CaseToken {
    param([Parameter(Mandatory = $true)][double]$Value)

    return ((("{0:g}" -f $Value) -replace "\.", "p") -replace "-", "m")
}

function ConvertTo-MeterStringFromCm {
    param([Parameter(Mandatory = $true)][double]$ValueCm)
    return ("{0:0.########}[m]" -f ($ValueCm / 100.0))
}

function ConvertTo-MeterStringFromMm {
    param([Parameter(Mandatory = $true)][double]$ValueMm)
    return ("{0:0.########}[m]" -f ($ValueMm / 1000.0))
}

function Copy-JsonObject {
    param([Parameter(Mandatory = $true)][object]$Value)
    return ($Value | ConvertTo-Json -Depth 64 | ConvertFrom-Json)
}

function Set-ObjectValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][object]$Value
    )

    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Set-CommonSteelConfig {
    param([Parameter(Mandatory = $true)][object]$Config)

    Set-ObjectValue -Object $Config.geometry -Name "b" -Value "0.03[m]"
    Set-ObjectValue -Object $Config.excitation -Name "x0" -Value "0.8*L_free"
    Set-ObjectValue -Object $Config.excitation -Name "J" -Value "0.04[N*s]"
    Set-ObjectValue -Object $Config.excitation -Name "tau_imp" -Value "2e-3[s]"
    Set-ObjectValue -Object $Config.excitation -Name "pulse_shape" -Value "half_sine"
    Set-ObjectValue -Object $Config.acoustics -Name "mic_x" -Value "L_free/2"
    Set-ObjectValue -Object $Config.acoustics -Name "mic_y" -Value "0[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "mic_z" -Value "0.02[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "mic_offset_from_surface_m" -Value "0.02[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "radiation_source_x" -Value "L_free/2"
    Set-ObjectValue -Object $Config.acoustics -Name "radiation_source_y" -Value "0[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "radiation_source_z" -Value "0[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "air_radius" -Value "0.16[m]"
}

function New-ScanCase {
    param(
        [Parameter(Mandatory = $true)][object]$BaseConfig,
        [Parameter(Mandatory = $true)][string]$PrimaryVariable,
        [Parameter(Mandatory = $true)][string]$CaseId,
        [Parameter(Mandatory = $true)][double]$Value,
        [Parameter(Mandatory = $true)][string]$ValueUnit,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [double]$LFreeCm = 20,
        [double]$ThicknessMm = 2
    )

    $config = Copy-JsonObject -Value $BaseConfig
    Set-CommonSteelConfig -Config $config
    Set-ObjectValue -Object $config.geometry -Name "L_free" -Value (ConvertTo-MeterStringFromCm -ValueCm $LFreeCm)
    Set-ObjectValue -Object $config.geometry -Name "h" -Value (ConvertTo-MeterStringFromMm -ValueMm $ThicknessMm)
    Write-JsonUtf8NoBomFile -Path $ConfigPath -Data $config

    return [ordered]@{
        case_id = $CaseId
        primary_variable = $PrimaryVariable
        value = $Value
        value_unit = $ValueUnit
        L_free_cm = $LFreeCm
        b_cm = 3
        h_mm = $ThicknessMm
        x0_ratio = 0.8
        J_Ns = 0.04
        mic_offset_cm = 2
        output_root = $OutputRoot
        config_path = $ConfigPath
        mph_path = (Join-Path $OutputRoot "mph\linear_acoustic_field_3d_air.mph")
        mic_pressure_timeseries_csv = (Join-Path $OutputRoot "data\mic_pressure_timeseries.csv")
        frequencies_csv = (Join-Path $OutputRoot "data\frequencies.csv")
        impact_force_timeseries_csv = (Join-Path $OutputRoot "data\impact_force_timeseries.csv")
        matlab_manifest_path = (Join-Path $OutputRoot "logs\linear_acoustic_field_3d_air_matlab_manifest.json")
    }
}

if ([string]::IsNullOrWhiteSpace($StudyId)) {
    $StudyId = "steel_frequency_L_h_${Quality}_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}

$studyRoot = Join-Path $repoRoot "outputs\linear\acoustic_field_3d_air_frequency_scan\$StudyId"
$configsDir = Join-Path $studyRoot "configs"
$casesRoot = Join-Path $studyRoot "cases"
$tablesDir = Join-Path $studyRoot "tables"
$figuresDir = Join-Path $studyRoot "figures"
$logsDir = Join-Path $studyRoot "logs"
New-Item -ItemType Directory -Path $studyRoot, $configsDir, $casesRoot, $tablesDir, $figuresDir, $logsDir -Force | Out-Null

$baseConfigPath = Join-Path $repoRoot "models\linear\acoustic_field_3d_air\config\params.json"
$baseConfig = Read-JsonFile -Path $baseConfigPath
$cases = New-Object System.Collections.Generic.List[object]

foreach ($valueCm in $LFreeValuesCm) {
    $caseId = "L_free_{0}cm" -f (ConvertTo-CaseToken -Value $valueCm)
    $caseOutputRoot = Join-Path $casesRoot ("L_free\$caseId")
    $caseConfigPath = Join-Path $configsDir ($caseId + ".json")
    $case = New-ScanCase `
        -BaseConfig $baseConfig `
        -PrimaryVariable "L_free" `
        -CaseId $caseId `
        -Value $valueCm `
        -ValueUnit "cm" `
        -ConfigPath $caseConfigPath `
        -OutputRoot $caseOutputRoot `
        -LFreeCm $valueCm `
        -ThicknessMm 2
    $cases.Add([pscustomobject]$case) | Out-Null
}

foreach ($valueMm in $ThicknessValuesMm) {
    $caseId = "h_{0}mm" -f (ConvertTo-CaseToken -Value $valueMm)
    $caseOutputRoot = Join-Path $casesRoot ("h\$caseId")
    $caseConfigPath = Join-Path $configsDir ($caseId + ".json")
    $case = New-ScanCase `
        -BaseConfig $baseConfig `
        -PrimaryVariable "h" `
        -CaseId $caseId `
        -Value $valueMm `
        -ValueUnit "mm" `
        -ConfigPath $caseConfigPath `
        -OutputRoot $caseOutputRoot `
        -LFreeCm 20 `
        -ThicknessMm $valueMm
    $cases.Add([pscustomobject]$case) | Out-Null
}

$studyManifestPath = Join-Path $studyRoot "study_manifest.json"
$manifest = [ordered]@{
    study_id = $StudyId
    model_id = "linear_acoustic_field_3d_air"
    material = "steel"
    output_root = $studyRoot
    quality = $Quality
    variables = @("L_free", "h")
    omitted_variables = @("b")
    fixed_conditions = [ordered]@{
        x0 = "0.8*L_free"
        b = "0.03[m]"
        J = "0.04[N*s]"
        mic_position = "(L_free/2, 0, 0.02[m])"
        mic_offset_from_ruler = "2 cm"
        air_radius = "0.16[m]"
    }
    scan_values = [ordered]@{
        L_free_cm = $LFreeValuesCm
        h_mm = $ThicknessValuesMm
    }
    cases = @($cases.ToArray())
}
Write-JsonUtf8NoBomFile -Path $studyManifestPath -Data $manifest

if ($PrepareOnly) {
    Write-Host "Prepared steel 3D air frequency scan manifest:"
    Write-Host $studyManifestPath
    return
}

$modelRun = Join-Path $repoRoot "models\linear\acoustic_field_3d_air\run.ps1"
$runtimeBase = if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
    Join-Path $repoRoot "runtime\comsol\linear\acoustic_field_3d_air_frequency_scan\$StudyId"
}
else {
    $RuntimeRoot
}

foreach ($case in @($cases.ToArray())) {
    $caseDataPath = [string]$case.mic_pressure_timeseries_csv
    if ($SkipExisting -and (Test-Path -LiteralPath $caseDataPath)) {
        Write-Host "==> skip existing case: $($case.case_id)"
        continue
    }

    Write-Host "==> build steel frequency scan case: $($case.case_id)"
    & $modelRun `
        -ConfigPath ([string]$case.config_path) `
        -Quality $Quality `
        -ComsolBin $ComsolBin `
        -RuntimeRoot (Join-Path $runtimeBase ([string]$case.case_id)) `
        -OutputRoot ([string]$case.output_root) `
        -SkipMatlabPostprocess
}

python (Join-Path $repoRoot "scripts\plot_steel_frequency_scan_3d_air.py") --study-root $studyRoot
Write-Host "==> steel 3D air frequency scan complete:"
Write-Host $studyRoot
