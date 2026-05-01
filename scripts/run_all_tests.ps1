[CmdletBinding()]
param(
    [string]$ComsolBin = $env:COMSOL_BIN,
    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "full",
    [switch]$IncludeParamStudySmoke,
    [switch]$SkipMatlabPhase,
    [switch]$ValidateExistingStudies
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $PSScriptRoot "comsol_common.ps1")

$ComsolBin = Resolve-ComsolBin -InputPath $ComsolBin

function Read-JsonUtf8 {
    param([string]$Path)
    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-MatlabHandoffState {
    param([string]$StatusPath)

    if ([string]::IsNullOrWhiteSpace($StatusPath) -or -not (Test-Path -LiteralPath $StatusPath)) {
        return ""
    }

    try {
        $status = Read-JsonUtf8 -Path $StatusPath
        if ($null -eq $status -or -not $status.PSObject.Properties["status"]) {
            return ""
        }
        return [string]$status.status
    }
    catch {
        return ""
    }
}

function Assert-FileExists {
    param(
        [string]$Path,
        [string]$Message
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Message`nMissing path: $Path"
    }
}

function Assert-PathMissing {
    param(
        [string]$Path,
        [string]$Message
    )

    if (Test-Path -LiteralPath $Path) {
        throw "$Message`nUnexpected path: $Path"
    }
}

function Assert-NonEmptyField {
    param(
        [object]$Object,
        [string]$FieldName,
        [string]$Path
    )

    $prop = $Object.PSObject.Properties[$FieldName]
    if ($null -eq $prop) {
        throw "Missing required field '$FieldName' in $Path"
    }
    $value = $prop.Value
    if ($null -eq $value) {
        throw "Empty required field '$FieldName' in $Path"
    }
    if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
        throw "Empty required field '$FieldName' in $Path"
    }
}

function Assert-PositiveField {
    param(
        [object]$Summary,
        [string]$FieldName,
        [string]$Path
    )

    $actual = [double]$Summary.$FieldName
    if ([double]::IsNaN($actual) -or [double]::IsInfinity($actual) -or $actual -le 0) {
        throw "Expected positive numeric field '$FieldName' in $Path, got '$($Summary.$FieldName)'."
    }
}

function Normalize-PathForCompare {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    $candidate = $Path.Replace('/', '\')
    return [System.IO.Path]::GetFullPath($candidate).TrimEnd('\')
}

function Invoke-TestRun {
    param(
        [string]$ScriptPath,
        [string[]]$ArgumentList
    )

    $cmdArgs = @("-ExecutionPolicy", "Bypass", "-File", $ScriptPath) + $ArgumentList
    & powershell @cmdArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Test command failed: powershell $($cmdArgs -join ' ')"
    }
}

function Assert-ModelArtifacts {
    param(
        [string]$BaseDir,
        [string[]]$ExpectedFiles
    )

    foreach ($relativePath in $ExpectedFiles) {
        Assert-FileExists -Path (Join-Path $BaseDir $relativePath) -Message "Missing expected artifact."
    }
}

function Assert-DirectoryFileCount {
    param(
        [string]$Directory,
        [string]$Filter,
        [int]$ExpectedCount,
        [string]$Message
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        throw "$Message`nMissing directory: $Directory"
    }

    $actualCount = @(Get-ChildItem -LiteralPath $Directory -File -Filter $Filter -ErrorAction SilentlyContinue).Count
    if ($actualCount -ne $ExpectedCount) {
        throw "$Message`nExpected $ExpectedCount file(s) matching '$Filter' in $Directory, found $actualCount."
    }
}

function Assert-DirectoryFileCountRange {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [string]$Filter = "*",
        [Parameter(Mandatory = $true)][int]$MinimumCount,
        [Parameter(Mandatory = $true)][int]$MaximumCount,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-FileExists -Path $Directory -Message "Missing directory: $Directory"
    $actual = @(Get-ChildItem -LiteralPath $Directory -File -Filter $Filter -ErrorAction Stop).Count
    if ($actual -lt $MinimumCount -or $actual -gt $MaximumCount) {
        throw "$Message Actual count: $actual. Expected range: [$MinimumCount, $MaximumCount]. Directory: $Directory"
    }
}

function Read-NumericCsv {
    param([Parameter(Mandatory = $true)][string]$Path)

    $lines = Get-Content -LiteralPath $Path -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $header = $null
    $dataLines = @()
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith('%')) {
            $candidate = $trimmed.Substring(1).Trim()
            if ($candidate.Contains(',') -and -not ($candidate.StartsWith('Model,') -or $candidate.StartsWith('Version,') -or $candidate.StartsWith('Date,') -or $candidate.StartsWith('Table,'))) {
                $header = $candidate
            }
            continue
        }
        $dataLines += $trimmed
    }

    if ($null -eq $header) {
        return Import-Csv -LiteralPath $Path
    }

    $names = $header.Split(',') | ForEach-Object { $_.Trim() }
    $rows = @()
    foreach ($row in $dataLines) {
        $parts = $row.Split(',') | ForEach-Object { $_.Trim() }
        $obj = [ordered]@{}
        for ($i = 0; $i -lt $names.Count; $i++) {
            $value = if ($i -lt $parts.Count) { $parts[$i] } else { "" }
            $obj[$names[$i]] = $value
        }
        $rows += [pscustomobject]$obj
    }
    return $rows
}

