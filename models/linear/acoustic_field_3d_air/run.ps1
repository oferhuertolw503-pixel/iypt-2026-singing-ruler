[CmdletBinding()]
param(
    [string]$ConfigPath = "",
    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "full",
    [string]$ComsolBin = $env:COMSOL_BIN,
    [string]$RuntimeRoot = "",
    [string]$OutputRoot = "",
    [ValidateRange(0, 65535)]
    [int]$LocalComsolPort = 0,
    [switch]$SkipMatlabPostprocess,
    [switch]$HonorConfigOverrides
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
. (Join-Path $repoRoot "scripts\comsol_common.ps1")

function Resolve-RuntimeBase {
    param(
        [string]$InputPath,
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return (Join-Path $RepoRoot "runtime\comsol\linear\acoustic_field_3d_air")
    }
    if ([System.IO.Path]::IsPathRooted($InputPath)) {
        return $InputPath
    }
    return (Join-Path $RepoRoot $InputPath)
}

function Resolve-OutputBase {
    param(
        [string]$InputPath,
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return (Join-Path $RepoRoot "outputs\linear\acoustic_field_3d_air")
    }
    if ([System.IO.Path]::IsPathRooted($InputPath)) {
        return $InputPath
    }
    return (Join-Path $RepoRoot $InputPath)
}

function Get-LeafMap {
    param([object]$Config)

    $sections = @("geometry", "material", "boundary", "excitation", "damping", "studies", "acoustics", "mesh")
    $map = @{}

    foreach ($sectionName in $sections) {
        $sectionProperty = $Config.PSObject.Properties[$sectionName]
        if ($null -eq $sectionProperty) {
            continue
        }
        foreach ($prop in $sectionProperty.Value.PSObject.Properties) {
            if ($prop.Value -is [System.Management.Automation.PSCustomObject]) {
                continue
            }
            if ($prop.Value -is [System.Array]) {
                continue
            }
            $map[$prop.Name] = ConvertTo-ConfigString -Value $prop.Value
        }
    }

    return $map
}

function Get-NormalizedParams {
    param([hashtable]$LeafMap)

    $requiredKeys = @(
        "L_free", "b", "h", "rho", "E", "nu", "x0", "J", "tau_imp",
        "eigen_modes", "time_end", "time_step", "mode_points", "use_real_air_domain",
        "air_shape", "air_radius", "rho_air", "c_air",
        "mic_x", "mic_y", "mic_z", "mic_offset_from_surface_m", "numelem"
    )
    foreach ($key in $requiredKeys) {
        if (-not $LeafMap.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($LeafMap[$key])) {
            throw "Missing required config value: $key"
        }
    }

    return [ordered]@{
        L_free = $LeafMap["L_free"]
        b = $LeafMap["b"]
        h_ruler = $LeafMap["h"]
        rho = $LeafMap["rho"]
        E = $LeafMap["E"]
        nu = $LeafMap["nu"]
        root = $(if ($LeafMap.ContainsKey("root")) { $LeafMap["root"] } else { "ideal_clamp" })
        tip = $(if ($LeafMap.ContainsKey("tip")) { $LeafMap["tip"] } else { "free" })
        excitation_mode = $(if ($LeafMap.ContainsKey("mode")) { $LeafMap["mode"] } else { "impact" })
        x0 = $LeafMap["x0"]
        use_impulse = $(if ($LeafMap.ContainsKey("use_impulse")) { $LeafMap["use_impulse"] } else { "1" })
        J = $LeafMap["J"]
        tau_imp = $LeafMap["tau_imp"]
        pulse_shape = $(if ($LeafMap.ContainsKey("pulse_shape")) { $LeafMap["pulse_shape"] } else { "gaussian" })
        impact_patch_dx = $(if ($LeafMap.ContainsKey("impact_patch_dx")) { $LeafMap["impact_patch_dx"] } else { "0.010[m]" })
        impact_patch_dy = $(if ($LeafMap.ContainsKey("impact_patch_dy")) { $LeafMap["impact_patch_dy"] } else { "0.006[m]" })
        zeta_struct = $(if ($LeafMap.ContainsKey("zeta_struct")) { $LeafMap["zeta_struct"] } else { "0.015" })
        f_damp_low = $(if ($LeafMap.ContainsKey("f_damp_low")) { $LeafMap["f_damp_low"] } elseif ($LeafMap.ContainsKey("f_damp_ref")) { $LeafMap["f_damp_ref"] } else { "40[Hz]" })
        f_damp_high = $(if ($LeafMap.ContainsKey("f_damp_high")) { $LeafMap["f_damp_high"] } elseif ($LeafMap.ContainsKey("f_damp_ref")) { $LeafMap["f_damp_ref"] } else { "700[Hz]" })
        eigen_modes = $LeafMap["eigen_modes"]
        eigen_shift = $(if ($LeafMap.ContainsKey("eigen_shift")) { $LeafMap["eigen_shift"] } else { "1000[Hz]" })
        time_end = $LeafMap["time_end"]
        time_step = $LeafMap["time_step"]
        mode_points = $LeafMap["mode_points"]
        mesh_numelem = $LeafMap["numelem"]
        use_real_air_domain = $LeafMap["use_real_air_domain"]
        air_shape = $LeafMap["air_shape"]
        air_radius = $LeafMap["air_radius"]
        rho_air = $LeafMap["rho_air"]
        c_air = $LeafMap["c_air"]
        mic_x = $LeafMap["mic_x"]
        mic_y = $LeafMap["mic_y"]
        mic_z = $LeafMap["mic_z"]
        mic_offset_from_surface_m = $LeafMap["mic_offset_from_surface_m"]
        radiation_source_x = $(if ($LeafMap.ContainsKey("radiation_source_x")) { $LeafMap["radiation_source_x"] } else { "L_free/2" })
        radiation_source_y = $(if ($LeafMap.ContainsKey("radiation_source_y")) { $LeafMap["radiation_source_y"] } else { "0[m]" })
        radiation_source_z = $(if ($LeafMap.ContainsKey("radiation_source_z")) { $LeafMap["radiation_source_z"] } else { "0[m]" })
    }
}

function Get-GeneratedParamBlock {
    param([hashtable]$Params)

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($key in $Params.Keys) {
        $javaValue = ConvertTo-JavaStringLiteral -Value $Params[$key]
        $null = $lines.Add("    model.param().set(""$key"", ""$javaValue"");")
    }
    return [string]::Join([Environment]::NewLine, $lines)
}

function Get-AutoMeshSizeFromNumElem {
    param([Parameter(Mandatory = $true)][string]$MeshNumElem)

    $trimmed = [string]$MeshNumElem
    $parsed = 0
    if (-not [int]::TryParse($trimmed, [ref]$parsed)) {
        $parsed = [int][Math]::Round([double]::Parse($trimmed, [System.Globalization.CultureInfo]::InvariantCulture))
    }

    if ($parsed -le 50) {
        return "5"
    }
    if ($parsed -le 100) {
        return "4"
    }
    return "3"
}

function Write-GeneratedModelSource {
    param(
        [string]$TemplatePath,
        [string]$GeneratedPath,
        [string]$ParamBlock,
        [string]$ModelSavePath,
        [hashtable]$Params
    )

    $template = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
    $rendered = $template.Replace("    // __LINEAR_PARAM_BLOCK__", $ParamBlock)
    $modePointsValue = $Params["mode_points"]
    if ([string]::IsNullOrWhiteSpace($modePointsValue)) {
        $modePointsValue = "241"
    }
    $rendered = $rendered.Replace("__MODE_POINTS__", $modePointsValue)
    $rendered = $rendered.Replace("__AUTO_MESH_SIZE__", (Get-AutoMeshSizeFromNumElem -MeshNumElem ([string]$Params["mesh_numelem"])))
    $rendered = $rendered.Replace("__MODEL_SAVE_PATH__", (ConvertTo-JavaStringLiteral -Value $ModelSavePath))
    Write-Utf8NoBomFile -Path $GeneratedPath -Content $rendered
}

function Get-ExpectedCommentedCsvHeader {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fileName = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
    switch ($fileName) {
        "frequencies.csv" { return "% mode,freq_hz" }
        "structure_probe_timeseries.csv" { return "% t_s,uz_m" }
        "mic_pressure_timeseries.csv" { return "% t_s,p_pa" }
        "impact_force_timeseries.csv" { return "% t_s,force_z_N" }
        "tip_timeseries.csv" { return "% t_s,w_m" }
        "mode_shapes.csv" {
            $firstDataLine = Get-Content -LiteralPath $Path -Encoding UTF8 |
                ForEach-Object { $_.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("%") } |
                Select-Object -First 1

            $colCount = if ([string]::IsNullOrWhiteSpace($firstDataLine)) {
                1
            }
            else {
                ($firstDataLine -split ",").Count
            }

            $headers = New-Object System.Collections.Generic.List[string]
            $null = $headers.Add("x_over_L")
            for ($i = 1; $i -lt $colCount; $i++) {
                $null = $headers.Add(("w_mode{0}" -f $i))
            }
            return ("% " + [string]::Join(",", $headers))
        }
        default { return "" }
    }
}

function Normalize-ExportedCsvHeader {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $headerLine = Get-ExpectedCommentedCsvHeader -Path $Path
    if ([string]::IsNullOrWhiteSpace($headerLine)) {
        return
    }

    $expectedBareHeader = $headerLine.Substring(2)
    $normalizedHeader = ($expectedBareHeader -replace "\s+", "").ToLowerInvariant()
    $dataLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed.StartsWith("%")) {
            continue
        }

        $normalizedLine = ($trimmed -replace "\s+", "").ToLowerInvariant()
        if ($normalizedLine -eq $normalizedHeader) {
            continue
        }

        $null = $dataLines.Add($trimmed)
    }

    $content = if ($dataLines.Count -gt 0) {
        $headerLine + [Environment]::NewLine + [string]::Join([Environment]::NewLine, $dataLines)
    }
    else {
        $headerLine
    }

    Write-Utf8NoBomFile -Path $Path -Content $content
}

