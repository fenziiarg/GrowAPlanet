$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$env:WALLY_HOME = Join-Path $PWD '.tools/wally'
New-Item -ItemType Directory -Force '.tools' | Out-Null
& wally install
if ($LASTEXITCODE -ne 0) { throw 'Wally failed' }
$url = 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau'
Invoke-WebRequest $url -OutFile '.tools/globalTypes.d.luau'
$expected = '2857EFA8245485F8C25C19C018EE1EF9B46AFAB4EFD2EA70FC3257CD3FAF7080'
if ((Get-FileHash '.tools/globalTypes.d.luau').Hash -ne $expected) { throw 'Roblox definitions hash mismatch' }