function Assert-ValidAcousticBuildOnlyCsvBundle {
    param([Parameter(Mandatory = $true)][string]$BaseDir)

    $freqPath = Join-Path $BaseDir "data\frequencies.csv"
    $modePath = Join-Path $BaseDir "data\mode_shapes.csv"
    $micPath = Join-Path $BaseDir "data\mic_pressure_timeseries.csv"

    foreach ($path in @($freqPath, $modePath, $micPath)) {
        Assert-FileExists -Path $path -Message "Missing required acoustic CSV bundle file."
    }

    $freqRows = @(Read-NumericCsv -Path $freqPath)
    if ($freqRows.Count -lt 1) {
        throw "frequencies.csv must contain at least one numeric row: $freqPath"
    }
    foreach ($row in $freqRows) {
        $freq = [double]$row.freq_hz
        if ([double]::IsNaN($freq) -or [double]::IsInfinity($freq) -or $freq -le 0) {
            throw "frequencies.csv contains invalid freq_hz: $freqPath"
        }
    }
    for ($i = 1; $i -lt $freqRows.Count; $i++) {
        if ([double]$freqRows[$i].freq_hz -le [double]$freqRows[$i - 1].freq_hz) {
            throw "frequencies.csv must be strictly increasing: $freqPath"
        }
    }

    $modeRows = @(Read-NumericCsv -Path $modePath)
    if ($modeRows.Count -lt 2) {
        throw "mode_shapes.csv must contain at least two rows: $modePath"
    }
    foreach ($row in $modeRows) {
        $x = [double]$row.x_m
        if ([double]::IsNaN($x) -or [double]::IsInfinity($x)) {
            throw "mode_shapes.csv contains invalid x_m: $modePath"
        }
        foreach ($prop in $row.PSObject.Properties.Name | Where-Object { $_ -like 'w_mode*' }) {
            $value = [double]$row.$prop
            if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) {
                throw "mode_shapes.csv contains invalid modal value '$prop': $modePath"
            }
        }
    }

    $micRows = @(Read-NumericCsv -Path $micPath)
    if ($micRows.Count -lt 2) {
        throw "mic_pressure_timeseries.csv must contain at least two rows: $micPath"
    }
    $maxMicAbs = 0.0
    foreach ($row in $micRows) {
        $t = [double]$row.t_s
        $p = [double]$row.p_pa
        if ([double]::IsNaN($t) -or [double]::IsInfinity($t) -or [double]::IsNaN($p) -or [double]::IsInfinity($p)) {
            throw "mic_pressure_timeseries.csv contains invalid numeric data: $micPath"
        }
        $maxMicAbs = [Math]::Max($maxMicAbs, [Math]::Abs($p))
    }
    if ($maxMicAbs -le 0) {
        throw "mic_pressure_timeseries.csv must not be all zero: $micPath"
    }
}

