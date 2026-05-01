Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TsrProjectRoot {
    param(
        [string]$StartDir = $PSScriptRoot
    )

    return (Resolve-Path (Join-Path $StartDir "..")).Path
}

function Resolve-ComsolBin {
    param([string]$InputPath)

    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        if (-not (Test-Path (Join-Path $InputPath "comsolcompile.exe"))) {
            throw "COMSOL bin directory not found: $InputPath"
        }
        return (Resolve-Path -LiteralPath $InputPath).Path
    }

    $candidates = @(
        "D:\Program Files\COMSOL64\Multiphysics\bin\win64",
        "D:\Program Files\comsol6.4\COMSOL64\Multiphysics\bin\win64",
        "D:\Program Files\comsol6.3\COMSOL63\Multiphysics\bin\win64"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate "comsolcompile.exe")) {
            return $candidate
        }
    }

    throw "COMSOL bin directory not found. Set -ComsolBin or COMSOL_BIN."
}

function Get-ComsolRootFromBin {
    param([Parameter(Mandatory = $true)][string]$ComsolBin)

    return (Split-Path (Split-Path $ComsolBin -Parent) -Parent)
}

function Resolve-MatlabExe {
    param([string]$InputPath)

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        $candidates += $InputPath
    }
    if (-not [string]::IsNullOrWhiteSpace($env:TSR_MATLAB_EXE)) {
        $candidates += $env:TSR_MATLAB_EXE
    }
    $candidates += @(
        "D:\Program Files\Matlab R2025a\bin\matlab.exe",
        "D:\Program Files\MATLAB\R2025a\bin\matlab.exe"
    )

    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "MATLAB executable not found. Set -MatlabExe or TSR_MATLAB_EXE."
}

function Test-ListeningPort {
    param([Parameter(Mandatory = $true)][int]$TargetPort)

    $getNetTcp = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
    if ($null -ne $getNetTcp) {
        return @(Get-NetTCPConnection -State Listen -LocalPort $TargetPort -ErrorAction SilentlyContinue).Count -gt 0
    }

    $netstatLines = @(netstat -ano | Select-String -Pattern (":{0}\s" -f $TargetPort))
    return $netstatLines.Count -gt 0
}

function Wait-ListeningPort {
    param(
        [Parameter(Mandatory = $true)][int]$TargetPort,
        [int]$TimeoutSeconds = 20
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-ListeningPort -TargetPort $TargetPort) {
            return
        }
        Start-Sleep -Seconds 1
    }

    throw "Port $TargetPort did not enter listening state within $TimeoutSeconds seconds."
}

function Start-LocalComsolMphServer {
    param(
        [Parameter(Mandatory = $true)][string]$ComsolBin,
        [Parameter(Mandatory = $true)][int]$Port,
        [hashtable]$State = $null,
        [int]$TimeoutSeconds = 20
    )

    $mphServerExe = Join-Path $ComsolBin "comsolmphserver.exe"
    if (-not (Test-Path -LiteralPath $mphServerExe)) {
        throw "COMSOL Multiphysics Server executable not found: $mphServerExe"
    }

    if ($null -eq $State) {
        $stateRoot = Get-LocalComsolServerStateRoot -Port $Port
        $State = New-ComsolStateDirs -StateRoot $stateRoot
    }

    $argsList = @(
        "-port", $Port,
        "-login", "auto",
        "-multi", "on",
        "-configuration", $State.Configuration,
        "-data", $State.Data,
        "-prefsdir", $State.Prefs,
        "-recoverydir", $State.Recovery,
        "-tmpdir", $State.Tmp,
        "-autosave", "off",
        "-silent"
    )

    $homeParts = Split-TsrHomePath -HomeDir $State.Home
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $mphServerExe
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = (Split-Path -Parent $mphServerExe)

    $psi.Arguments = ConvertTo-ComsolProcessArgumentString -Arguments $argsList

    $psi.EnvironmentVariables["USERPROFILE"] = $State.Home
    $psi.EnvironmentVariables["HOME"] = $State.Home
    $psi.EnvironmentVariables["TMP"] = $State.Tmp
    $psi.EnvironmentVariables["TEMP"] = $State.Tmp
    $psi.EnvironmentVariables["HOMEDRIVE"] = $homeParts.Drive
    $psi.EnvironmentVariables["HOMEPATH"] = $homeParts.Path
    $psi.EnvironmentVariables["APPDATA"] = $State.AppData
    $psi.EnvironmentVariables["LOCALAPPDATA"] = $State.LocalAppData

    $proc = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $proc) {
        throw "Failed to start COMSOL Multiphysics Server process."
    }

    try {
        Wait-ListeningPort -TargetPort $Port -TimeoutSeconds $TimeoutSeconds
        return $proc
    }
    catch {
        try {
            $proc.Refresh()
            if (-not $proc.HasExited) {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
        }
        throw
    }
}

function Stop-LocalComsolMphServer {
    param([System.Diagnostics.Process]$Process)

    if ($null -eq $Process) {
        return
    }

    try {
        $Process.Refresh()
        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
    }
}

function Resolve-OptionalPath {
    param(
        [string]$InputPath,
        [string]$DefaultPath,
        [string]$BaseDir
    )

    $candidate = $DefaultPath
    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        $candidate = $InputPath
    }

    if ([System.IO.Path]::IsPathRooted($candidate)) {
        if (-not (Test-Path -LiteralPath $candidate)) {
            throw "Path not found: $candidate"
        }
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    $joined = Join-Path $BaseDir $candidate
    if (Test-Path -LiteralPath $joined) {
        return (Resolve-Path -LiteralPath $joined).Path
    }

    throw "Path not found: $candidate"
}

