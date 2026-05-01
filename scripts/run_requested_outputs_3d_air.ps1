[CmdletBinding()]
param(
    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "coarse",

    [string]$StudyId = "",

    [double[]]$LFreeValuesCm = @(10, 14, 18, 22, 26),
    [double[]]$WidthValuesCm = @(1, 2, 3, 4, 5),
    [double[]]$ThicknessValuesMm = @(1, 2, 3, 4, 5),
    [double[]]$X0Ratios = @(0.25, 0.50, 0.75),
    [double[]]$ImpulseValuesNs = @(0.02, 0.04, 0.06, 0.08),

    [string]$ComsolBin = $env:COMSOL_BIN,
    [string]$RuntimeRoot = "",

    [ValidateRange(1, 8)]
    [int]$MaxParallelCases = 1,

    [switch]$PrepareOnly,
    [switch]$SkipExisting,
    [switch]$SkipPlots
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $repoRoot "scripts\comsol_common.ps1")
$ComsolBin = Resolve-ComsolBin -InputPath $ComsolBin

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

function Get-RequestedAirRadiusMeters {
    param(
        [double]$LFreeCm,
        [double]$WidthCm,
        [double]$ThicknessMm
    )

    $halfLengthM = $LFreeCm / 200.0
    $halfWidthM = $WidthCm / 200.0
    $halfThicknessM = $ThicknessMm / 2000.0
    $rulerCornerRadiusM = [Math]::Sqrt(
        $halfLengthM * $halfLengthM +
        $halfWidthM * $halfWidthM +
        $halfThicknessM * $halfThicknessM
    )

    $minimumUsefulRadiusM = 0.12
    $airBoundaryClearanceM = 0.02
    return [Math]::Max($minimumUsefulRadiusM, $rulerCornerRadiusM + $airBoundaryClearanceM)
}

function ConvertTo-MeterString {
    param([Parameter(Mandatory = $true)][double]$ValueM)
    return ("{0:0.###}[m]" -f $ValueM)
}

function Get-OrCreateNoteObject {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not $Object.PSObject.Properties[$Name]) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue ([pscustomobject]@{})
    }
    return $Object.$Name
}

function Get-RequestedSolvePlan {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("timbre", "trend")][string]$RequestedRole,
        [Parameter(Mandatory = $true)][ValidateSet("coarse", "medium", "full")][string]$RequestedQuality
    )

    switch ("$RequestedRole::$RequestedQuality") {
        "timbre::full" {
            return @{
                requested_role = "timbre"
                display_quality = "full"
                model_quality = "full"
                profile_label = "full_timbre"
                mesh_numelem = 120
                mode_points = 241
                time_end = "1[s]"
                time_step = "1e-4[s]"
                modal_exports_skipped = $false
            }
        }
        "trend::medium" {
            return @{
                requested_role = "trend"
                display_quality = "medium"
                model_quality = "medium"
                profile_label = "medium_trend"
                mesh_numelem = 80
                mode_points = 161
                time_end = "0.5[s]"
                time_step = "2e-4[s]"
                modal_exports_skipped = $false
            }
        }
        "trend::full" {
            return @{
                requested_role = "trend"
                display_quality = "medium"
                model_quality = "medium"
                profile_label = "medium_trend_from_full_request"
                mesh_numelem = 80
                mode_points = 161
                time_end = "0.5[s]"
                time_step = "2e-4[s]"
                modal_exports_skipped = $false
            }
        }
        default {
            if ($RequestedRole -eq "timbre") {
                return @{
                    requested_role = "timbre"
                    display_quality = "medium"
                    model_quality = "medium"
                    profile_label = "medium_plus_timbre"
                    mesh_numelem = 80
                    mode_points = 161
                    time_end = "0.80[s]"
                    time_step = "2e-4[s]"
                    modal_exports_skipped = $false
                }
            }

            return @{
                requested_role = "trend"
                display_quality = "coarse"
                model_quality = "coarse"
                profile_label = "coarse_trend"
                mesh_numelem = 40
                mode_points = 81
                time_end = "0.10[s]"
                time_step = "1e-4[s]"
                modal_exports_skipped = $false
            }
        }
    }
}

function Test-RequestedCaseOutputsComplete {
    param([Parameter(Mandatory = $true)][object]$Case)

    $requiredPaths = @(
        [string]$Case.mph_path,
        [string]$Case.structure_probe_timeseries_csv,
        [string]$Case.mic_pressure_timeseries_csv,
        [string]$Case.impact_force_timeseries_csv
    )

    foreach ($path in $requiredPaths) {
        if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) {
            return $false
        }
    }

    return $true
}

