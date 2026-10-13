$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Invoke-Check([string]$Tool, [string[]]$Arguments) {
    & $Tool @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Tool failed ($LASTEXITCODE)" }
}
New-Item -ItemType Directory -Force 'build' | Out-Null
Invoke-Check 'stylua' @('--check', 'src', 'tests')
Invoke-Check 'selene' @('src', 'tests')
Invoke-Check 'rojo' @('sourcemap', 'dev.project.json', '--output', 'sourcemap.json')
Invoke-Check 'luau-lsp' @('analyze', '--definitions=.tools/globalTypes.d.luau', '--sourcemap=sourcemap.json', '--ignore=**/vendor/**', '--ignore=**/DevPackages/**', 'src', 'tests')
Invoke-Check 'rojo' @('build', 'default.project.json', '--output', 'build/GrowAPlanet.rbxlx')
Invoke-Check 'rojo' @('build', 'dev.project.json', '--output', 'build/GrowAPlanet-Dev.rbxl')
[xml]$release = Get-Content 'build/GrowAPlanet.rbxlx' -Raw
$scripts = @($release.SelectNodes('//Item[@class="Script" or @class="LocalScript"]'))
if ($scripts.Count -ne 2) { throw 'Expected server and client entry points only' }
$testModules = @($release.SelectNodes('//string[@name="Name" and (text()="TestEZ" or text()="GrowAPlanetPipeline" or text()="GrowAPlanetClientDebug" or text()="Debug" or text()="Specs")]'))
if ($testModules.Count -ne 0) { throw 'Development test content leaked into release' }
if ((Get-FileHash 'vendor/ProfileStore/ProfileStore.luau').Hash -ne 'AD43737203688B8E88CAB34EBE8C483000C157E53BFB41E35F1B49EE89D0C95F') { throw 'ProfileStore source changed' }
Write-Output 'CHECKS_PASS: formatting, lint, types, both builds, release isolation, vendor hash'