function New-ComsolStateDirs {
    param([Parameter(Mandatory = $true)][string]$StateRoot)

    $homeDir = Join-Path $StateRoot "home"
    $cfgDir = Join-Path $StateRoot "cfg"
    $dataDir = Join-Path $StateRoot "data"
    $prefsDir = Join-Path $StateRoot "prefs"
    $recoveryDir = Join-Path $StateRoot "recoveries"
    $tmpDir = Join-Path $StateRoot "tmp"
    $appDataDir = Join-Path $StateRoot "appdata"
    $localAppDataDir = Join-Path $StateRoot "localappdata"

    foreach ($dir in @($StateRoot, $homeDir, $cfgDir, $dataDir, $prefsDir, $recoveryDir, $tmpDir, $appDataDir, $localAppDataDir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    return @{
        Root = $StateRoot
        Home = $homeDir
        Configuration = $cfgDir
        Data = $dataDir
        Prefs = $prefsDir
        Recovery = $recoveryDir
        Tmp = $tmpDir
        AppData = $appDataDir
        LocalAppData = $localAppDataDir
    }
}

function Set-ComsolRuntimeEnvironment {
    param([Parameter(Mandatory = $true)][hashtable]$State)

    $homeParts = Split-TsrHomePath -HomeDir $State.Home
    $env:USERPROFILE = $State.Home
    $env:HOME = $State.Home
    $env:TMP = $State.Tmp
    $env:TEMP = $State.Tmp
    $env:HOMEDRIVE = $homeParts.Drive
    $env:HOMEPATH = $homeParts.Path
    $env:APPDATA = $State.AppData
    $env:LOCALAPPDATA = $State.LocalAppData
}

function Get-ComsolStateArgs {
    param([Parameter(Mandatory = $true)][hashtable]$State)

    return @(
        "-configuration", $State.Configuration,
        "-data", $State.Data,
        "-prefsdir", $State.Prefs,
        "-recoverydir", $State.Recovery,
        "-tmpdir", $State.Tmp
    )
}

function Split-TsrHomePath {
    param([Parameter(Mandatory = $true)][string]$HomeDir)

    $normalized = $HomeDir.Replace('/', '\')
    if ($normalized.Length -ge 3 -and $normalized[1] -eq ':') {
        $drive = $normalized.Substring(0, 2)
        $path = $normalized.Substring(2)
        if ([string]::IsNullOrWhiteSpace($path)) {
            $path = "\"
        }
        return @{
            Drive = $drive
            Path = $path
        }
    }

    return @{
        Drive = ""
        Path = $normalized
    }
}

function ConvertTo-ComsolProcessArgumentString {
    param([Parameter(Mandatory = $true)][object[]]$Arguments)

    $quoted = foreach ($arg in $Arguments) {
        $text = [string]$arg
        if ($text -match '[\s"]') {
            '"' + ($text -replace '"', '\"') + '"'
        }
        else {
            $text
        }
    }

    return ($quoted -join ' ')
}

function Get-LocalComsolServerStateRoot {
    param(
        [Parameter(Mandatory = $true)][int]$Port,
        [string]$ProjectRoot = ""
    )

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Get-TsrProjectRoot
    }

    return (Join-Path $ProjectRoot (Join-Path ".codex_tmp\local_comsol_server" ("port_{0}" -f $Port)))
}

function Get-LocalComsolServerState {
    param(
        [Parameter(Mandatory = $true)][int]$Port,
        [string]$ProjectRoot = ""
    )

    $stateRoot = Get-LocalComsolServerStateRoot -Port $Port -ProjectRoot $ProjectRoot
    return (New-ComsolStateDirs -StateRoot $stateRoot)
}

function Get-ComsolRuntimeEnvironmentMap {
    param([Parameter(Mandatory = $true)][hashtable]$State)

    $homeParts = Split-TsrHomePath -HomeDir $State.Home
    return @{
        USERPROFILE = $State.Home
        HOME = $State.Home
        TMP = $State.Tmp
        TEMP = $State.Tmp
        HOMEDRIVE = $homeParts.Drive
        HOMEPATH = $homeParts.Path
        APPDATA = $State.AppData
        LOCALAPPDATA = $State.LocalAppData
    }
}

function Initialize-MatlabState {
    param([Parameter(Mandatory = $true)][string]$StateRoot)

    $prefsDir = Join-Path $StateRoot "prefs"
    $cacheDir = Join-Path $StateRoot "cache"

    foreach ($dir in @($StateRoot, $prefsDir, $cacheDir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $env:MATLAB_PREFDIR = $prefsDir
    $env:MCR_CACHE_ROOT = $cacheDir

    return @{
        Root = $StateRoot
        Prefs = $prefsDir
        Cache = $cacheDir
    }
}

function Invoke-External {
    param(
        [string]$Exe,
        [string[]]$ArgList,
        [string]$Step,
        [string]$WorkingDirectory,
        [string]$StdoutFile = ""
    )

    Write-Host "==> $Step"
    Push-Location $WorkingDirectory
    try {
        $cmdOut = @()
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $nativeErrorPref = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
        $restoreNativeErrorPref = $false
        if ($null -ne $nativeErrorPref) {
            $restoreNativeErrorPref = $true
            $previousNativeErrorPref = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }

        try {
            if ([string]::IsNullOrWhiteSpace($StdoutFile)) {
                $null = & $Exe @ArgList 2>&1 | Tee-Object -Variable cmdOut
            } else {
                $null = & $Exe @ArgList 2>&1 | Tee-Object -FilePath $StdoutFile
                if (Test-Path -LiteralPath $StdoutFile) {
                    $cmdOut = @(Get-Content -LiteralPath $StdoutFile -ErrorAction SilentlyContinue)
                }
            }
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
            if ($restoreNativeErrorPref) {
                $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPref
            }
        }

        $cmdOut = @($cmdOut | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.ToString()
            } else {
                [string]$_
            }
        })
        if ($cmdOut.Count -gt 0) {
            $errorLike = @($cmdOut | Where-Object {
                ($_.ToString() -notmatch '^Picked up JAVA_TOOL_OPTIONS:') -and (
                    $_.ToString() -match '(^|\s)ERROR:' -or
                    $_.ToString() -match 'Compilation failed' -or
                    $_.ToString() -match 'Failed to start COMSOL'
                )
            })
            if ($errorLike.Count -gt 0) {
                throw "$Step reported COMSOL errors."
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "$Step failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Assert-PathExists {
    param(
        [string]$PathToCheck,
        [string]$Message
    )
    if (-not (Test-Path -LiteralPath $PathToCheck)) {
        throw "$Message`nMissing path: $PathToCheck"
    }
}

function Assert-NewerThan {
    param(
        [string]$PathToCheck,
        [datetime]$Since,
        [string]$Message
    )

    Assert-PathExists -PathToCheck $PathToCheck -Message $Message
    $item = Get-Item -LiteralPath $PathToCheck
    if ($item.LastWriteTime -lt $Since) {
        throw "$Message`nPath is older than current run: $PathToCheck"
    }
}

function Move-ClassArtifactsToBuild {
    param(
        [string]$SourceDir,
        [string]$BuildDir
    )

    Get-ChildItem -Path $SourceDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '\.class(\.recovery|\.status)?$' } |
        ForEach-Object {
            Move-Item -LiteralPath $_.FullName -Destination (Join-Path $BuildDir $_.Name) -Force
        }
}

function Move-StrayMphArtifacts {
    param(
        [string]$ModelDir,
        [string]$OutputsDir
    )

    Get-ChildItem -Path $ModelDir -File -Filter "*.mph" -ErrorAction SilentlyContinue | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $OutputsDir $_.Name) -Force
    }
}

function Remove-OptionalMatches {
    param(
        [string]$Directory,
        [string[]]$Patterns
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        return
    }

    foreach ($pattern in $Patterns) {
        Get-ChildItem -Path $Directory -File -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function ConvertTo-ConfigString {
    param([object]$Value)

    if ($null -eq $Value) {
        return ""
    }
    if ($Value -is [string]) {
        return $Value
    }
    if ($Value -is [bool]) {
        return $(if ($Value) { "1" } else { "0" })
    }
    if ($Value -is [System.IFormattable]) {
        return $Value.ToString($null, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return [string]$Value
}

function ConvertTo-JavaStringLiteral {
    param([Parameter(Mandatory = $true)][string]$Value)

    $escaped = $Value.Replace('\', '\\')
    $escaped = $escaped.Replace('"', '\"')
    return $escaped
}

function ConvertTo-MatlabSingleQuoted {
    param([Parameter(Mandatory = $true)][string]$Value)

    $normalized = $Value.Replace('\', '/')
    return $normalized.Replace("'", "''")
}

function New-MatlabPostprocessScript {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string[]]$ManifestPaths,
        [string]$Title = "Singing ruler MATLAB postprocess"
    )

    if ($ManifestPaths.Count -eq 0) {
        throw "At least one MATLAB handoff manifest is required."
    }

    $scriptDir = Split-Path -Parent $ScriptPath
    if (-not [string]::IsNullOrWhiteSpace($scriptDir)) {
        New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
    }

    $projectRootLiteral = ConvertTo-MatlabSingleQuoted -Value $ProjectRoot
    $manifestLines = @($ManifestPaths | ForEach-Object {
        "    '" + (ConvertTo-MatlabSingleQuoted -Value $_) + "'"
    })
    $titleLiteral = ConvertTo-MatlabSingleQuoted -Value $Title

    $contentLines = @(
        "% Auto-generated by scripts/build_comsol_model.ps1.",
        "% Run this file from a real MATLAB session. It reads Java-exported CSV first and does not require COMSOL Server login for the normal path.",
        ("fprintf('$titleLiteral\n');"),
        ("project_root = '$projectRootLiteral';"),
        "cd(project_root);",
        "addpath(genpath(fullfile(project_root, 'matlab')));",
        "manifests = {"
    )

    for ($i = 0; $i -lt $manifestLines.Count; $i++) {
        $suffix = $(if ($i -lt ($manifestLines.Count - 1)) { ";" } else { "" })
        $contentLines += ($manifestLines[$i] + $suffix)
    }

    $contentLines += @(
        "};",
        "for k = 1:numel(manifests)",
        "    fprintf('Running MATLAB handoff %d/%d: %s\n', k, numel(manifests), manifests{k});",
        "    run_matlab_manifest(manifests{k});",
        "end",
        "fprintf('MATLAB postprocess completed.\n');",
        ""
    )

    Write-Utf8NoBomFile -Path $ScriptPath -Content ($contentLines -join [Environment]::NewLine)
    return (Resolve-Path -LiteralPath $ScriptPath).Path
}

function Format-MatlabRunCommand {
    param([Parameter(Mandatory = $true)][string]$ScriptPath)

    return ("run('{0}')" -f (ConvertTo-MatlabSingleQuoted -Value $ScriptPath))
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Convert-TextFileToUtf8FromAnsi {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($null -eq $bytes -or $bytes.Length -eq 0) {
        Write-Utf8NoBomFile -Path $Path -Content ""
        return
    }

    $hasUtf8Bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    if ($hasUtf8Bom) {
        return
    }

    $utf8 = [System.Text.Encoding]::UTF8
    $utf8Text = $utf8.GetString($bytes)
    $utf8RoundTrip = $utf8.GetBytes($utf8Text)
    $isUtf8Content = $utf8RoundTrip.Length -eq $bytes.Length
    if ($isUtf8Content) {
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($Path, $utf8Text, $utf8Bom)
        return
    }

    $ansiCodePage = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
    $ansi = [System.Text.Encoding]::GetEncoding($ansiCodePage)
    $content = $ansi.GetString($bytes)
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $content, $utf8Bom)
}

function Write-JsonUtf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 64
    Write-Utf8NoBomFile -Path $Path -Content $json
}

function Format-CodexMatlabFunctionArgs {
    param([string[]]$FunctionArgs = @())

    $argsList = @($FunctionArgs | Where-Object { $null -ne $_ })
    if ($argsList.Count -eq 0) {
        return "(none)"
    }

    return (($argsList | ForEach-Object { '"' + $_ + '"' }) -join ", ")
}

function Get-CodexMatlabSessionStatus {
    $codeCount = @(Get-Process -Name "Code" -ErrorAction SilentlyContinue).Count
    $codexCount =
        @(Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -in @("codex", "Codex", "codex-command-runner") }).Count
    $matlabMcpCount = @(Get-Process -Name "matlab-mcp-core-server-win64" -ErrorAction SilentlyContinue).Count
    $matlabCount =
        @(Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -in @("matlab", "MATLAB", "MathWorksServiceHost", "MathWorksServiceHost-Monitor") }).Count

    $hasCodexThread = -not [string]::IsNullOrWhiteSpace($env:CODEX_THREAD_ID)
    $hasCodexShell = $env:CODEX_SHELL -eq "1"
    $originator = $env:CODEX_INTERNAL_ORIGINATOR_OVERRIDE
    $isCodexDesktop = $originator -eq "Codex Desktop"
    $sessionDetected = $hasCodexThread -and $hasCodexShell -and ($matlabMcpCount -gt 0)

    return [pscustomobject]@{
        session_detected = $sessionDetected
        has_codex_thread = $hasCodexThread
        has_codex_shell = $hasCodexShell
        codex_thread_id = $env:CODEX_THREAD_ID
        codex_originator = $originator
        is_codex_desktop = $isCodexDesktop
        vscode_process_count = $codeCount
        codex_process_count = $codexCount
        matlab_mcp_process_count = $matlabMcpCount
        matlab_process_count = $matlabCount
    }
}

function Test-CodexMatlabSession {
    return [bool](Get-CodexMatlabSessionStatus).session_detected
}

function Get-CodexMatlabRequirementMessage {
    param(
        [string]$MainFunction = "",
        [string[]]$FunctionArgs = @(),
        [object]$SessionStatus = $null,
        [switch]$BridgeUnavailable,
        [string]$ManifestPath = "",
        [string]$StatusPath = ""
    )

    if ($null -eq $SessionStatus) {
        $SessionStatus = Get-CodexMatlabSessionStatus
    }

    $lines = @(
        "This command expects a live MATLAB workspace session.",
        "The repository's formal automation path now goes through scripts/run_matlab_model.ps1.",
        ""
    )

    if ($BridgeUnavailable) {
        $lines += @(
            "The current command was invoked in a session-gated/manual-recovery path.",
            "It cannot complete the MATLAB phase from this shell-only context.",
            "Use the formal model run.ps1 automation path or continue the manifest from a live MATLAB session.",
            ""
        )
    }

    $lines += @(
        ("Requested MATLAB function: {0}" -f $(if ([string]::IsNullOrWhiteSpace($MainFunction)) { "(unspecified)" } else { $MainFunction })),
        ("Requested arguments: {0}" -f (Format-CodexMatlabFunctionArgs -FunctionArgs $FunctionArgs)),
        ("Manifest path: {0}" -f $(if ([string]::IsNullOrWhiteSpace($ManifestPath)) { "(unspecified)" } else { $ManifestPath })),
        ("Status path: {0}" -f $(if ([string]::IsNullOrWhiteSpace($StatusPath)) { "(unspecified)" } else { $StatusPath })),
        "",
        "Detected session status:",
        ("- session_detected: {0}" -f $SessionStatus.session_detected),
        ("- has_codex_thread: {0}" -f $SessionStatus.has_codex_thread),
        ("- has_codex_shell: {0}" -f $SessionStatus.has_codex_shell),
        ("- codex_originator: {0}" -f $(if ([string]::IsNullOrWhiteSpace($SessionStatus.codex_originator)) { "(empty)" } else { $SessionStatus.codex_originator })),
        ("- vscode_process_count: {0}" -f $SessionStatus.vscode_process_count),
        ("- codex_process_count: {0}" -f $SessionStatus.codex_process_count),
        ("- matlab_mcp_process_count: {0}" -f $SessionStatus.matlab_mcp_process_count),
        ("- matlab_process_count: {0}" -f $SessionStatus.matlab_process_count),
        ""
    )

    if (-not $SessionStatus.session_detected) {
        $lines += @(
            "Recovery:",
            "1. Open this repository in VSCode.",
            "2. Start or resume the Codex Desktop conversation for this workspace.",
            "3. Confirm the MATLAB extension session is alive and the MATLAB MCP server is attached.",
            "4. Either rerun the formal model script so scripts/run_matlab_model.ps1 can automate the MATLAB phase, or continue the manifest manually from the live MATLAB session."
        )
    } else {
        $lines += @(
            "Recovery:",
            "1. Stay in the current Codex conversation for this workspace.",
            "2. Run the requested MATLAB phase from the live MATLAB session.",
            "3. Use the formal model run.ps1 entrypoint when you want the shell to automate the MATLAB phase."
        )
    }

    return ($lines -join [Environment]::NewLine)
}

function Write-CodexMatlabLogStub {
    param(
        [string]$LogPath = "",
        [string]$MainFunction = "",
        [string[]]$FunctionArgs = @(),
        [object]$SessionStatus = $null,
        [switch]$BridgeUnavailable,
        [string]$ManifestPath = "",
        [string]$StatusPath = ""
    )

    if ([string]::IsNullOrWhiteSpace($LogPath)) {
        return
    }

    $logDir = Split-Path -Parent $LogPath
    if (-not [string]::IsNullOrWhiteSpace($logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }

    if ($null -eq $SessionStatus) {
        $SessionStatus = Get-CodexMatlabSessionStatus
    }

    $content = Get-CodexMatlabRequirementMessage `
        -MainFunction $MainFunction `
        -FunctionArgs $FunctionArgs `
        -SessionStatus $SessionStatus `
        -BridgeUnavailable:$BridgeUnavailable `
        -ManifestPath $ManifestPath `
        -StatusPath $StatusPath
    Write-Utf8NoBomFile -Path $LogPath -Content $content
}

function Write-CodexMatlabStatusFile {
    param(
        [Parameter(Mandatory = $true)][string]$StatusPath,
        [Parameter(Mandatory = $true)][ValidateSet("pending", "running", "completed", "failed")][string]$State,
        [string]$ManifestPath = "",
        [string]$EntryFunction = "",
        [string]$LogPath = "",
        [string]$Message = "",
        [string]$ErrorReport = "",
        [object]$SessionStatus = $null
    )

    $statusDir = Split-Path -Parent $StatusPath
    if (-not [string]::IsNullOrWhiteSpace($statusDir)) {
        New-Item -ItemType Directory -Force -Path $statusDir | Out-Null
    }

    $payload = [ordered]@{
        status = $State
        updated_at = (Get-Date).ToString("o")
        manifest_path = $ManifestPath
        entry_function = $EntryFunction
        log_path = $LogPath
        message = $Message
    }

    if (-not [string]::IsNullOrWhiteSpace($ErrorReport)) {
        $payload.error_report = $ErrorReport
    }
    if ($null -ne $SessionStatus) {
        $payload.session = $SessionStatus
    }

    Write-JsonUtf8NoBomFile -Path $StatusPath -Data $payload
}

function New-CodexMatlabHandoffManifest {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$EntryFunction,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [string]$ModelLine = "",
        [string]$ModelId = "",
        [string]$ConfigPath = "",
        [string]$MphPath = "",
        [string]$LogPath = "",
        [string]$StatusPath = "",
        [string[]]$FunctionArgs = @(),
        [string]$BuildWallclockSeconds = "",
        [string]$SourceScript = "",
        [string]$InvokeStyle = "manifest_path",
        [hashtable]$ExtraFields = @{}
    )

    $manifestDir = Split-Path -Parent $ManifestPath
    if (-not [string]::IsNullOrWhiteSpace($manifestDir)) {
        New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
    }

    $payload = [ordered]@{
        manifest_version = 1
        created_at = (Get-Date).ToString("o")
        project_root = $ProjectRoot
        matlab_project_root = (Join-Path $ProjectRoot "matlab")
        source_script = $SourceScript
        model_line = $ModelLine
        model_id = $ModelId
        entry_function = $EntryFunction
        invoke_style = $InvokeStyle
        output_root = $OutputRoot
        config_path = $ConfigPath
        mph_path = $MphPath
        log_path = $LogPath
        status_path = $StatusPath
        function_args = @($FunctionArgs)
        build_wallclock_s = $BuildWallclockSeconds
    }

    foreach ($key in $ExtraFields.Keys) {
        $payload[$key] = $ExtraFields[$key]
    }

    Write-JsonUtf8NoBomFile -Path $ManifestPath -Data $payload
    return $payload
}

function Assert-CodexMatlabSession {
    param(
        [string]$MainFunction = "",
        [string[]]$FunctionArgs = @(),
        [string]$LogPath = ""
    )

    $status = Get-CodexMatlabSessionStatus
    if ($status.session_detected) {
        return
    }

    Write-CodexMatlabLogStub -LogPath $LogPath -MainFunction $MainFunction -FunctionArgs $FunctionArgs -SessionStatus $status
    throw (Get-CodexMatlabRequirementMessage -MainFunction $MainFunction -FunctionArgs $FunctionArgs -SessionStatus $status)
}

function Set-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    } else {
        $prop.Value = $Value
    }
}

function Get-OrCreateChildObject {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) {
        $child = [pscustomobject]@{}
        Set-ObjectPropertyValue -Object $Object -Name $Name -Value $child
        return $child
    }

    return $prop.Value
}