function Invoke-RequestedCaseBuild {
    param(
        [Parameter(Mandatory = $true)][object]$Case,
        [Parameter(Mandatory = $true)][string]$ModelRunPath,
        [Parameter(Mandatory = $true)][string]$ComsolBinPath,
        [Parameter(Mandatory = $true)][string]$RuntimeBasePath
    )

    Write-Host ("==> build requested 3D air case: {0} [{1} -> {2}]" -f `
        $Case.case_id, $Case.requested_role, $Case.effective_model_quality)

    & $ModelRunPath `
        -ConfigPath ([string]$Case.config_path) `
        -Quality ([string]$Case.effective_model_quality) `
        -ComsolBin $ComsolBinPath `
        -RuntimeRoot (Join-Path $RuntimeBasePath ([string]$Case.case_id)) `
        -OutputRoot ([string]$Case.output_root) `
        -SkipMatlabPostprocess
}

function Start-RequestedCaseBuildJob {
    param(
        [Parameter(Mandatory = $true)][object]$Case,
        [Parameter(Mandatory = $true)][string]$ModelRunPath,
        [Parameter(Mandatory = $true)][string]$ComsolBinPath,
        [Parameter(Mandatory = $true)][string]$RuntimeBasePath
    )

    return Start-Job -Name ([string]$Case.case_id) -ArgumentList @(
        [string]$ModelRunPath,
        [string]$Case.config_path,
        [string]$Case.effective_model_quality,
        [string]$ComsolBinPath,
        (Join-Path $RuntimeBasePath ([string]$Case.case_id)),
        [string]$Case.output_root
    ) -ScriptBlock {
        param($ModelRunPath, $ConfigPath, $CaseQuality, $ComsolBinPath, $CaseRuntimeRoot, $CaseOutputRoot)
        & $ModelRunPath `
            -ConfigPath $ConfigPath `
            -Quality $CaseQuality `
            -ComsolBin $ComsolBinPath `
            -RuntimeRoot $CaseRuntimeRoot `
            -OutputRoot $CaseOutputRoot `
            -SkipMatlabPostprocess
    }
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
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Set-CaseConfigValues {
    param(
        [Parameter(Mandatory = $true)][object]$Config,
        [Parameter(Mandatory = $true)][object]$Material,
        [Parameter(Mandatory = $true)][ValidateSet("timbre", "trend")][string]$RequestedRole,
        [Parameter(Mandatory = $true)][object]$SolvePlan,
        [Parameter(Mandatory = $true)][string]$PublicRequestedQuality,
        [double]$LFreeCm = 20,
        [double]$WidthCm = 3,
        [double]$ThicknessMm = 2,
        [double]$X0Ratio = 0.8,
        [double]$ImpulseNs = 0.04
    )

    Set-ObjectValue -Object $Config.geometry -Name "L_free" -Value (ConvertTo-MeterStringFromCm -ValueCm $LFreeCm)
    Set-ObjectValue -Object $Config.geometry -Name "b" -Value (ConvertTo-MeterStringFromCm -ValueCm $WidthCm)
    Set-ObjectValue -Object $Config.geometry -Name "h" -Value (ConvertTo-MeterStringFromMm -ValueMm $ThicknessMm)

    Set-ObjectValue -Object $Config.material -Name "rho" -Value $Material.rho
    Set-ObjectValue -Object $Config.material -Name "E" -Value $Material.E
    Set-ObjectValue -Object $Config.material -Name "nu" -Value $Material.nu

    Set-ObjectValue -Object $Config.excitation -Name "x0" -Value ("{0:0.########}*L_free" -f $X0Ratio)
    Set-ObjectValue -Object $Config.excitation -Name "J" -Value ("{0:0.########}[N*s]" -f $ImpulseNs)
    Set-ObjectValue -Object $Config.excitation -Name "tau_imp" -Value "2e-3[s]"
    Set-ObjectValue -Object $Config.excitation -Name "pulse_shape" -Value "half_sine"

    Set-ObjectValue -Object $Config.acoustics -Name "mic_x" -Value "L_free/2"
    Set-ObjectValue -Object $Config.acoustics -Name "mic_y" -Value "0[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "mic_z" -Value "0.02[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "mic_offset_from_surface_m" -Value "0.02[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "radiation_source_x" -Value "L_free/2"
    Set-ObjectValue -Object $Config.acoustics -Name "radiation_source_y" -Value "0[m]"
    Set-ObjectValue -Object $Config.acoustics -Name "radiation_source_z" -Value "0[m]"
    $airRadiusM = Get-RequestedAirRadiusMeters -LFreeCm $LFreeCm -WidthCm $WidthCm -ThicknessMm $ThicknessMm
    Set-ObjectValue -Object $Config.acoustics -Name "air_radius" -Value (ConvertTo-MeterString -ValueM $airRadiusM)

    $studies = Get-OrCreateNoteObject -Object $Config -Name "studies"
    $mesh = Get-OrCreateNoteObject -Object $Config -Name "mesh"
    $execution = Get-OrCreateNoteObject -Object $Config -Name "execution"

    Set-ObjectValue -Object $studies -Name "time_end" -Value ([string]$SolvePlan.time_end)
    Set-ObjectValue -Object $studies -Name "time_step" -Value ([string]$SolvePlan.time_step)
    Set-ObjectValue -Object $studies -Name "mode_points" -Value ([int]$SolvePlan.mode_points)
    Set-ObjectValue -Object $mesh -Name "numelem" -Value ([int]$SolvePlan.mesh_numelem)

    Set-ObjectValue -Object $execution -Name "requested_role" -Value $RequestedRole
    Set-ObjectValue -Object $execution -Name "requested_output_quality" -Value ([string]$SolvePlan.display_quality)
    Set-ObjectValue -Object $execution -Name "requested_output_quality_request" -Value $PublicRequestedQuality
    Set-ObjectValue -Object $execution -Name "requested_output_internal_profile" -Value ([string]$SolvePlan.profile_label)
    Set-ObjectValue -Object $execution -Name "modal_exports_skipped" -Value ([bool]$SolvePlan.modal_exports_skipped)
}

function New-RequestedCase {
    param(
        [Parameter(Mandatory = $true)][object]$BaseConfig,
        [Parameter(Mandatory = $true)][object]$Material,
        [Parameter(Mandatory = $true)][string]$CaseId,
        [Parameter(Mandatory = $true)][string]$Group,
        [Parameter(Mandatory = $true)][string]$PrimaryVariable,
        [Parameter(Mandatory = $true)][ValidateSet("timbre", "trend")][string]$RequestedRole,
        [Parameter(Mandatory = $true)][object]$SolvePlan,
        [Parameter(Mandatory = $true)][string]$PublicRequestedQuality,
        [Parameter(Mandatory = $true)][double]$Value,
        [Parameter(Mandatory = $true)][string]$ValueUnit,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [double]$LFreeCm = 20,
        [double]$WidthCm = 3,
        [double]$ThicknessMm = 2,
        [double]$X0Ratio = 0.8,
        [double]$ImpulseNs = 0.04
    )

    $config = Copy-JsonObject -Value $BaseConfig
    $airRadiusM = Get-RequestedAirRadiusMeters -LFreeCm $LFreeCm -WidthCm $WidthCm -ThicknessMm $ThicknessMm
    Set-CaseConfigValues `
        -Config $config `
        -Material $Material `
        -RequestedRole $RequestedRole `
        -SolvePlan $SolvePlan `
        -PublicRequestedQuality $PublicRequestedQuality `
        -LFreeCm $LFreeCm `
        -WidthCm $WidthCm `
        -ThicknessMm $ThicknessMm `
        -X0Ratio $X0Ratio `
        -ImpulseNs $ImpulseNs
    Write-JsonUtf8NoBomFile -Path $ConfigPath -Data $config

    return [ordered]@{
        case_id = $CaseId
        group = $Group
        requested_role = $RequestedRole
        public_requested_quality = $PublicRequestedQuality
        effective_quality = [string]$SolvePlan.display_quality
        effective_model_quality = [string]$SolvePlan.model_quality
        internal_profile_label = [string]$SolvePlan.profile_label
        modal_exports_skipped = [bool]$SolvePlan.modal_exports_skipped
        material_key = $Material.key
        material_name = $Material.name
        primary_variable = $PrimaryVariable
        value = $Value
        value_unit = $ValueUnit
        L_free_cm = $LFreeCm
        b_cm = $WidthCm
        h_mm = $ThicknessMm
        x0_ratio = $X0Ratio
        J_Ns = $ImpulseNs
        mic_offset_cm = 2
        air_radius_m = [Math]::Round($airRadiusM, 6)
        air_radius = (ConvertTo-MeterString -ValueM $airRadiusM)
        output_root = $OutputRoot
        config_path = $ConfigPath
        mph_path = (Join-Path $OutputRoot "mph\linear_acoustic_field_3d_air.mph")
        frequencies_csv = (Join-Path $OutputRoot "data\frequencies.csv")
        structure_probe_timeseries_csv = (Join-Path $OutputRoot "data\structure_probe_timeseries.csv")
        mic_pressure_timeseries_csv = (Join-Path $OutputRoot "data\mic_pressure_timeseries.csv")
        impact_force_timeseries_csv = (Join-Path $OutputRoot "data\impact_force_timeseries.csv")
        mode_shapes_csv = (Join-Path $OutputRoot "data\mode_shapes.csv")
        matlab_manifest_path = (Join-Path $OutputRoot "logs\linear_acoustic_field_3d_air_matlab_manifest.json")
    }
}

if ([string]::IsNullOrWhiteSpace($StudyId)) {
    $StudyId = "requested_3d_air_${Quality}_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}

$studyRoot = Join-Path $repoRoot "outputs\linear\requested_3d_air\$StudyId"
$configsDir = Join-Path $studyRoot "configs"
$casesRoot = Join-Path $studyRoot "cases"
$tablesDir = Join-Path $studyRoot "tables"
$figuresDir = Join-Path $studyRoot "figures"
$logsDir = Join-Path $studyRoot "logs"
New-Item -ItemType Directory -Path $studyRoot, $configsDir, $casesRoot, $tablesDir, $figuresDir, $logsDir -Force | Out-Null

$materials = @(
    [pscustomobject]@{ key = "steel"; name = "steel_ruler"; rho = "7930[kg/m^3]"; E = "193e9[Pa]"; nu = "0.29"; note = "baseline steel ruler" },
    [pscustomobject]@{ key = "pvc"; name = "pvc"; rho = "1380[kg/m^3]"; E = "3.0e9[Pa]"; nu = "0.38"; note = "engineering approximation" },
    [pscustomobject]@{ key = "xuefu_board"; name = "xuefu_board"; rho = "700[kg/m^3]"; E = "0.7e9[Pa]"; nu = "0.35"; note = "PVC foam board engineering approximation" },
    [pscustomobject]@{ key = "acrylic"; name = "acrylic"; rho = "1180[kg/m^3]"; E = "3.2e9[Pa]"; nu = "0.35"; note = "PMMA engineering approximation" },
    [pscustomobject]@{ key = "satinwood"; name = "satinwood"; rho = "650[kg/m^3]"; E = "10e9[Pa]"; nu = "0.35"; note = "orthotropy simplified to isotropic approximation" }
)
$steel = @($materials | Where-Object { $_.key -eq "steel" })[0]

$baseConfigPath = Join-Path $repoRoot "models\linear\acoustic_field_3d_air\config\params.json"
$baseConfig = Read-JsonFile -Path $baseConfigPath
$cases = New-Object System.Collections.Generic.List[object]
$timbreSolvePlan = Get-RequestedSolvePlan -RequestedRole "timbre" -RequestedQuality $Quality
$trendSolvePlan = Get-RequestedSolvePlan -RequestedRole "trend" -RequestedQuality $Quality

foreach ($material in $materials) {
    $caseId = "material_$($material.key)"
    $caseOutputRoot = Join-Path $casesRoot ("timbre_material\$caseId")
    $caseConfigPath = Join-Path $configsDir ($caseId + ".json")
    $case = New-RequestedCase `
        -BaseConfig $baseConfig -Material $material `
        -CaseId $caseId -Group "timbre" -PrimaryVariable "material" `
        -RequestedRole "timbre" -SolvePlan $timbreSolvePlan -PublicRequestedQuality $Quality `
        -Value 0 -ValueUnit "category" `
        -ConfigPath $caseConfigPath -OutputRoot $caseOutputRoot `
        -LFreeCm 20 -WidthCm 3 -ThicknessMm 2 -X0Ratio 0.8 -ImpulseNs 0.04
    $case.material_value = $material.key
    $cases.Add([pscustomobject]$case) | Out-Null
}

foreach ($valueCm in $LFreeValuesCm) {
    $caseId = "L_free_{0}cm" -f (ConvertTo-CaseToken -Value $valueCm)
    $case = New-RequestedCase `
        -BaseConfig $baseConfig -Material $steel `
        -CaseId $caseId -Group "steel_scan" -PrimaryVariable "L_free" `
        -RequestedRole "trend" -SolvePlan $trendSolvePlan -PublicRequestedQuality $Quality `
        -Value $valueCm -ValueUnit "cm" `
        -ConfigPath (Join-Path $configsDir ($caseId + ".json")) `
        -OutputRoot (Join-Path $casesRoot ("steel_scan\L_free\$caseId")) `
        -LFreeCm $valueCm -WidthCm 3 -ThicknessMm 2 -X0Ratio 0.8 -ImpulseNs 0.04
    $cases.Add([pscustomobject]$case) | Out-Null
}

foreach ($valueCm in $WidthValuesCm) {
    $caseId = "b_{0}cm" -f (ConvertTo-CaseToken -Value $valueCm)
    $case = New-RequestedCase `
        -BaseConfig $baseConfig -Material $steel `
        -CaseId $caseId -Group "steel_scan" -PrimaryVariable "b" `
        -RequestedRole "trend" -SolvePlan $trendSolvePlan -PublicRequestedQuality $Quality `
        -Value $valueCm -ValueUnit "cm" `
        -ConfigPath (Join-Path $configsDir ($caseId + ".json")) `
        -OutputRoot (Join-Path $casesRoot ("steel_scan\b\$caseId")) `
        -LFreeCm 20 -WidthCm $valueCm -ThicknessMm 2 -X0Ratio 0.8 -ImpulseNs 0.04
    $cases.Add([pscustomobject]$case) | Out-Null
}

foreach ($valueMm in $ThicknessValuesMm) {
    $caseId = "h_{0}mm" -f (ConvertTo-CaseToken -Value $valueMm)
    $case = New-RequestedCase `
        -BaseConfig $baseConfig -Material $steel `
        -CaseId $caseId -Group "steel_scan" -PrimaryVariable "h" `
        -RequestedRole "trend" -SolvePlan $trendSolvePlan -PublicRequestedQuality $Quality `
        -Value $valueMm -ValueUnit "mm" `
        -ConfigPath (Join-Path $configsDir ($caseId + ".json")) `
        -OutputRoot (Join-Path $casesRoot ("steel_scan\h\$caseId")) `
        -LFreeCm 20 -WidthCm 3 -ThicknessMm $valueMm -X0Ratio 0.8 -ImpulseNs 0.04
    $cases.Add([pscustomobject]$case) | Out-Null
}

foreach ($ratio in $X0Ratios) {
    $caseId = "x0_ratio_{0}" -f (ConvertTo-CaseToken -Value $ratio)
    $case = New-RequestedCase `
        -BaseConfig $baseConfig -Material $steel `
        -CaseId $caseId -Group "steel_scan" -PrimaryVariable "x0_ratio" `
        -RequestedRole "trend" -SolvePlan $trendSolvePlan -PublicRequestedQuality $Quality `
        -Value $ratio -ValueUnit "ratio" `
        -ConfigPath (Join-Path $configsDir ($caseId + ".json")) `
        -OutputRoot (Join-Path $casesRoot ("steel_scan\x0_ratio\$caseId")) `
        -LFreeCm 20 -WidthCm 3 -ThicknessMm 2 -X0Ratio $ratio -ImpulseNs 0.04
    $cases.Add([pscustomobject]$case) | Out-Null
}

foreach ($impulse in $ImpulseValuesNs) {
    $caseId = "J_{0}Ns" -f (ConvertTo-CaseToken -Value $impulse)
    $case = New-RequestedCase `
        -BaseConfig $baseConfig -Material $steel `
        -CaseId $caseId -Group "steel_scan" -PrimaryVariable "J" `
        -RequestedRole "trend" -SolvePlan $trendSolvePlan -PublicRequestedQuality $Quality `
        -Value $impulse -ValueUnit "N*s" `
        -ConfigPath (Join-Path $configsDir ($caseId + ".json")) `
        -OutputRoot (Join-Path $casesRoot ("steel_scan\J\$caseId")) `
        -LFreeCm 20 -WidthCm 3 -ThicknessMm 2 -X0Ratio 0.8 -ImpulseNs $impulse
    $cases.Add([pscustomobject]$case) | Out-Null
}

$studyManifestPath = Join-Path $studyRoot "study_manifest.json"
$manifest = [ordered]@{
    study_id = $StudyId
    model_id = "linear_acoustic_field_3d_air"
    output_root = $studyRoot
    quality = $Quality
    max_parallel_cases = $MaxParallelCases
    solve_strategy = "role_layered_requested_outputs"
    truth_policy = "Every plotted point must come from a completed COMSOL 3D air-domain case. Missing cases are marked missing; no interpolation or synthetic spectra."
    material_property_note = "Non-steel material properties are engineering approximations and should be replaced with measured values when available."
    requested_outputs = @(
        "Timbre: steel/PVC/xuefu_board/acrylic/satinwood microphone spectra",
        "Timbre: per-material dominant received-frequency duration panels",
        "Timbre: steel dominant received-frequency duration",
        "Pitch: steel scans at microphone 2 cm for free length/width/thickness/impact position/impulse",
        "Sound pressure: steel scans at microphone 2 cm for free length/width/thickness/impact position/impulse",
        "Impulse force-time curves"
    )
    role_profiles = [ordered]@{
        timbre = $timbreSolvePlan
        trend = $trendSolvePlan
    }
    fixed_baseline = [ordered]@{
        L_free_cm = 20
        b_cm = 3
        h_mm = 2
        x0_ratio = 0.8
        J_Ns = 0.04
        mic_position = "(L_free/2, 0, 0.02[m])"
        mic_offset_from_ruler = "2 cm"
        air_radius_policy = "per case: max(0.12 m, ruler-corner radius from sphere center + 0.02 m clearance)"
    }
    materials = @($materials)
    scan_values = [ordered]@{
        L_free_cm = $LFreeValuesCm
        b_cm = $WidthValuesCm
        h_mm = $ThicknessValuesMm
        x0_ratio = $X0Ratios
        J_Ns = $ImpulseValuesNs
    }
    cases = @($cases.ToArray())
}
Write-JsonUtf8NoBomFile -Path $studyManifestPath -Data $manifest

if ($PrepareOnly) {
    Write-Host "Prepared requested 3D air output manifest:"
    Write-Host $studyManifestPath
    return
}

$modelRun = Join-Path $repoRoot "models\linear\acoustic_field_3d_air\run.ps1"
$runtimeBase = if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
    Join-Path $repoRoot "runtime\comsol\linear\requested_3d_air\$StudyId"
} else {
    $RuntimeRoot
}

