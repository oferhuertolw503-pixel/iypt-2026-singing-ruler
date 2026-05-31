# deploy_to_server.ps1 — Upload project to Linux server and run COMSOL simulation
# Usage: .\deploy_to_server.ps1 [-Quality coarse] [-RunNow] [-Download]
#
# This script:
#   1. Runs Parameter_Resolver locally (generates params_resolved.json + Java injection)
#   2. Uploads the generated Java + scripts to the Linux server
#   3. Optionally triggers COMSOL compilation and batch run
#   4. Optionally downloads results back to local outputs/

[CmdletBinding()]
param(
    [ValidateSet('coarse','medium','full')]
    [string]$Quality = 'coarse',
    [switch]$RunNow,
    [switch]$Download,
    [switch]$Background,
    [string]$Server = 'user@<your-linux-server>',
    [string]$RemoteWorkDir = '~/comsol_work/the_singing_ruler'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

Write-Host "============================================"
Write-Host " Deploy to Linux Server"
Write-Host " Server:  $Server"
Write-Host " Quality: $Quality"
Write-Host "============================================"

# === Step 1: Run local parameter resolution + Java injection ===
Write-Host "`n[1/4] Running local parameter resolution..."
. (Join-Path $PSScriptRoot 'comsol_common.ps1')

$modelDir = Join-Path $repoRoot 'models/linear/acoustic_field_3d_air'
$cfgPath = Join-Path $modelDir 'config/params.json'
$schemaPath = Join-Path $modelDir 'config/params.schema.json'

$config = Read-ParameterConfig -Path $cfgPath -SchemaPath $schemaPath
$resolved = Resolve-Parameters -Config $config -Quality $Quality

# Write params_resolved.json locally
$resolvedPath = Join-Path $repoRoot "runtime/comsol/acoustic_field_3d_air/params_resolved.json"
$resolvedDir = Split-Path $resolvedPath -Parent
$null = New-Item -ItemType Directory -Path $resolvedDir -Force
Write-ParameterResolved -Resolved $resolved -Path $resolvedPath

# Generate Java parameter block and inject
$block = New-ParameterBlock -Resolved $resolved
$generatedDir = Join-Path $repoRoot "runtime/comsol/acoustic_field_3d_air/generated"
$null = New-Item -ItemType Directory -Path $generatedDir -Force
$generatedJava = Join-Path $generatedDir 'Linear_Acoustic_Field_3D_Air.java'
$templatePath = Join-Path $modelDir 'src/Linear_Acoustic_Field_3D_Air.java'
Invoke-ParameterInjection -TemplatePath $templatePath -OutputPath $generatedJava -ParameterBlock $block

Write-Host "       Generated: $generatedJava"

# === Step 2: Create remote directory and upload ===
Write-Host "`n[2/4] Uploading to server..."

# Create remote work directory
ssh -o ServerAliveInterval=30 $Server "mkdir -p $RemoteWorkDir/{data,mph,snapshots,logs}"

# Upload generated Java
scp $generatedJava "${Server}:${RemoteWorkDir}/Linear_Acoustic_Field_3D_Air.java"

# Upload params_resolved.json (for reference)
scp $resolvedPath "${Server}:${RemoteWorkDir}/params_resolved.json"

Write-Host "       Upload complete."

# === Step 3: Optionally compile and run ===
if ($RunNow) {
    Write-Host "`n[3/4] Compiling and running on server..."

    $envSetup = 'export PATH=~/jdk-11.0.27+6/bin:/disk/home/zhangzhenlei/Comsol/comsol61/multiphysics/bin:$PATH'

    if ($Background) {
        # Run in background with nohup
        $remoteCmd = "$envSetup && cd $RemoteWorkDir && comsol compile Linear_Acoustic_Field_3D_Air.java && nohup comsol batch -inputfile Linear_Acoustic_Field_3D_Air.class -outputfile /tmp/acoustic_field_3d_air_${Quality}.mph -batchlog logs/comsol_batch.log > logs/nohup.log 2>&1 &"
        ssh -o ServerAliveInterval=30 $Server $remoteCmd
        Write-Host "       COMSOL batch started in background."
        Write-Host "       Monitor: ssh $Server 'tail -f $RemoteWorkDir/logs/comsol_batch.log'"
    } else {
        # Run interactively (blocks until done)
        $remoteCmd = "$envSetup && cd $RemoteWorkDir && comsol compile Linear_Acoustic_Field_3D_Air.java && comsol batch -inputfile Linear_Acoustic_Field_3D_Air.class -outputfile /tmp/acoustic_field_3d_air_${Quality}.mph -batchlog logs/comsol_batch.log"
        ssh -o ServerAliveInterval=30 $Server $remoteCmd
        Write-Host "       COMSOL batch completed."
    }
} else {
    Write-Host "`n[3/4] Skipped (use -RunNow to compile and run on server)."
    Write-Host "       To run manually:"
    Write-Host "         ssh $Server"
    Write-Host "         export PATH=~/jdk-11.0.27+6/bin:/disk/home/zhangzhenlei/Comsol/comsol61/multiphysics/bin:`$PATH"
    Write-Host "         cd $RemoteWorkDir"
    Write-Host "         comsol compile Linear_Acoustic_Field_3D_Air.java"
    Write-Host "         comsol batch -inputfile Linear_Acoustic_Field_3D_Air.class -outputfile /tmp/acoustic_field_3d_air_${Quality}.mph"
}

# === Step 4: Optionally download results ===
if ($Download) {
    Write-Host "`n[4/4] Downloading results..."
    $localOutput = Join-Path $repoRoot "outputs/linear/acoustic_field_3d_air"
    $null = New-Item -ItemType Directory -Path $localOutput -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $localOutput 'data') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $localOutput 'mph') -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $localOutput 'logs') -Force

    # Download CSV data (from /tmp/siphon_data/ where Java exports)
    scp -r "${Server}:/tmp/siphon_data/*" (Join-Path $localOutput 'data/')
    # Download MPH
    scp "${Server}:/tmp/acoustic_field_3d_air_${Quality}.mph" (Join-Path $localOutput "mph/acoustic_field_3d_air.mph")
    # Download logs
    scp -r "${Server}:${RemoteWorkDir}/logs/*" (Join-Path $localOutput 'logs/')

    Write-Host "       Results downloaded to: $localOutput"
} else {
    Write-Host "`n[4/4] Skipped download (use -Download to fetch results)."
}

Write-Host "`n============================================"
Write-Host " Deployment complete."
Write-Host "============================================"