function Get-LinearQualityProfile {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("base", "impact_response", "acoustic_field", "acoustic_field_3d_air")][string]$ModelId,
        [Parameter(Mandatory = $true)][ValidateSet("coarse", "medium", "full")][string]$Quality
    )

    switch ("${ModelId}::${Quality}") {
        "base::full" {
            return [ordered]@{
                quality = "full"
                mesh_numelem = 120
                mode_points = 241
                time_end = "1[s]"
                time_step = "1e-4[s]"
            }
        }
        "base::medium" {
            return [ordered]@{
                quality = "medium"
                mesh_numelem = 90
                mode_points = 161
                time_end = "0.5[s]"
                time_step = "2e-4[s]"
            }
        }
        "base::coarse" {
            return [ordered]@{
                quality = "coarse"
                mesh_numelem = 40
                mode_points = 61
                time_end = "0.10[s]"
                time_step = "1e-3[s]"
            }
        }
        "impact_response::full" {
            return [ordered]@{
                quality = "full"
                mesh_numelem = 160
                mode_points = 241
                time_end = "1[s]"
                time_step = "1e-4[s]"
            }
        }
        "impact_response::medium" {
            return [ordered]@{
                quality = "medium"
                mesh_numelem = 120
                mode_points = 161
                time_end = "0.5[s]"
                time_step = "2e-4[s]"
            }
        }
        "impact_response::coarse" {
            return [ordered]@{
                quality = "coarse"
                mesh_numelem = 50
                mode_points = 61
                time_end = "0.10[s]"
                time_step = "1e-3[s]"
            }
        }
        "acoustic_field::full" {
            return [ordered]@{
                quality = "full"
                mesh_numelem = 160
                mode_points = 241
                time_end = "1[s]"
                time_step = "1e-4[s]"
            }
        }
        "acoustic_field::medium" {
            return [ordered]@{
                quality = "medium"
                mesh_numelem = 120
                mode_points = 161
                time_end = "0.5[s]"
                time_step = "2e-4[s]"
            }
        }
        "acoustic_field::coarse" {
            return [ordered]@{
                quality = "coarse"
                mesh_numelem = 50
                mode_points = 61
                time_end = "0.05[s]"
                time_step = "5e-5[s]"
            }
        }
        "acoustic_field_3d_air::full" {
            return [ordered]@{
                quality = "full"
                mesh_numelem = 120
                mode_points = 241
                time_end = "1[s]"
                time_step = "1e-4[s]"
            }
        }
        "acoustic_field_3d_air::medium" {
            return [ordered]@{
                quality = "medium"
                mesh_numelem = 80
                mode_points = 161
                time_end = "0.5[s]"
                time_step = "2e-4[s]"
            }
        }
        "acoustic_field_3d_air::coarse" {
            return [ordered]@{
                quality = "coarse"
                mesh_numelem = 40
                mode_points = 81
                time_end = "0.10[s]"
                time_step = "1e-4[s]"
            }
        }
        default {
            throw "Unsupported linear quality profile: $ModelId / $Quality"
        }
    }
}

