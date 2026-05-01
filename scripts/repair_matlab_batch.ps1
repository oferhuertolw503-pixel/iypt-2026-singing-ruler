Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$message = @(
    "repair_matlab_batch.ps1 is deprecated.",
    "This repository no longer supports matlab.exe -batch as a formal execution backend.",
    "Reopen the workspace in VSCode, continue from a Codex Desktop conversation, and use the MATLAB extension session there."
) -join [Environment]::NewLine

throw $message
