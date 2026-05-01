[CmdletBinding(DefaultParameterSetName = "manifest")]
param(
    [Parameter(ParameterSetName = "manifest", Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(ParameterSetName = "legacy", Mandatory = $true)]
    [string]$MainFunction,

    [Parameter(ParameterSetName = "legacy")]
    [string[]]$FunctionArgs = @(),

    [Parameter(ParameterSetName = "legacy")]
    [string]$LogPath = "",

    [Parameter(ParameterSetName = "legacy")]
    [string]$ManifestOutputPath = "",

    [ValidateRange(0, 65535)]
    [int]$LocalComsolPort = 0,

    [switch]$AllowComsolLiveLink,

    [string]$MatlabExe = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "comsol_common.ps1")

function Resolve-LegacyManifestPath {
    param(
        [string]$RepoRoot,
        [string]$MainFunction,
        [string]$LogPath,
        [string]$ManifestOutputPath
    )

    if (-not [string]::IsNullOrWhiteSpace($ManifestOutputPath)) {
        if ([System.IO.Path]::IsPathRooted($ManifestOutputPath)) {
            return $ManifestOutputPath
        }
        return (Join-Path $RepoRoot $ManifestOutputPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $logDir = Split-Path -Parent $LogPath
        if ([string]::IsNullOrWhiteSpace($logDir)) {
            $logDir = (Join-Path $RepoRoot "outputs\test_logs")
        }
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($LogPath)
        if ($stem -like "*_matlab") {
            return (Join-Path $logDir ($stem + "_manifest.json"))
        }
        return (Join-Path $logDir ($stem + "_matlab_manifest.json"))
    }

    return (Join-Path $RepoRoot ("outputs\test_logs\" + $MainFunction + "_matlab_manifest.json"))
}

function Resolve-LegacyStatusPath {
    param([string]$ManifestPath)

    $manifestDir = Split-Path -Parent $ManifestPath
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($ManifestPath)
    if ($stem -like "*_manifest") {
        $stem = $stem.Substring(0, $stem.Length - "_manifest".Length)
    }
    return (Join-Path $manifestDir ($stem + "_status.json"))
}

function Convert-ManifestArgsToStrings {
    param([object]$RawArgs)

    if ($null -eq $RawArgs) {
        return @()
    }
    if ($RawArgs -is [string]) {
        return @($RawArgs)
    }
    if ($RawArgs -is [System.Collections.IEnumerable] -and -not ($RawArgs -is [string])) {
        return @($RawArgs | ForEach-Object { [string]$_ })
    }
    return @([string]$RawArgs)
}

function Resolve-ManifestMatlabRoot {
    param(
        [object]$Manifest,
        [string]$RepoRoot
    )

    $matlabRoot = [string]$Manifest.matlab_project_root
    if ([string]::IsNullOrWhiteSpace($matlabRoot)) {
        $matlabRoot = Join-Path $RepoRoot "matlab"
    } elseif (-not [System.IO.Path]::IsPathRooted($matlabRoot)) {
        $matlabRoot = Join-Path $RepoRoot $matlabRoot
    }

    if (-not (Test-Path -LiteralPath $matlabRoot)) {
        throw "MATLAB project root not found: $matlabRoot"
    }
    return $matlabRoot
}

function Read-CodexMatlabStatusObject {
    param([string]$StatusPath)

    if ([string]::IsNullOrWhiteSpace($StatusPath) -or -not (Test-Path -LiteralPath $StatusPath)) {
        return $null
    }

    try {
        return (Get-Content -LiteralPath $StatusPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        return $null
    }
}

function Test-ListeningPort {
    param([int]$TargetPort)

    $getNetTcp = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
    if ($null -ne $getNetTcp) {
        return @(Get-NetTCPConnection -State Listen -LocalPort $TargetPort -ErrorAction SilentlyContinue).Count -gt 0
    }

    $netstatLines = @(netstat -ano | Select-String -Pattern (":{0}\s" -f $TargetPort))
    return $netstatLines.Count -gt 0
}

function Get-PreferredLocalComsolPorts {
    $ports = New-Object System.Collections.Generic.List[int]

    if ($LocalComsolPort -gt 0) {
        $ports.Add($LocalComsolPort)
        return @($ports.ToArray())
    }

    $rawPorts = $env:TSR_COMSOL_LOCAL_PORTS
    if ([string]::IsNullOrWhiteSpace($rawPorts)) {
        $rawPorts = "2038,2036"
    }

    foreach ($token in ($rawPorts -split '[,\s;]+')) {
        if ([string]::IsNullOrWhiteSpace($token)) {
            continue
        }
        $parsed = 0
        if (-not [int]::TryParse($token, [ref]$parsed)) {
            continue
        }
        if ($parsed -le 0 -or $parsed -gt 65535) {
            continue
        }
        if ($ports -notcontains $parsed) {
            $ports.Add($parsed)
        }
    }

    if ($ports.Count -eq 0) {
        $ports.Add(2038)
        $ports.Add(2036)
    }

    return @($ports.ToArray())
}

function Find-ReusableLocalComsolPort {
    param([int[]]$CandidatePorts)

    foreach ($port in $CandidatePorts) {
        if (Test-ListeningPort -TargetPort $port) {
            return $port
        }
    }

    return 0
}

function Get-ManifestRequiredCsvPaths {
    param([object]$Manifest)

    $outputRoot = [string]$Manifest.output_root
    if ([string]::IsNullOrWhiteSpace($outputRoot) -or -not [System.IO.Path]::IsPathRooted($outputRoot)) {
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

function Get-MissingRequiredManifestCsvPaths {
    param([object]$Manifest)

    $requiredPaths = @(Get-ManifestRequiredCsvPaths -Manifest $Manifest)
    if ($requiredPaths.Count -eq 0) {
        return @()
    }

    return @($requiredPaths | Where-Object { -not (Test-Path -LiteralPath $_) })
}

function Test-ManifestNeedsLocalComsolServer {
    param([object]$Manifest)

    $mphPath = [string]$Manifest.mph_path

    if ([string]::IsNullOrWhiteSpace($mphPath)) {
        return $false
    }

    $requiredPaths = @(Get-ManifestRequiredCsvPaths -Manifest $Manifest)
    if ($requiredPaths.Count -eq 0) {
        return $true
    }

    $missingPaths = @(Get-MissingRequiredManifestCsvPaths -Manifest $Manifest)
    return ($missingPaths.Count -gt 0)
}

function Get-ManifestAutomationTimeoutSeconds {
    param([object]$Manifest)

    $entryFunction = [string]$Manifest.entry_function
    $modelLine = [string]$Manifest.model_line

    if ($entryFunction -like "*param_study*" -or $entryFunction -like "*study_postprocess*") {
        return 14400
    }
    if ($modelLine -eq "linear") {
        return 7200
    }

    return 1800
}

function Get-LocalComsolServerStartCommand {
    param([int]$Port)

    $mphServerExe = '<COMSOL_BIN>\comsolmphserver.exe'
    try {
        $resolvedComsolBin = Resolve-ComsolBin -InputPath $env:COMSOL_BIN
        $mphServerExe = Join-Path $resolvedComsolBin "comsolmphserver.exe"
    }
    catch {
    }

    return ('Start-Process -FilePath "{0}" -ArgumentList "-port {1} -login never -multi on -silent"' -f $mphServerExe, $Port)
}

function Format-MatlabAutomationFailure {
    param(
        [string]$Header,
        [string]$ManifestPath,
        [string]$StatusPath,
        [string]$LogPath,
        [string]$Details = ""
    )

    $lines = @(
        $Header,
        ("Manifest: {0}" -f $ManifestPath),
        ("Status: {0}" -f $StatusPath),
        ("Log: {0}" -f $(if ([string]::IsNullOrWhiteSpace($LogPath)) { "(not available)" } else { $LogPath }))
    )

    if (-not [string]::IsNullOrWhiteSpace($Details)) {
        $lines += ""
        $lines += $Details
    }

    return ($lines -join [Environment]::NewLine)
}

function Wait-ForMatlabCompletion {
    param(
        [string]$ManifestPath,
        [string]$StatusPath,
        [string]$PreferredLogPath,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $effectiveLogPath = $PreferredLogPath
    $lastStatus = ""

    while ((Get-Date) -lt $deadline) {
        $statusObject = Read-CodexMatlabStatusObject -StatusPath $StatusPath
        if ($null -ne $statusObject) {
            if ($statusObject.PSObject.Properties["status"]) {
                $lastStatus = [string]$statusObject.status
            }
            if ($statusObject.PSObject.Properties["log_path"] -and -not [string]::IsNullOrWhiteSpace([string]$statusObject.log_path)) {
                $effectiveLogPath = [string]$statusObject.log_path
            }

            switch ($lastStatus) {
                "completed" {
                    if ([string]::IsNullOrWhiteSpace($effectiveLogPath) -or (Test-Path -LiteralPath $effectiveLogPath)) {
                        return $statusObject
                    }
                }
                "failed" {
                    $details = ""
                    if ($statusObject.PSObject.Properties["error_report"]) {
                        $details = [string]$statusObject.error_report
                    } elseif ($statusObject.PSObject.Properties["message"]) {
                        $details = [string]$statusObject.message
                    }

                    throw (Format-MatlabAutomationFailure `
                            -Header "MATLAB automation failed." `
                            -ManifestPath $ManifestPath `
                            -StatusPath $StatusPath `
                            -LogPath $effectiveLogPath `
                            -Details $details)
                }
            }
        }

        Start-Sleep -Seconds 2
    }

    $detail = "Timed out waiting for *_matlab_status.json to reach completed."
    if (-not [string]::IsNullOrWhiteSpace($lastStatus)) {
        $detail = $detail + (" Last observed status: {0}" -f $lastStatus)
    }

    throw (Format-MatlabAutomationFailure `
            -Header "MATLAB automation timed out." `
            -ManifestPath $ManifestPath `
            -StatusPath $StatusPath `
            -LogPath $effectiveLogPath `
            -Details $detail)
}

function Invoke-MatlabManifestBatch {
    param(
        [string]$RepoRoot,
        [string]$ManifestPath,
        [string]$MatlabExeInput,
        [object]$Manifest,
        [string]$StatusPath,
        [string]$LogPath,
        [string]$EntryFunction,
        [hashtable]$EnvironmentUpdates,
        [string]$PendingMessage
    )

    $resolvedMatlabExe = Resolve-MatlabExe -InputPath $MatlabExeInput
    $matlabRoot = Resolve-ManifestMatlabRoot -Manifest $Manifest -RepoRoot $RepoRoot
    $timeoutSeconds = Get-ManifestAutomationTimeoutSeconds -Manifest $Manifest

    $manifestArg = ConvertTo-MatlabSingleQuoted -Value $ManifestPath
    $matlabRootArg = ConvertTo-MatlabSingleQuoted -Value $matlabRoot
    $batchCommand = "cd('$matlabRootArg'); run_matlab_manifest('$manifestArg');"

    $mergedEnvironment = @{} + $EnvironmentUpdates
    $mergedEnvironment["TSR_PROJECT_ROOT"] = $RepoRoot

    $previousValues = @{}
    foreach ($name in $mergedEnvironment.Keys) {
        $previousValues[$name] = [System.Environment]::GetEnvironmentVariable($name, "Process")
    }

    Write-CodexMatlabStatusFile `
        -StatusPath $StatusPath `
        -State "pending" `
        -ManifestPath $ManifestPath `
        -EntryFunction $EntryFunction `
        -LogPath $LogPath `
        -Message $PendingMessage

    try {
        foreach ($name in $mergedEnvironment.Keys) {
            [System.Environment]::SetEnvironmentVariable($name, [string]$mergedEnvironment[$name], "Process")
        }

        Invoke-MatlabBatchRobust `
            -MatlabExe $resolvedMatlabExe `
            -BatchCommand $batchCommand

        $null = Wait-ForMatlabCompletion `
            -ManifestPath $ManifestPath `
            -StatusPath $StatusPath `
            -PreferredLogPath $LogPath `
            -TimeoutSeconds $timeoutSeconds
    }
    catch {
        $statusObject = Read-CodexMatlabStatusObject -StatusPath $StatusPath
        $failedFromMatlab = ($null -ne $statusObject) -and $statusObject.PSObject.Properties["status"] -and ([string]$statusObject.status -eq "failed")

        if (-not $failedFromMatlab) {
            Write-CodexMatlabStatusFile `
                -StatusPath $StatusPath `
                -State "failed" `
                -ManifestPath $ManifestPath `
                -EntryFunction $EntryFunction `
                -LogPath $LogPath `
                -Message "MATLAB automation did not reach completed." `
                -ErrorReport $_.ToString()
        }

        throw
    }
    finally {
        foreach ($name in $previousValues.Keys) {
            [System.Environment]::SetEnvironmentVariable($name, $previousValues[$name], "Process")
        }
    }
}

function Invoke-LocalComsolPortMode {
    param(
        [string]$RepoRoot,
        [string]$ManifestPath,
        [string]$MatlabExeInput,
        [int]$Port,
        [object]$Manifest,
        [string]$StatusPath,
        [string]$LogPath,
        [string]$EntryFunction
    )

    if (-not (Test-ListeningPort -TargetPort $Port)) {
        $details = @(
            ("No reusable local COMSOL server was found on port {0}." -f $Port),
            "Start the server first, then rerun the same model script or rerun scripts/run_matlab_model.ps1 for this manifest.",
            "",
            "Suggested command:",
            (Get-LocalComsolServerStartCommand -Port $Port)
        ) -join [Environment]::NewLine

        Write-CodexMatlabStatusFile `
            -StatusPath $StatusPath `
            -State "failed" `
            -ManifestPath $ManifestPath `
            -EntryFunction $EntryFunction `
            -LogPath $LogPath `
            -Message "MATLAB automation could not start because no local COMSOL server was available." `
            -ErrorReport $details

        throw (Format-MatlabAutomationFailure `
                -Header "MATLAB automation requires an already-running local COMSOL server." `
                -ManifestPath $ManifestPath `
                -StatusPath $StatusPath `
                -LogPath $LogPath `
                -Details $details)
    }

    $sharedComsolState = Get-LocalComsolServerState -Port $Port -ProjectRoot $RepoRoot
    $sharedEnv = Get-ComsolRuntimeEnvironmentMap -State $sharedComsolState

    Invoke-MatlabManifestBatch `
        -RepoRoot $RepoRoot `
        -ManifestPath $ManifestPath `
        -MatlabExeInput $MatlabExeInput `
        -Manifest $Manifest `
        -StatusPath $StatusPath `
        -LogPath $LogPath `
        -EntryFunction $EntryFunction `
        -PendingMessage ("Launching MATLAB automation against reusable local COMSOL server localhost:{0}." -f $Port) `
        -EnvironmentUpdates (@{
            TSR_COMSOL_HOST = "localhost"
            TSR_COMSOL_PORT = [string]$Port
            TSR_COMSOL_USE_SYSTEM_LOCAL = "1"
            TSR_COMSOL_MODE = "local_port"
            TSR_COMSOL_LOCAL_PORTS = [string]$Port
        } + $sharedEnv)
}

function Invoke-DirectMatlabBatchMode {
    param(
        [string]$RepoRoot,
        [string]$ManifestPath,
        [string]$MatlabExeInput,
        [object]$Manifest,
        [string]$StatusPath,
        [string]$LogPath,
        [string]$EntryFunction
    )

    Invoke-MatlabManifestBatch `
        -RepoRoot $RepoRoot `
        -ManifestPath $ManifestPath `
        -MatlabExeInput $MatlabExeInput `
        -Manifest $Manifest `
        -StatusPath $StatusPath `
        -LogPath $LogPath `
        -EntryFunction $EntryFunction `
        -PendingMessage "Launching MATLAB automation without an explicit COMSOL LiveLink port." `
        -EnvironmentUpdates @{
            TSR_COMSOL_HOST = $null
            TSR_COMSOL_PORT = $null
            TSR_COMSOL_USE_SYSTEM_LOCAL = $null
            TSR_COMSOL_MODE = $null
            TSR_COMSOL_LOCAL_PORTS = $null
        }
}

function Stop-BeforeComsolBoundary {
    param(
        [string]$ManifestPath,
        [object]$Manifest,
        [string]$StatusPath,
        [string]$LogPath,
        [string]$EntryFunction
    )

    $missingPaths = @(Get-MissingRequiredManifestCsvPaths -Manifest $Manifest)
    $missingText = if ($missingPaths.Count -gt 0) {
        ($missingPaths | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
    } else {
        "  - Required CSV set is unknown for this COMSOL-backed manifest."
    }

    $details = @(
        "This manifest is not safe for default MATLAB batch automation because it needs COMSOL/LiveLink data production.",
        "Default automation stops here before launching MATLAB, COMSOL, mphstart, or ModelUtil.",
        "",
        "Missing or unverified CSV inputs:",
        $missingText,
        "",
        "Generate/export the CSV files in a user-controlled local COMSOL session, then rerun the same manifest.",
        "If you intentionally want to use a fully legitimate LiveLink environment, rerun with -AllowComsolLiveLink or use scripts/run_matlab_manifest_local_port.ps1."
    ) -join [Environment]::NewLine

    Write-CodexMatlabStatusFile `
        -StatusPath $StatusPath `
        -State "failed" `
        -ManifestPath $ManifestPath `
        -EntryFunction $EntryFunction `
        -LogPath $LogPath `
        -Message "MATLAB automation stopped before the COMSOL/LiveLink boundary because required CSV inputs are missing." `
        -ErrorReport $details

    throw (Format-MatlabAutomationFailure `
            -Header "MATLAB automation stopped before COMSOL/LiveLink boundary." `
            -ManifestPath $ManifestPath `
            -StatusPath $StatusPath `
            -LogPath $LogPath `
            -Details $details)
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ($PSCmdlet.ParameterSetName -eq "legacy") {
    $resolvedLogPath = $LogPath
    if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and -not [System.IO.Path]::IsPathRooted($resolvedLogPath)) {
        $resolvedLogPath = Join-Path $repoRoot $resolvedLogPath
    }

    $resolvedManifestPath = Resolve-LegacyManifestPath `
        -RepoRoot $repoRoot `
        -MainFunction $MainFunction `
        -LogPath $resolvedLogPath `
        -ManifestOutputPath $ManifestOutputPath
    $resolvedStatusPath = Resolve-LegacyStatusPath -ManifestPath $resolvedManifestPath
    $outputRoot = Split-Path -Parent $resolvedManifestPath

    New-CodexMatlabHandoffManifest `
        -ManifestPath $resolvedManifestPath `
        -ProjectRoot $repoRoot `
        -EntryFunction $MainFunction `
        -OutputRoot $outputRoot `
        -ModelId $MainFunction `
        -LogPath $resolvedLogPath `
        -StatusPath $resolvedStatusPath `
        -FunctionArgs $FunctionArgs `
        -SourceScript "scripts/run_matlab_model.ps1 (legacy)" `
        -InvokeStyle "function_args" | Out-Null

    $ManifestPath = $resolvedManifestPath
}

if (-not [System.IO.Path]::IsPathRooted($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot $ManifestPath
}
if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "MATLAB handoff manifest not found: $ManifestPath"
}

$manifest = Read-JsonFile -Path $ManifestPath
$entryFunction = [string]$manifest.entry_function
$logPath = [string]$manifest.log_path
$statusPath = [string]$manifest.status_path

if ([string]::IsNullOrWhiteSpace($statusPath)) {
    $statusPath = Resolve-LegacyStatusPath -ManifestPath $ManifestPath
}
if (-not [System.IO.Path]::IsPathRooted($statusPath)) {
    $statusPath = Join-Path $repoRoot $statusPath
}
if (-not [string]::IsNullOrWhiteSpace($logPath) -and -not [System.IO.Path]::IsPathRooted($logPath)) {
    $logPath = Join-Path $repoRoot $logPath
}

if ($LocalComsolPort -gt 0) {
    Invoke-LocalComsolPortMode `
        -RepoRoot $repoRoot `
        -ManifestPath $ManifestPath `
        -MatlabExeInput $MatlabExe `
        -Port $LocalComsolPort `
        -Manifest $manifest `
        -StatusPath $statusPath `
        -LogPath $logPath `
        -EntryFunction $entryFunction
    return
}

if ((Test-ManifestNeedsLocalComsolServer -Manifest $manifest) -and -not $AllowComsolLiveLink) {
    Stop-BeforeComsolBoundary `
        -ManifestPath $ManifestPath `
        -Manifest $manifest `
        -StatusPath $statusPath `
        -LogPath $logPath `
        -EntryFunction $entryFunction
}

if (Test-ManifestNeedsLocalComsolServer -Manifest $manifest) {
    $candidatePorts = Get-PreferredLocalComsolPorts
    $reusablePort = Find-ReusableLocalComsolPort -CandidatePorts $candidatePorts

    if ($reusablePort -le 0) {
        $preferredText = ($candidatePorts | ForEach-Object { [string]$_ }) -join ", "
        $suggestedPort = if ($candidatePorts.Count -gt 0) { $candidatePorts[0] } else { 2038 }
        $details = @(
            ("No reusable local COMSOL server was found on preferred ports [{0}]." -f $preferredText),
            "This manifest needs a local COMSOL server for MATLAB LiveLink automation.",
            "Start the server first, then rerun the same model script.",
            "",
            "Suggested command:",
            (Get-LocalComsolServerStartCommand -Port $suggestedPort),
            "",
            ("You can also rerun with -LocalComsolPort {0} after the server is up." -f $suggestedPort)
        ) -join [Environment]::NewLine

        Write-CodexMatlabStatusFile `
            -StatusPath $statusPath `
            -State "failed" `
            -ManifestPath $ManifestPath `
            -EntryFunction $entryFunction `
            -LogPath $logPath `
            -Message "MATLAB automation could not start because no reusable local COMSOL server was available." `
            -ErrorReport $details

        throw (Format-MatlabAutomationFailure `
                -Header "MATLAB automation requires an already-running local COMSOL server." `
                -ManifestPath $ManifestPath `
                -StatusPath $statusPath `
                -LogPath $logPath `
                -Details $details)
    }

    Invoke-LocalComsolPortMode `
        -RepoRoot $repoRoot `
        -ManifestPath $ManifestPath `
        -MatlabExeInput $MatlabExe `
        -Port $reusablePort `
        -Manifest $manifest `
        -StatusPath $statusPath `
        -LogPath $logPath `
        -EntryFunction $entryFunction
    return
}

Invoke-DirectMatlabBatchMode `
    -RepoRoot $repoRoot `
    -ManifestPath $ManifestPath `
    -MatlabExeInput $MatlabExe `
    -Manifest $manifest `
    -StatusPath $statusPath `
    -LogPath $logPath `
    -EntryFunction $entryFunction