function New-ResolvedLinearConfig {
    param(
        [Parameter(Mandatory = $true)][object]$Config,
        [Parameter(Mandatory = $true)][ValidateSet("base", "impact_response", "acoustic_field", "acoustic_field_3d_air")][string]$ModelId,
        [Parameter(Mandatory = $true)][ValidateSet("coarse", "medium", "full")][string]$Quality,
        [switch]$HonorConfigOverrides
    )

    $profile = Get-LinearQualityProfile -ModelId $ModelId -Quality $Quality
    $resolved = $Config | ConvertTo-Json -Depth 64 | ConvertFrom-Json

    $studies = Get-OrCreateChildObject -Object $resolved -Name "studies"
    $configStudies = $null
    $configStudiesProp = $Config.PSObject.Properties["studies"]
    if ($null -ne $configStudiesProp) {
        $configStudies = $configStudiesProp.Value
    }
    if (-not $HonorConfigOverrides -or $null -eq $configStudies -or $null -eq $configStudies.PSObject.Properties["time_end"]) {
        Set-ObjectPropertyValue -Object $studies -Name "time_end" -Value $profile.time_end
    }
    if (-not $HonorConfigOverrides -or $null -eq $configStudies -or $null -eq $configStudies.PSObject.Properties["time_step"]) {
        Set-ObjectPropertyValue -Object $studies -Name "time_step" -Value $profile.time_step
    }
    if (-not $HonorConfigOverrides -or $null -eq $configStudies -or $null -eq $configStudies.PSObject.Properties["mode_points"]) {
        Set-ObjectPropertyValue -Object $studies -Name "mode_points" -Value $profile.mode_points
    }

    $mesh = Get-OrCreateChildObject -Object $resolved -Name "mesh"
    $configMesh = $null
    $configMeshProp = $Config.PSObject.Properties["mesh"]
    if ($null -ne $configMeshProp) {
        $configMesh = $configMeshProp.Value
    }
    if (-not $HonorConfigOverrides -or $null -eq $configMesh -or $null -eq $configMesh.PSObject.Properties["numelem"]) {
        Set-ObjectPropertyValue -Object $mesh -Name "numelem" -Value $profile.mesh_numelem
    }

    $execution = Get-OrCreateChildObject -Object $resolved -Name "execution"
    Set-ObjectPropertyValue -Object $execution -Name "quality" -Value $profile.quality
    Set-ObjectPropertyValue -Object $execution -Name "solve_owner" -Value "java_batch"
    Set-ObjectPropertyValue -Object $execution -Name "run_studies" -Value $false

    return [ordered]@{
        Config = $resolved
        Profile = $profile
    }
}