function Assert-ValidImpactBuildOnlyCsvBundle {
    param([Parameter(Mandatory = $true)][string]$BaseDir)

    $freqPath = Join-Path $BaseDir "data\frequencies.csv"
    $modePath = Join-Path $BaseDir "data\mode_shapes.csv"
    $tipPath = Join-Path $BaseDir "data\tip_timeseries.csv"

    foreach ($path in @($freqPath, $modePath, $tipPath)) {
        Assert-FileExists -Path $path -Message "Missing required impact-response CSV bundle file."
    }

    $freqRows = @(Read-NumericCsv -Path $freqPath)
    if ($freqRows.Count -lt 1) {
        throw "frequencies.csv must contain at least one numeric row: $freqPath"
    }
    for ($i = 0; $i -lt $freqRows.Count; $i++) {
        $freq = [double]$freqRows[$i].freq_hz
        if ([double]::IsNaN($freq) -or [double]::IsInfinity($freq) -or $freq -le 0) {
            throw "frequencies.csv contains invalid freq_hz: $freqPath"
        }
        if ($i -gt 0 -and $freq -le [double]$freqRows[$i - 1].freq_hz) {
            throw "frequencies.csv must be strictly increasing: $freqPath"
        }
    }

    $modeRows = @(Read-NumericCsv -Path $modePath)
    if ($modeRows.Count -lt 2) {
        throw "mode_shapes.csv must contain at least two rows: $modePath"
    }
    $modeMax = @{}
    foreach ($row in $modeRows) {
        $x = [double]$row.x_m
        $s = [double]$row.x_over_L
        if ([double]::IsNaN($x) -or [double]::IsInfinity($x) -or [double]::IsNaN($s) -or [double]::IsInfinity($s)) {
            throw "mode_shapes.csv contains invalid coordinate data: $modePath"
        }
        foreach ($prop in $row.PSObject.Properties.Name | Where-Object { $_ -like 'w_mode*' }) {
            $value = [double]$row.$prop
            if ([double]::IsNaN($value) -or [double]::IsInfinity($value)) {
                throw "mode_shapes.csv contains invalid modal value '$prop': $modePath"
            }
            if (-not $modeMax.ContainsKey($prop)) {
                $modeMax[$prop] = 0.0
            }
            $modeMax[$prop] = [Math]::Max($modeMax[$prop], [Math]::Abs($value))
        }
    }
    foreach ($prop in $modeMax.Keys) {
        if ($modeMax[$prop] -le 0) {
            throw "mode_shapes.csv modal column '$prop' must not be all zero: $modePath"
        }
    }

    $tipRows = @(Read-NumericCsv -Path $tipPath)
    if ($tipRows.Count -lt 2) {
        throw "tip_timeseries.csv must contain at least two rows: $tipPath"
    }
    $maxTipAbs = 0.0
    foreach ($row in $tipRows) {
        $t = [double]$row.t_s
        $w = [double]$row.w_m
        if ([double]::IsNaN($t) -or [double]::IsInfinity($t) -or [double]::IsNaN($w) -or [double]::IsInfinity($w)) {
            throw "tip_timeseries.csv contains invalid numeric data: $tipPath"
        }
        $maxTipAbs = [Math]::Max($maxTipAbs, [Math]::Abs($w))
    }
    if ($maxTipAbs -le 0) {
        throw "tip_timeseries.csv must not be all zero: $tipPath"
    }
}

function Assert-StructuralReferenceAgreement {
    param(
        [Parameter(Mandatory = $true)][string]$ImpactBaseDir,
        [Parameter(Mandatory = $true)][string]$AcousticBaseDir,
        [double]$MaxRelativeError = 0.20
    )

    $impactFreqRows = @(Read-NumericCsv -Path (Join-Path $ImpactBaseDir "data\frequencies.csv"))
    $acousticFreqRows = @(Read-NumericCsv -Path (Join-Path $AcousticBaseDir "data\frequencies.csv"))
    $compareCount = [Math]::Min([Math]::Min($impactFreqRows.Count, $acousticFreqRows.Count), 3)
    if ($compareCount -lt 3) {
        throw "Need at least three structural frequencies to compare impact_response and acoustic_field."
    }

    for ($i = 0; $i -lt $compareCount; $i++) {
        $impactFreq = [double]$impactFreqRows[$i].freq_hz
        $acousticFreq = [double]$acousticFreqRows[$i].freq_hz
        $den = [Math]::Max([Math]::Abs($impactFreq), 1e-12)
        $relErr = [Math]::Abs($acousticFreq - $impactFreq) / $den
        if ($relErr -gt $MaxRelativeError) {
            throw ("acoustic_field structural frequency {0} deviates too far from impact_response: impact={1}, acoustic={2}, rel_err={3}" -f ($i + 1), $impactFreq, $acousticFreq, $relErr)
        }
    }
}

