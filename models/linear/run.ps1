[CmdletBinding()]
param(
    [ValidateSet("ALL", "base", "impact_response", "acoustic_field", "acoustic_field_3d_air")]
    [string]$Model = "ALL",
    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "full",
    [string]$BaseConfigPath = "",
    [string]$ImpactConfigPath = "",
    [string]$AcousticConfigPath = "",
    [string]$Acoustic3DAirConfigPath = "",
    [string]$ComsolBin = $env:COMSOL_BIN,
    [string]$RuntimeRoot = "",
    [ValidateRange(0, 65535)]
    [int]$LocalComsolPort = 0,
    [switch]$SkipMatlabPostprocess
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SubRuntime {
    param(
        [string]$Root,
        [string]$Leaf
    )
    if ([string]::IsNullOrWhiteSpace($Root)) {
        return ""
    }
    if ([System.IO.Path]::IsPathRooted($Root)) {
        return (Join-Path $Root $Leaf)
    }
    return (Join-Path $Root $Leaf)
}

$targets = switch ($Model) {
    "ALL" { @("base", "impact_response", "acoustic_field") }
    default { @($Model) }
}

foreach ($target in $targets) {
    switch ($target) {
        "base" {
            & (Join-Path $PSScriptRoot "base\run.ps1") -ConfigPath $BaseConfigPath -Quality $Quality -ComsolBin $ComsolBin -RuntimeRoot (Get-SubRuntime -Root $RuntimeRoot -Leaf "base") -LocalComsolPort $LocalComsolPort -SkipMatlabPostprocess:$SkipMatlabPostprocess
        }
        "impact_response" {
            & (Join-Path $PSScriptRoot "impact_response\run.ps1") -ConfigPath $ImpactConfigPath -Quality $Quality -ComsolBin $ComsolBin -RuntimeRoot (Get-SubRuntime -Root $RuntimeRoot -Leaf "impact_response") -LocalComsolPort $LocalComsolPort -SkipMatlabPostprocess:$SkipMatlabPostprocess
        }
        "acoustic_field" {
            & (Join-Path $PSScriptRoot "acoustic_field\run.ps1") -ConfigPath $AcousticConfigPath -Quality $Quality -ComsolBin $ComsolBin -RuntimeRoot (Get-SubRuntime -Root $RuntimeRoot -Leaf "acoustic_field") -LocalComsolPort $LocalComsolPort -SkipMatlabPostprocess:$SkipMatlabPostprocess
        }
        "acoustic_field_3d_air" {
            & (Join-Path $PSScriptRoot "acoustic_field_3d_air\run.ps1") -ConfigPath $Acoustic3DAirConfigPath -Quality $Quality -ComsolBin $ComsolBin -RuntimeRoot (Get-SubRuntime -Root $RuntimeRoot -Leaf "acoustic_field_3d_air") -LocalComsolPort $LocalComsolPort -SkipMatlabPostprocess:$SkipMatlabPostprocess
        }
    }
}
