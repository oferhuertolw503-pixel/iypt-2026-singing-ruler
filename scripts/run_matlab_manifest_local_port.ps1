[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [int]$Port = 2038,

    [string]$LocalPorts = "",

    [string]$ComsolBin = $env:COMSOL_BIN,

    [string]$MatlabExe = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "comsol_common.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedManifestPath = Resolve-OptionalPath -InputPath $ManifestPath -DefaultPath $ManifestPath -BaseDir $repoRoot
$resolvedMatlabExe = Resolve-MatlabExe -InputPath $MatlabExe
$resolvedComsolBin = Resolve-ComsolBin -InputPath $ComsolBin
$sharedComsolState = Get-LocalComsolServerState -Port $Port -ProjectRoot $repoRoot

if (-not (Test-ListeningPort -TargetPort $Port)) {
    Write-Host "==> Starting local COMSOL server on port $Port"
    Start-LocalComsolMphServer -ComsolBin $resolvedComsolBin -Port $Port -State $sharedComsolState | Out-Null
} else {
    Write-Host "==> Reusing local COMSOL server on port $Port"
}

$portsText = if ([string]::IsNullOrWhiteSpace($LocalPorts)) {
    "$Port,2036"
} else {
    $LocalPorts
}

$env:TSR_PROJECT_ROOT = $repoRoot
$env:TSR_COMSOL_MODE = "local_port"
$env:TSR_COMSOL_LOCAL_PORTS = $portsText
$sharedEnv = Get-ComsolRuntimeEnvironmentMap -State $sharedComsolState
foreach ($key in $sharedEnv.Keys) {
    [System.Environment]::SetEnvironmentVariable($key, [string]$sharedEnv[$key], "Process")
}

$matlabManifestPath = $resolvedManifestPath.Replace('\', '/')
$matlabCommand = "repo_root=getenv('TSR_PROJECT_ROOT'); cd(repo_root); addpath(genpath(fullfile(repo_root,'matlab'))); run_matlab_manifest('$matlabManifestPath');"

Write-Host "==> Running MATLAB manifest through local_port mode"
& $resolvedMatlabExe -batch $matlabCommand
if ($LASTEXITCODE -ne 0) {
    throw "MATLAB manifest execution failed with exit code $LASTEXITCODE"
}

Write-Host "==> Completed local_port manifest run: $resolvedManifestPath"