function Assert-JsonFieldMissing {
    param(
        [object]$Object,
        [string]$FieldName,
        [string]$Path
    )

    if ($Object.PSObject.Properties[$FieldName]) {
        throw "Deprecated field '$FieldName' should not exist in $Path."
    }
}

function Assert-BuildOnlyLinearContract {
    param(
        [string]$BaseDir,
        [string]$ModelMphRelativePath,
        [string]$BuildLogRelativePath,
        [string]$MatlabManifestRelativePath,
        [string]$MatlabStatusRelativePath,
        [int]$ExpectedDataFileCount,
        [Nullable[int]]$MinimumDataFileCount = $null,
        [Nullable[int]]$MaximumDataFileCount = $null
    )

    Assert-ModelArtifacts -BaseDir $BaseDir -ExpectedFiles @(
        "params_resolved.json",
        $ModelMphRelativePath,
        $BuildLogRelativePath,
        $MatlabManifestRelativePath,
        $MatlabStatusRelativePath
    )

    foreach ($path in @(
        (Join-Path $BaseDir "summary.json"),
        (Join-Path $BaseDir "summary.txt"),
        (Join-Path $BaseDir "run_manifest.txt")
    )) {
        Assert-PathMissing -Path $path -Message "Build-only linear run should stop before MATLAB metadata export."
    }

    if ($MinimumDataFileCount -ne $null -and $MaximumDataFileCount -ne $null) {
        Assert-DirectoryFileCountRange -Directory (Join-Path $BaseDir "data") -Filter "*" -MinimumCount $MinimumDataFileCount -MaximumCount $MaximumDataFileCount -Message "Build-only linear run should export Java raw CSV data within the allowed range."
    } else {
        Assert-DirectoryFileCount -Directory (Join-Path $BaseDir "data") -Filter "*" -ExpectedCount $ExpectedDataFileCount -Message "Build-only linear run should export only Java raw CSV data."
    }
    Assert-DirectoryFileCount -Directory (Join-Path $BaseDir "figures") -Filter "*.png" -ExpectedCount 0 -Message "Build-only linear run should not export MATLAB figures yet."
}

function Assert-AcousticParamStudySummaryArtifacts {
    param(
        [string]$StudyRoot,
        [string]$StudySelection
    )

    Assert-FileExists -Path (Join-Path $StudyRoot "tables\all_cases.csv") -Message "Missing parameter-study long table."

    switch ($StudySelection) {
        "timbre" {
            Assert-FileExists -Path (Join-Path $StudyRoot "figures\linear_timbre_overview.png") -Message "Missing timbre overview figure."
            Assert-FileExists -Path (Join-Path $StudyRoot "tables\timbre_summary.csv") -Message "Missing timbre summary table."
        }
        "amplitude" {
            Assert-FileExists -Path (Join-Path $StudyRoot "figures\linear_amplitude_overview.png") -Message "Missing amplitude overview figure."
            Assert-FileExists -Path (Join-Path $StudyRoot "tables\amplitude_summary.csv") -Message "Missing amplitude summary table."
        }
        "frequency" {
            Assert-FileExists -Path (Join-Path $StudyRoot "figures\linear_frequency_overview.png") -Message "Missing frequency overview figure."
            Assert-FileExists -Path (Join-Path $StudyRoot "tables\frequency_summary.csv") -Message "Missing frequency summary table."
        }
        "all" {
            Assert-FileExists -Path (Join-Path $StudyRoot "figures\linear_timbre_overview.png") -Message "Missing timbre overview figure."
            Assert-FileExists -Path (Join-Path $StudyRoot "tables\timbre_summary.csv") -Message "Missing timbre summary table."
            Assert-FileExists -Path (Join-Path $StudyRoot "figures\linear_amplitude_overview.png") -Message "Missing amplitude overview figure."
            Assert-FileExists -Path (Join-Path $StudyRoot "tables\amplitude_summary.csv") -Message "Missing amplitude summary table."
            Assert-FileExists -Path (Join-Path $StudyRoot "figures\linear_frequency_overview.png") -Message "Missing frequency overview figure."
            Assert-FileExists -Path (Join-Path $StudyRoot "tables\frequency_summary.csv") -Message "Missing frequency summary table."
        }
        default {
            throw "Unsupported parameter-study selection '$StudySelection' in completed study: $StudyRoot"
        }
    }
}

