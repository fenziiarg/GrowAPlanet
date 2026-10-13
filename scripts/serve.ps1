param([switch]$Development, [ValidateRange(1024, 65535)][int]$Port = 34872)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$project = if ($Development) { 'dev.project.json' } else { 'default.project.json' }
& rojo serve $project --address 127.0.0.1 --port $Port
if ($LASTEXITCODE -ne 0) { throw 'Rojo failed' }