function Format-SummaryScalar {
    param([object]$Value)

    if ($null -eq $Value) {
        return ""
    }
    if ($Value -is [string]) {
        return $Value
    }
    if ($Value -is [bool]) {
        return $(if ($Value) { "true" } else { "false" })
    }
    if ($Value -is [System.IFormattable]) {
        return $Value.ToString($null, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return [string]$Value
}

function Write-SummaryTextFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Data
    )

    $lines = foreach ($prop in $Data.PSObject.Properties) {
        "{0}: {1}" -f $prop.Name, (Format-SummaryScalar -Value $prop.Value)
    }
    Write-Utf8NoBomFile -Path $Path -Content ($lines -join [Environment]::NewLine)
}

function Initialize-CanonicalOutputRoot {
    param(
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [string]$HistoryBaseDir = "",
        [string[]]$PreserveNames = @()
    )

    $parentDir = Split-Path -Parent $OutputRoot
    if (-not [string]::IsNullOrWhiteSpace($parentDir)) {
        New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
    }

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
        return
    }

    $preserveSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $PreserveNames) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            $null = $preserveSet.Add($name)
        }
    }

    $existing = @(Get-ChildItem -LiteralPath $OutputRoot -Force -ErrorAction SilentlyContinue |
        Where-Object { -not $preserveSet.Contains($_.Name) })
    if ($existing.Count -eq 0) {
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($HistoryBaseDir)) {
        $snapshotDir = Join-Path $HistoryBaseDir (Get-Date -Format "yyyyMMdd_HHmmss")
        New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null
        foreach ($entry in $existing) {
            $destinationPath = Join-Path $snapshotDir $entry.Name
            try {
                Move-Item -LiteralPath $entry.FullName -Destination $destinationPath -Force
                continue
            }
            catch {
                $moveException = $_.Exception
            }

            if (-not $entry.PSIsContainer) {
                Write-Warning ("Could not archive '{0}'. {1}" -f $entry.FullName, $moveException.Message)
                continue
            }

            $lockedChildren = @()
            New-Item -ItemType Directory -Force -Path $destinationPath | Out-Null
            Get-ChildItem -LiteralPath $entry.FullName -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $child = $_
                try {
                    Move-Item -LiteralPath $child.FullName -Destination (Join-Path $destinationPath $child.Name) -Force
                }
                catch {
                    $lockedChildren += $child
                }
            }

            $benignLockedChildren = @($lockedChildren | Where-Object { -not $_.PSIsContainer -and $_.Name -like "*_matlab.log" })
            $significantLockedChildren = @($lockedChildren | Where-Object { $benignLockedChildren -notcontains $_ })
            if ($significantLockedChildren.Count -eq 0 -and $benignLockedChildren.Count -gt 0) {
                continue
            }

            Write-Warning ("Could not fully archive '{0}'. Falling back to best-effort child moves. {1}" -f $entry.FullName, $moveException.Message)
            foreach ($child in $significantLockedChildren) {
                Write-Warning ("Leaving locked path in active output root: {0}" -f $child.FullName)
            }
        }
        return
    }

    foreach ($entry in $existing) {
        Remove-Item -LiteralPath $entry.FullName -Recurse -Force
    }
}