function Normalize-ExportedCsvHeaders {
    param([Parameter(Mandatory = $true)][string]$DataDir)

    @(
        "frequencies.csv",
        "structure_probe_timeseries.csv",
        "mic_pressure_timeseries.csv",
        "impact_force_timeseries.csv",
        "tip_timeseries.csv",
        "mode_shapes.csv"
    ) | ForEach-Object {
        Normalize-ExportedCsvHeader -Path (Join-Path $DataDir $_)
    }
}

$runtimeBase = Resolve-RuntimeBase -InputPath $RuntimeRoot -RepoRoot $repoRoot
$stableOutputBaseDir = Resolve-OutputBase -InputPath $OutputRoot -RepoRoot $repoRoot
$historyBaseDir = ""
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $historyBaseDir = Join-Path $repoRoot ("outputs\history\linear\acoustic_field_3d_air\" + $Quality)
}

$ComsolBin = Resolve-ComsolBin -InputPath $ComsolBin
$comsolCompileExe = Join-Path $ComsolBin "comsolcompile.exe"
$comsolBatchExe = Join-Path $ComsolBin "comsolbatch.exe"

$sourceDir = Join-Path $PSScriptRoot "src"
$buildDir = Join-Path $PSScriptRoot "artifacts\build"
$runToken = Get-Date -Format "yyyyMMdd_HHmmss"
$runBuildDir = Join-Path $buildDir ("run_" + $runToken)
$generatedSourceDir = Join-Path $runBuildDir "generated"
$tempComsolOutputRoot = Join-Path $runBuildDir "comsol_output"
$tempOutputsDir = Join-Path $tempComsolOutputRoot "mph"
$tempDataDir = Join-Path $tempComsolOutputRoot "data"
$outputsDir = Join-Path $stableOutputBaseDir "mph"
$dataDir = Join-Path $stableOutputBaseDir "data"
$figuresDir = Join-Path $stableOutputBaseDir "figures"
$logsDir = Join-Path $stableOutputBaseDir "logs"

