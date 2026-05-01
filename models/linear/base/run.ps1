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
    [switch]$SkipMatlabPostprocess
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
        return (Join-Path $RepoRoot "runtime\comsol\linear\base")
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
        return (Join-Path $RepoRoot "outputs\linear\base")
    }
    if ([System.IO.Path]::IsPathRooted($InputPath)) {
        return $InputPath
    }
    return (Join-Path $RepoRoot $InputPath)
}

function Get-LeafMap {
    param([object]$Config)

    $sections = @("geometry", "material", "boundary", "excitation", "studies", "mesh")
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

    $requiredKeys = @("L_free", "b", "h", "rho", "E", "nu", "J", "tau_imp", "eigen_modes", "time_end", "time_step", "numelem")
    foreach ($key in $requiredKeys) {
        if (-not $LeafMap.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($LeafMap[$key])) {
            throw "Missing required config value: $key"
        }
    }

    return [ordered]@{
        L_total = $(if ($LeafMap.ContainsKey("L_total")) { $LeafMap["L_total"] } else { "0.30[m]" })
        L_free = $LeafMap["L_free"]
        L = $LeafMap["L_free"]
        b = $LeafMap["b"]
        h_beam = $LeafMap["h"]
        rho = $LeafMap["rho"]
        E = $LeafMap["E"]
        nu = $LeafMap["nu"]
        root = $(if ($LeafMap.ContainsKey("root")) { $LeafMap["root"] } else { "ideal_clamp" })
        tip = $(if ($LeafMap.ContainsKey("tip")) { $LeafMap["tip"] } else { "free" })
        excitation_mode = $(if ($LeafMap.ContainsKey("mode")) { $LeafMap["mode"] } else { "impact" })
        use_impulse = $(if ($LeafMap.ContainsKey("use_impulse")) { $LeafMap["use_impulse"] } else { "1" })
        J = $LeafMap["J"]
        tau_imp = $LeafMap["tau_imp"]
        pulse_shape = $(if ($LeafMap.ContainsKey("pulse_shape")) { $LeafMap["pulse_shape"] } else { "square_like" })
        eigen_modes = $LeafMap["eigen_modes"]
        time_end = $LeafMap["time_end"]
        time_step = $LeafMap["time_step"]
        mesh_numelem = $LeafMap["numelem"]
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

function Write-GeneratedModelSource {
    param(
        [string]$TemplatePath,
        [string]$GeneratedPath,
        [string]$ParamBlock,
        [string]$ModelSavePath
    )

    $template = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
    $rendered = $template.Replace("    // __LINEAR_PARAM_BLOCK__", $ParamBlock)
    $rendered = $rendered.Replace("__MODEL_SAVE_PATH__", (ConvertTo-JavaStringLiteral -Value $ModelSavePath))
    Write-Utf8NoBomFile -Path $GeneratedPath -Content $rendered
}

$runtimeBase = Resolve-RuntimeBase -InputPath $RuntimeRoot -RepoRoot $repoRoot
$stableOutputBaseDir = Resolve-OutputBase -InputPath $OutputRoot -RepoRoot $repoRoot
$historyBaseDir = ""
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $historyBaseDir = Join-Path $repoRoot ("outputs\history\linear\base\" + $Quality)
}

$ComsolBin = Resolve-ComsolBin -InputPath $ComsolBin
$comsolCompileExe = Join-Path $ComsolBin "comsolcompile.exe"
$comsolBatchExe = Join-Path $ComsolBin "comsolbatch.exe"

$sourceDir = Join-Path $PSScriptRoot "src"
$buildDir = Join-Path $PSScriptRoot "artifacts\build"
$runToken = Get-Date -Format "yyyyMMdd_HHmmss"
$runBuildDir = Join-Path $buildDir ("run_" + $runToken)
$generatedSourceDir = Join-Path $runBuildDir "generated"
$outputsDir = Join-Path $stableOutputBaseDir "mph"
$dataDir = Join-Path $stableOutputBaseDir "results"
$figuresDir = $dataDir
$logsDir = Join-Path $stableOutputBaseDir "logs"

$defaultConfigPath = Join-Path $PSScriptRoot "config\params.json"
$configPath = Resolve-OptionalPath -InputPath $ConfigPath -DefaultPath $defaultConfigPath -BaseDir $repoRoot
$configObject = Read-JsonFile -Path $configPath
$resolvedInfo = New-ResolvedLinearConfig -Config $configObject -ModelId "base" -Quality $Quality
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
    New-Item -ItemType Directory -Path $buildDir, $runBuildDir, $generatedSourceDir, $stableOutputBaseDir, $outputsDir, $dataDir, $figuresDir, $logsDir -Force | Out-Null

    $resolvedConfigPath = Join-Path $stableOutputBaseDir "params_resolved.json"
    $runStart = Get-Date
    $buildTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $modelLogPath = Join-Path $logsDir "linear_base.log"
    $matlabLogPath = Join-Path $logsDir "linear_base_matlab.log"
    $matlabManifestPath = Join-Path $logsDir "linear_base_matlab_manifest.json"
    $matlabStatusPath = Join-Path $logsDir "linear_base_matlab_status.json"
    $modelMphPath = Join-Path $outputsDir "linear_base.mph"

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

    $generatedJavaPath = Join-Path $generatedSourceDir "Linear_Base_EB.java"
    Write-GeneratedModelSource -TemplatePath (Join-Path $sourceDir "Linear_Base_EB.java") -GeneratedPath $generatedJavaPath -ParamBlock (Get-GeneratedParamBlock -Params $selectedParams) -ModelSavePath $modelMphPath

    Invoke-External -Exe $comsolCompileExe -ArgList ($commonArgs + @("Linear_Base_EB.java")) -Step "linear/base compile model" -WorkingDirectory $generatedSourceDir
    Move-ClassArtifactsToBuild -SourceDir $generatedSourceDir -BuildDir $runBuildDir
    Assert-NewerThan -PathToCheck (Join-Path $runBuildDir "Linear_Base_EB.class") -Since $runStart -Message "linear/base compile did not produce class file."

    Invoke-External -Exe $comsolBatchExe -ArgList ($commonArgs + @("-classpath", $runBuildDir, "-inputfile", (Join-Path $runBuildDir "Linear_Base_EB.class"), "-batchlog", $modelLogPath)) -Step "linear/base build mph" -WorkingDirectory $PSScriptRoot
    Move-StrayMphArtifacts -ModelDir $PSScriptRoot -OutputsDir $outputsDir
    $fallbackMphPath = Join-Path $runBuildDir "Linear_Base_EB_Model.mph"
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
            Write-Host "==> linear/base using fallback MPH: $fallbackMphPath"
        }
        $modelMphPath = $resolvedMphPath
    }

    Assert-NewerThan -PathToCheck $modelLogPath -Since $runStart -Message "linear/base build did not produce model log."
    Assert-NewerThan -PathToCheck $modelMphPath -Since $runStart -Message "linear/base build did not produce MPH output."
    $buildTimer.Stop()
    $buildSeconds = [Math]::Round($buildTimer.Elapsed.TotalSeconds, 6)

    New-CodexMatlabHandoffManifest `
        -ManifestPath $matlabManifestPath `
        -ProjectRoot $repoRoot `
        -EntryFunction "main_linear_base_from_manifest" `
        -OutputRoot $stableOutputBaseDir `
        -ModelLine "linear" `
        -ModelId "base" `
        -ConfigPath $resolvedConfigPath `
        -MphPath $modelMphPath `
        -LogPath $matlabLogPath `
        -StatusPath $matlabStatusPath `
        -BuildWallclockSeconds ([string]$buildSeconds) `
        -SourceScript "models/linear/base/run.ps1" `
        -ExtraFields @{ quality = $Quality } | Out-Null

    Write-CodexMatlabStatusFile `
        -StatusPath $matlabStatusPath `
        -State "pending" `
        -ManifestPath $matlabManifestPath `
        -EntryFunction "main_linear_base_from_manifest" `
        -LogPath $matlabLogPath `
        -Message "COMSOL build completed. Continue with run_matlab_manifest(manifest_path) from the active MATLAB session."

    if ($SkipMatlabPostprocess) {
        Write-Host "==> linear/base build-only completed ($Quality): $modelMphPath"
        return
    }

    $env:USERPROFILE = $originalUserProfile
    $env:HOME = $originalHome
    $env:TMP = $originalTmp
    $env:TEMP = $originalTemp

    & (Join-Path $repoRoot "scripts\run_matlab_model.ps1") -ManifestPath $matlabManifestPath -LocalComsolPort $LocalComsolPort
    Write-Host "==> linear/base MATLAB handoff completed: $matlabManifestPath"
}
finally {
    $env:USERPROFILE = $originalUserProfile
    $env:HOME = $originalHome
    $env:TMP = $originalTmp
    $env:TEMP = $originalTemp
}