function Assert-BuildOnlyAcousticParamStudyContract {
    param([string]$StudyRoot)

    Assert-FileExists -Path (Join-Path $StudyRoot "summary.json") -Message "Missing parameter-study summary."
    Assert-FileExists -Path (Join-Path $StudyRoot "run_manifest.txt") -Message "Missing parameter-study run manifest."
    Assert-FileExists -Path (Join-Path $StudyRoot "study_manifest.json") -Message "Missing parameter-study manifest."
    Assert-FileExists -Path (Join-Path $StudyRoot "logs\linear_acoustic_param_study_matlab_manifest.json") -Message "Missing parameter-study MATLAB handoff manifest."
    Assert-FileExists -Path (Join-Path $StudyRoot "logs\linear_acoustic_param_study_matlab_status.json") -Message "Missing parameter-study MATLAB handoff status."
    Assert-DirectoryFileCount -Directory (Join-Path $StudyRoot "figures") -Filter "*.png" -ExpectedCount 0 -Message "Build-only parameter study should not export summary figures yet."
    Assert-DirectoryFileCount -Directory (Join-Path $StudyRoot "tables") -Filter "*.csv" -ExpectedCount 0 -Message "Build-only parameter study should not export summary tables yet."
    Assert-PathMissing -Path (Join-Path $StudyRoot "data") -Message "Parameter-study root should not contain a data directory."

    $manifestPath = Join-Path $StudyRoot "study_manifest.json"
    $manifest = Read-JsonUtf8 -Path $manifestPath
    $cases = @($manifest.cases)
    if ($cases.Count -eq 0) {
        throw "Parameter-study manifest has no cases: $manifestPath"
    }

    foreach ($case in $cases) {
        $caseRoot = [string]$case.output_root
        if ([string]::IsNullOrWhiteSpace($caseRoot)) {
            throw "Parameter-study case is missing output_root in $manifestPath."
        }

        Assert-FileExists -Path (Join-Path $caseRoot "params_resolved.json") -Message "Missing parameter-study case params."
        Assert-FileExists -Path (Join-Path $caseRoot "mph\linear_acoustic_field.mph") -Message "Missing parameter-study case MPH."
        Assert-PathMissing -Path (Join-Path $caseRoot "qualities") -Message "Parameter-study case should be a flat canonical bundle."

        foreach ($path in @(
            (Join-Path $caseRoot "summary.json"),
            (Join-Path $caseRoot "summary.txt"),
            (Join-Path $caseRoot "run_manifest.txt")
        )) {
            Assert-PathMissing -Path $path -Message "Build-only parameter-study case should stop before MATLAB metadata export."
        }

        Assert-DirectoryFileCountRange -Directory (Join-Path $caseRoot "data") -Filter "*" -MinimumCount 3 -MaximumCount 4 -Message "Build-only parameter-study case should export Java raw CSV data, with tip_timeseries.csv allowed to be deferred to MATLAB."
        Assert-DirectoryFileCount -Directory (Join-Path $caseRoot "figures") -Filter "*.png" -ExpectedCount 0 -Message "Build-only parameter-study case should not export figures yet."
    }
}

function Assert-CompletedAcousticParamStudyContract {
    param([string]$StudyRoot)

    Assert-FileExists -Path (Join-Path $StudyRoot "summary.json") -Message "Missing parameter-study summary."
    Assert-FileExists -Path (Join-Path $StudyRoot "run_manifest.txt") -Message "Missing parameter-study run manifest."
    $manifestPath = Join-Path $StudyRoot "study_manifest.json"
    Assert-FileExists -Path $manifestPath -Message "Missing parameter-study manifest."
    Assert-PathMissing -Path (Join-Path $StudyRoot "data") -Message "Parameter-study root should not contain a data directory."

    $manifest = Read-JsonUtf8 -Path $manifestPath
    Assert-AcousticParamStudySummaryArtifacts -StudyRoot $StudyRoot -StudySelection ([string]$manifest.study_selection)

    $cases = @($manifest.cases)
    if ($cases.Count -eq 0) {
        throw "Parameter-study manifest has no cases: $manifestPath"
    }

    foreach ($case in $cases) {
        $caseRoot = [string]$case.output_root
        Assert-FileExists -Path (Join-Path $caseRoot "params_resolved.json") -Message "Missing parameter-study case params."
        Assert-FileExists -Path (Join-Path $caseRoot "summary.json") -Message "Missing parameter-study case summary."
        Assert-FileExists -Path (Join-Path $caseRoot "summary.txt") -Message "Missing parameter-study case summary text."
        Assert-FileExists -Path (Join-Path $caseRoot "run_manifest.txt") -Message "Missing parameter-study case run manifest."
        Assert-FileExists -Path (Join-Path $caseRoot "mph\linear_acoustic_field.mph") -Message "Missing parameter-study case MPH."
        Assert-PathMissing -Path (Join-Path $caseRoot "qualities") -Message "Parameter-study case should be a flat canonical bundle."
        Assert-DirectoryFileCount -Directory (Join-Path $caseRoot "data") -Filter "*" -ExpectedCount 6 -Message "Parameter-study case data/ should contain exactly six files."
        Assert-DirectoryFileCount -Directory (Join-Path $caseRoot "figures") -Filter "*.png" -ExpectedCount 11 -Message "Parameter-study case figures/ should contain exactly eleven PNG files."
    }
}