foreach ($case in @($cases.ToArray())) {
    if ($SkipExisting -and (Test-RequestedCaseOutputsComplete -Case $case)) {
        Write-Host "==> skip existing case: $($case.case_id)"
        continue
    }
}

$casesToRun = @(
    @($cases.ToArray()) | Where-Object {
        -not ($SkipExisting -and (Test-RequestedCaseOutputsComplete -Case $_))
    }
)

if ($MaxParallelCases -le 1 -or $casesToRun.Count -le 1) {
    foreach ($case in $casesToRun) {
        Invoke-RequestedCaseBuild -Case $case -ModelRunPath $modelRun -ComsolBinPath $ComsolBin -RuntimeBasePath $runtimeBase
    }
}
else {
    $pendingCases = [System.Collections.Queue]::new()
    foreach ($case in $casesToRun) {
        $pendingCases.Enqueue($case)
    }

    $activeJobs = New-Object System.Collections.Generic.List[object]
    while ($pendingCases.Count -gt 0 -or $activeJobs.Count -gt 0) {
        while ($activeJobs.Count -lt $MaxParallelCases -and $pendingCases.Count -gt 0) {
            $case = $pendingCases.Dequeue()
            Write-Host ("==> queue requested 3D air case: {0} [{1} -> {2}]" -f `
                $case.case_id, $case.requested_role, $case.effective_model_quality)
            $job = Start-RequestedCaseBuildJob -Case $case -ModelRunPath $modelRun -ComsolBinPath $ComsolBin -RuntimeBasePath $runtimeBase
            $activeJobs.Add($job) | Out-Null
        }

        $completedJob = Wait-Job -Job @($activeJobs.ToArray()) -Any -Timeout 30
        if ($null -eq $completedJob) {
            continue
        }

        foreach ($job in @($completedJob)) {
            try {
                Receive-Job -Job $job -ErrorAction Stop | ForEach-Object { Write-Host $_ }
                Write-Host "==> completed requested 3D air case: $($job.Name)"
            }
            finally {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                [void]$activeJobs.Remove($job)
            }
        }
    }
}

if (-not $SkipPlots) {
    python (Join-Path $repoRoot "scripts\plot_requested_outputs_3d_air.py") --study-root $studyRoot
}

Write-Host "==> requested 3D air output run complete:"
Write-Host $studyRoot
