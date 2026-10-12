param([switch]$Development)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$project = if ($Development) { 'dev.project.json' } else { 'default.project.json' }
& rojo serve $project --address 127.0.0.1 --port 34872
if ($LASTEXITCODE -ne 0) { throw 'Rojo failed' }