Write-Host "==> Running linear line shell phase"
Invoke-TestRun -ScriptPath (Join-Path $repoRoot "models\linear\run.ps1") -ArgumentList @("-Model", "ALL", "-Quality", $Quality, "-ComsolBin", $ComsolBin, "-SkipMatlabPostprocess")

if ($IncludeParamStudySmoke) {
    Write-Host "==> Running acoustic parameter-study shell phase"
    & (Join-Path $repoRoot "models\linear\acoustic_field\param_study.ps1") `
        -Study "all" `
        -Design "one_at_a_time" `
        -Quality $Quality `
        -ComsolBin $ComsolBin `
        -ImpulseValuesNs @(0.08, 0.10) `
        -LFreeValuesCm @(10) `
        -X0Ratios @(0.70) `
        -WidthValuesCm @(5) `
        -ThicknessValuesMm @(5) `
        -SkipMatlabPostprocess
}

Assert-BuildOnlyLinearContract -BaseDir (Join-Path $repoRoot "outputs\linear\base") -ModelMphRelativePath "mph\linear_base.mph" -BuildLogRelativePath "logs\linear_base.log" -MatlabManifestRelativePath "logs\linear_base_matlab_manifest.json" -MatlabStatusRelativePath "logs\linear_base_matlab_status.json" -ExpectedDataFileCount 3
Assert-BuildOnlyLinearContract -BaseDir (Join-Path $repoRoot "outputs\linear\impact_response") -ModelMphRelativePath "mph\linear_impact_response.mph" -BuildLogRelativePath "logs\linear_impact_response.log" -MatlabManifestRelativePath "logs\linear_impact_response_matlab_manifest.json" -MatlabStatusRelativePath "logs\linear_impact_response_matlab_status.json" -ExpectedDataFileCount 3
Assert-BuildOnlyLinearContract -BaseDir (Join-Path $repoRoot "outputs\linear\acoustic_field") -ModelMphRelativePath "mph\linear_acoustic_field.mph" -BuildLogRelativePath "logs\linear_acoustic_field.log" -MatlabManifestRelativePath "logs\linear_acoustic_field_matlab_manifest.json" -MatlabStatusRelativePath "logs\linear_acoustic_field_matlab_status.json" -ExpectedDataFileCount 3 -MinimumDataFileCount 3 -MaximumDataFileCount 4
Assert-ModelArtifacts -BaseDir (Join-Path $repoRoot "outputs\linear\app") -ExpectedFiles @(
    "params.json",
    "summary.json",
    "summary.txt",
    "run_manifest.txt",
    "data\README.txt",
    "figures\README.txt",
    "logs\README.txt",
    "mph\README.txt"
)

$acousticRoot = Join-Path $repoRoot "outputs\linear\acoustic_field"

foreach ($path in @(
    (Join-Path $acousticRoot "results"),
    (Join-Path $acousticRoot "tables"),
    (Join-Path $acousticRoot "artifacts"),
    (Join-Path $acousticRoot "structure_response"),
    (Join-Path $acousticRoot "mic_signals"),
    (Join-Path $acousticRoot "spectra"),
    (Join-Path $acousticRoot "pressure_field"),
    (Join-Path $acousticRoot "qualities"),
    (Join-Path $acousticRoot "latest.json")
)) {
    Assert-PathMissing -Path $path -Message "Acoustic root should only expose the canonical bundle."
}