function Resolve-TsrPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$DefaultRelativePath,
        [string]$InputPath = ""
    )

    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        return (Join-Path $RepoRoot $DefaultRelativePath)
    }
    if ([System.IO.Path]::IsPathRooted($InputPath)) {
        return $InputPath
    }
    return (Join-Path $RepoRoot $InputPath)
}

function Remove-TsrPathIfExists {
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$ActionLabel,
        [Parameter(Mandatory = $true)][System.Management.Automation.PSCmdlet]$Cmdlet
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return
    }

    if ($Cmdlet.ShouldProcess($TargetPath, $ActionLabel)) {
        Remove-Item -LiteralPath $TargetPath -Recurse -Force
    }
}

function Invoke-TsrModelClean {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$ModelRoot,
        [Parameter(Mandatory = $true)][string]$DefaultOutputRelativePath,
        [Parameter(Mandatory = $true)][string]$DefaultRuntimeRelativePath,
        [string]$RuntimeRoot = "",
        [Parameter(Mandatory = $true)][System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $targets = @(
        (Join-Path $ModelRoot "artifacts\build\generated"),
        (Resolve-TsrPath -RepoRoot $RepoRoot -DefaultRelativePath $DefaultOutputRelativePath),
        (Resolve-TsrPath -RepoRoot $RepoRoot -DefaultRelativePath $DefaultRuntimeRelativePath -InputPath $RuntimeRoot)
    )

    foreach ($target in $targets) {
        Remove-TsrPathIfExists -TargetPath $target -ActionLabel "Remove generated model content" -Cmdlet $Cmdlet
    }
}

function Get-MatlabStartupErrorPattern {
    return '5006|5013|5201|5202|Fatal Startup Error|File system inconsistency|Unable to access services required to run MATLAB|MathWorks.*service'
}

function Stop-MatlabRelatedProcesses {
    $processNames = @(
        'matlab',
        'MATLAB',
        'MATLABWindow',
        'MathWorksServiceHost',
        'MathWorksServiceHostWindow',
        'MathWorksServiceHost-Monitor',
        'ServiceHost',
        'matlab-mcp-core-server-win64'
    )

    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -in $processNames } |
        Stop-Process -Force -ErrorAction SilentlyContinue

    Start-Sleep -Seconds 2
}