$defaultConfigPath = Join-Path $PSScriptRoot "config\params.json"
$configPath = Resolve-OptionalPath -InputPath $ConfigPath -DefaultPath $defaultConfigPath -BaseDir $repoRoot
$configObject = Read-JsonFile -Path $configPath
$resolvedInfo = New-ResolvedLinearConfig -Config $configObject -ModelId "acoustic_field_3d_air" -Quality $Quality -HonorConfigOverrides:$HonorConfigOverrides
$resolvedConfig = $resolvedInfo.Config
$selectedParams = Get-NormalizedParams -LeafMap (Get-LeafMap -Config $resolvedConfig)

$originalUserProfile = $env:USERPROFILE
$originalHome = $env:HOME
$originalTmp = $env:TMP
$originalTemp = $env:TEMP

$state = New-ComsolStateDirs -StateRoot $runtimeBase
Set-ComsolRuntimeEnvironment -State $state
$commonArgs = Get-ComsolStateArgs -State $state

try {
    Initialize-CanonicalOutputRoot -OutputRoot $stableOutputBaseDir -HistoryBaseDir $historyBaseDir
    New-Item -ItemType Directory -Path $buildDir, $runBuildDir, $generatedSourceDir, $tempComsolOutputRoot, $tempOutputsDir, $tempDataDir, $stableOutputBaseDir, $outputsDir, $dataDir, $figuresDir, $logsDir -Force | Out-Null

    $resolvedConfigPath = Join-Path $stableOutputBaseDir "params_resolved.json"
    $runStart = Get-Date
    $buildTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $modelLogPath = Join-Path $logsDir "linear_acoustic_field_3d_air.log"
    $matlabLogPath = Join-Path $logsDir "linear_acoustic_field_3d_air_matlab.log"
    $matlabManifestPath = Join-Path $logsDir "linear_acoustic_field_3d_air_matlab_manifest.json"
    $matlabStatusPath = Join-Path $logsDir "linear_acoustic_field_3d_air_matlab_status.json"
    $modelMphPath = Join-Path $outputsDir "linear_acoustic_field_3d_air.mph"
    $tempModelMphPath = Join-Path $tempOutputsDir "linear_acoustic_field_3d_air.mph"
    $scriptRootResolved = (Resolve-Path -LiteralPath $PSScriptRoot).Path
    if (-not $tempModelMphPath.StartsWith($scriptRootResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Expected temporary COMSOL output to stay under model root: $tempModelMphPath"
    }
    $tempModelMphPathForJava = $tempModelMphPath.Substring($scriptRootResolved.Length).TrimStart('\', '/')

    @(
        $modelLogPath,
        $matlabLogPath,
        $matlabManifestPath,
        $matlabStatusPath,
        $modelMphPath,
        (Join-Path $stableOutputBaseDir "summary.json"),
        (Join-Path $stableOutputBaseDir "summary.txt"),
        (Join-Path $stableOutputBaseDir "run_manifest.txt")
    ) | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue
        }
    }

    if (Test-Path -LiteralPath $resolvedConfigPath) {
        Remove-Item -LiteralPath $resolvedConfigPath -Force -ErrorAction SilentlyContinue
    }
    Write-JsonUtf8NoBomFile -Path $resolvedConfigPath -Data $resolvedConfig

    Remove-OptionalMatches -Directory $sourceDir -Patterns @("*.class", "*.class.recovery", "*.class.status")
    Remove-OptionalMatches -Directory $runBuildDir -Patterns @("*.class", "*.class.recovery", "*.class.status", "*_Model.mph")
    Remove-OptionalMatches -Directory $generatedSourceDir -Patterns @("*.java", "*.class", "*.class.recovery", "*.class.status")

    $generatedJavaPath = Join-Path $generatedSourceDir "Linear_Acoustic_Field_3D_Air.java"
    Write-GeneratedModelSource -TemplatePath (Join-Path $sourceDir "Linear_Acoustic_Field_3D_Air.java") -GeneratedPath $generatedJavaPath -ParamBlock (Get-GeneratedParamBlock -Params $selectedParams) -ModelSavePath $tempModelMphPathForJava -Params $selectedParams

    Invoke-External -Exe $comsolCompileExe -ArgList ($commonArgs + @("Linear_Acoustic_Field_3D_Air.java")) -Step "linear/acoustic_field_3d_air compile model" -WorkingDirectory $generatedSourceDir
    Move-ClassArtifactsToBuild -SourceDir $generatedSourceDir -BuildDir $runBuildDir
    Assert-NewerThan -PathToCheck (Join-Path $runBuildDir "Linear_Acoustic_Field_3D_Air.class") -Since $runStart -Message "linear/acoustic_field_3d_air compile did not produce class file."

    Invoke-External -Exe $comsolBatchExe -ArgList ($commonArgs + @("-classpath", $runBuildDir, "-inputfile", (Join-Path $runBuildDir "Linear_Acoustic_Field_3D_Air.class"), "-batchlog", $modelLogPath)) -Step "linear/acoustic_field_3d_air build mph" -WorkingDirectory $PSScriptRoot
    if (Test-Path -LiteralPath $tempModelMphPath) {
        Move-Item -LiteralPath $tempModelMphPath -Destination $modelMphPath -Force
    }
    if (Test-Path -LiteralPath $tempDataDir) {
        Get-ChildItem -LiteralPath $tempDataDir -File -Filter "*.csv" -ErrorAction SilentlyContinue | ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination (Join-Path $dataDir $_.Name) -Force
        }
    }
    Normalize-ExportedCsvHeaders -DataDir $dataDir
    Move-StrayMphArtifacts -ModelDir $PSScriptRoot -OutputsDir $outputsDir
    $fallbackMphPath = Join-Path $runBuildDir "Linear_Acoustic_Field_3D_Air_Model.mph"
    if (Test-Path -LiteralPath $fallbackMphPath) {
        $resolvedMphPath = $modelMphPath
        if (Test-Path -LiteralPath $modelMphPath) {
            try {
                Remove-Item -LiteralPath $modelMphPath -Force
            }
            catch {
                $resolvedMphPath = $fallbackMphPath
            }
        }
        if ($resolvedMphPath -eq $modelMphPath) {
            Move-Item -LiteralPath $fallbackMphPath -Destination $modelMphPath -Force
        }
        else {
            Write-Host "==> linear/acoustic_field_3d_air using fallback MPH: $fallbackMphPath"
        }
        $modelMphPath = $resolvedMphPath
    }

    Assert-NewerThan -PathToCheck $modelLogPath -Since $runStart -Message "linear/acoustic_field_3d_air build did not produce model log."
    Assert-NewerThan -PathToCheck $modelMphPath -Since $runStart -Message "linear/acoustic_field_3d_air build did not produce MPH output."
    Assert-NewerThan -PathToCheck (Join-Path $dataDir "frequencies.csv") -Since $runStart -Message "linear/acoustic_field_3d_air build did not export frequencies.csv."
    Assert-NewerThan -PathToCheck (Join-Path $dataDir "impact_force_timeseries.csv") -Since $runStart -Message "linear/acoustic_field_3d_air build did not export impact_force_timeseries.csv."
    Assert-NewerThan -PathToCheck (Join-Path $dataDir "structure_probe_timeseries.csv") -Since $runStart -Message "linear/acoustic_field_3d_air build did not export structure_probe_timeseries.csv."
    Assert-NewerThan -PathToCheck (Join-Path $dataDir "mode_shapes.csv") -Since $runStart -Message "linear/acoustic_field_3d_air build did not export mode_shapes.csv."
    Assert-NewerThan -PathToCheck (Join-Path $dataDir "mic_pressure_timeseries.csv") -Since $runStart -Message "linear/acoustic_field_3d_air build did not export mic_pressure_timeseries.csv."
    $buildTimer.Stop()
    $buildSeconds = [Math]::Round($buildTimer.Elapsed.TotalSeconds, 6)

    New-CodexMatlabHandoffManifest `
        -ManifestPath $matlabManifestPath `
        -ProjectRoot $repoRoot `
        -EntryFunction "main_linear_acoustic_field_3d_air_from_manifest" `
        -OutputRoot $stableOutputBaseDir `
        -ModelLine "linear" `
        -ModelId "acoustic_field_3d_air" `
        -ConfigPath $resolvedConfigPath `
        -MphPath $modelMphPath `
        -LogPath $matlabLogPath `
        -StatusPath $matlabStatusPath `
        -BuildWallclockSeconds ([string]$buildSeconds) `
        -SourceScript "models/linear/acoustic_field_3d_air/run.ps1" `
        -ExtraFields @{ quality = $Quality } | Out-Null

    Write-CodexMatlabStatusFile `
        -StatusPath $matlabStatusPath `
        -State "pending" `
        -ManifestPath $matlabManifestPath `
        -EntryFunction "main_linear_acoustic_field_3d_air_from_manifest" `
        -LogPath $matlabLogPath `
        -Message "COMSOL build completed. Continue with run_matlab_manifest(manifest_path) from the active MATLAB session."

    if ($SkipMatlabPostprocess) {
        Write-Host "==> linear/acoustic_field_3d_air build-only completed ($Quality): $modelMphPath"
        return
    }

    $env:USERPROFILE = $originalUserProfile
    $env:HOME = $originalHome
    $env:TMP = $originalTmp
    $env:TEMP = $originalTemp

    & (Join-Path $repoRoot "scripts\run_matlab_model.ps1") -ManifestPath $matlabManifestPath -LocalComsolPort $LocalComsolPort
    Write-Host "==> linear/acoustic_field_3d_air MATLAB handoff completed: $matlabManifestPath"
}
finally {
    $env:USERPROFILE = $originalUserProfile
    $env:HOME = $originalHome
    $env:TMP = $originalTmp
    $env:TEMP = $originalTemp
}