Assert-PathMissing -Path (Join-Path $acousticRoot "summary.json") -Message "Build-only acoustic run should stop before MATLAB metadata export."
Assert-PathMissing -Path (Join-Path $acousticRoot "summary.txt") -Message "Build-only acoustic run should stop before MATLAB metadata export."
Assert-PathMissing -Path (Join-Path $acousticRoot "run_manifest.txt") -Message "Build-only acoustic run should stop before MATLAB metadata export."
Assert-DirectoryFileCountRange -Directory (Join-Path $acousticRoot "data") -Filter "*" -MinimumCount 3 -MaximumCount 4 -Message "Build-only acoustic run should export Java raw CSV data, with tip_timeseries.csv allowed to be deferred to MATLAB."
Assert-DirectoryFileCount -Directory (Join-Path $acousticRoot "figures") -Filter "*.png" -ExpectedCount 0 -Message "Build-only acoustic run should not export figures yet."
Assert-ValidImpactBuildOnlyCsvBundle -BaseDir (Join-Path $repoRoot "outputs\linear\impact_response")
Assert-ValidAcousticBuildOnlyCsvBundle -BaseDir $acousticRoot
Assert-StructuralReferenceAgreement -ImpactBaseDir (Join-Path $repoRoot "outputs\linear\impact_response") -AcousticBaseDir $acousticRoot

if ($IncludeParamStudySmoke) {
    $studiesRoot = Join-Path $repoRoot "outputs\linear\sweep"
    if (-not (Test-Path -LiteralPath $studiesRoot)) {
        throw "Missing parameter-study root after parameter-study shell phase: $studiesRoot"
    }

    $latestStudy = Get-ChildItem -LiteralPath $studiesRoot -Directory -Filter "study_*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latestStudy) {
        throw "Expected at least one parameter-study directory after parameter-study shell phase."
    }

    Assert-BuildOnlyAcousticParamStudyContract -StudyRoot $latestStudy.FullName
}

$activeStudiesRoot = Join-Path $repoRoot "outputs\linear\sweep"
if ($ValidateExistingStudies -and (Test-Path -LiteralPath $activeStudiesRoot)) {
    Get-ChildItem -LiteralPath $activeStudiesRoot -Directory -Filter "study_*" -ErrorAction SilentlyContinue | ForEach-Object {
        $state = Get-MatlabHandoffState -StatusPath (Join-Path $_.FullName "logs\linear_acoustic_param_study_matlab_status.json")
        if ($state -in @("pending", "running", "failed")) {
            Write-Host ("==> Skipping completed-study assertions for handoff state '{0}': {1}" -f $state, $_.FullName)
        }
        else {
            Assert-CompletedAcousticParamStudyContract -StudyRoot $_.FullName
        }
    }
}

if ($SkipMatlabPhase) {
    Write-Host "==> Shell-only test phase completed successfully."
    return
}

$testLogPath = Join-Path $repoRoot "outputs\test_logs\matlab_unit_tests.log"
$testManifestPath = Join-Path $repoRoot "outputs\test_logs\run_all_tests_matlab_manifest.json"
$testStatusPath = Join-Path $repoRoot "outputs\test_logs\run_all_tests_matlab_status.json"
New-CodexMatlabHandoffManifest `
    -ManifestPath $testManifestPath `
    -ProjectRoot $repoRoot `
    -EntryFunction "run_all_tests_from_manifest" `
    -OutputRoot (Join-Path $repoRoot "outputs\test_logs") `
    -ModelLine "repo" `
    -ModelId "run_all_tests" `
    -LogPath $testLogPath `
    -StatusPath $testStatusPath `
    -FunctionArgs @() `
    -BuildWallclockSeconds "0" `
    -SourceScript "scripts/run_all_tests.ps1" | Out-Null
Write-CodexMatlabStatusFile `
    -StatusPath $testStatusPath `
    -State "pending" `
    -ManifestPath $testManifestPath `
    -EntryFunction "run_all_tests_from_manifest" `
    -LogPath $testLogPath `
    -Message "Shell checks completed. MATLAB test automation is starting."
& (Join-Path $repoRoot "scripts\run_matlab_model.ps1") -ManifestPath $testManifestPath