function Invoke-MatlabEnvironmentRepair {
    param(
        [switch]$HardReset
    )

    Stop-MatlabRelatedProcesses

    if (-not $HardReset) {
        return
    }

    Write-Warning 'Hard MATLAB repair is enabled. This may clear cached local services and require sign-in again.'
    $statePaths = @(
        (Join-Path $env:LOCALAPPDATA 'MathWorks\ServiceHost'),
        (Join-Path $env:LOCALAPPDATA 'MathWorks\MATLABConnector')
    )
    foreach ($statePath in $statePaths) {
        if (Test-Path -LiteralPath $statePath) {
            Remove-Item -LiteralPath $statePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-MatlabWarmup {
    param(
        [Parameter(Mandatory = $true)][string]$MatlabExe,
        [string]$LogPath = ''
    )

    try {
        $warmupOutput = & $MatlabExe '-batch' "disp('MATLAB_BOOT_OK');" 2>&1
        if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
            Add-Content -LiteralPath $LogPath -Value '[warmup]'
            foreach ($line in @($warmupOutput)) {
                Add-Content -LiteralPath $LogPath -Value $line
            }
        }
    } catch {
        if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
            Add-Content -LiteralPath $LogPath -Value ('[warmup-error] ' + $_.ToString())
        }
    }
}

function Invoke-MatlabBatchRobust {
    param(
        [Parameter(Mandatory = $true)][string]$MatlabExe,
        [Parameter(Mandatory = $true)][string]$BatchCommand,
        [string]$LogPath = '',
        [int]$MaxAttempts = 7,
        [bool]$WarmupBeforeRetry = $true,
        [bool]$HardRepairOnFailure = $false
    )

    if ($MaxAttempts -lt 1) {
        $MaxAttempts = 1
    }

    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $logDir = Split-Path -Parent $LogPath
        if (-not [string]::IsNullOrWhiteSpace($logDir)) {
            New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        }
    }

    $lastText = ''
    $lastExitCode = 1
    $startupPattern = Get-MatlabStartupErrorPattern

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (-not [string]::IsNullOrWhiteSpace($LogPath) -and (Test-Path -LiteralPath $LogPath)) {
            Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue
        }

        Write-Host ("==> MATLAB attempt {0}/{1}" -f $attempt, $MaxAttempts)
        $invokeFailed = $false
        try {
            if ([string]::IsNullOrWhiteSpace($LogPath)) {
                $output = @(& $MatlabExe '-batch' $BatchCommand 2>&1)
                foreach ($line in $output) { Write-Host $line }
            } else {
                $output = @(& $MatlabExe '-batch' $BatchCommand 2>&1 | Tee-Object -FilePath $LogPath)
            }
        } catch {
            $invokeFailed = $true
            $output = @($_.ToString())
            if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
                Set-Content -LiteralPath $LogPath -Value ($output -join [Environment]::NewLine) -Encoding UTF8
            }
        }

        $lastExitVar = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
        if ($null -ne $lastExitVar) {
            $lastExitCode = [int]$lastExitVar.Value
        } elseif ($invokeFailed) {
            $lastExitCode = 1
        } else {
            $lastExitCode = 0
        }
        if ($invokeFailed -and $lastExitCode -eq 0) {
            $lastExitCode = 1
        }

        if ([string]::IsNullOrWhiteSpace($LogPath)) {
            $lastText = (($output | ForEach-Object { $_.ToString() }) -join "`n")
        } elseif (Test-Path -LiteralPath $LogPath) {
            $lastText = (Get-Content -LiteralPath $LogPath -Raw -ErrorAction SilentlyContinue)
        } else {
            $lastText = (($output | ForEach-Object { $_.ToString() }) -join "`n")
        }

        if ($lastExitCode -eq 0) {
            return
        }

        $isStartupFailure = ($lastText -match $startupPattern) -or ($lastExitCode -eq -1)
        if (($attempt -ge $MaxAttempts) -or (-not $isStartupFailure)) {
            break
        }

        $useHardRepair = $HardRepairOnFailure -and ($attempt -ge 2)
        if ($useHardRepair) {
            Write-Warning 'MATLAB startup retry is escalating to hard repair.'
        } else {
            Write-Warning 'MATLAB startup failed. Applying soft repair and retrying.'
        }

        Invoke-MatlabEnvironmentRepair -HardReset:$useHardRepair
        if ($WarmupBeforeRetry) {
            Invoke-MatlabWarmup -MatlabExe $MatlabExe -LogPath $LogPath
            Start-Sleep -Seconds 2
        }
    }

    throw "MATLAB batch command failed with exit code $lastExitCode. Log: $LogPath"
}
