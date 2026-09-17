# Requires: PowerShell 7+, network access to GitHub Releases
param(
    [Parameter(Mandatory = $true)][string]$Version
)

$ErrorActionPreference = "Stop"
$tag = "v$Version"
$base = "https://github.com/dev-centr/ibex-install-builder/releases/download/$tag"
$asset = "ibex-windows-amd64.exe"
$url = "$base/$asset"
$tmp = Join-Path $env:TEMP $asset
Write-Host "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $tmp
$hash = (Get-FileHash -Algorithm SHA256 $tmp).Hash.ToLowerInvariant()
Write-Host "SHA256: $hash"

$installer = Join-Path $PSScriptRoot "DevCentr.Ibex.installer.yaml"
$text = Get-Content -Raw $installer
$text = $text -replace 'PackageVersion: .*', "PackageVersion: $Version"
$text = $text -replace 'InstallerUrl: .*', "InstallerUrl: $url"
$text = $text -replace 'InstallerSha256: .*', "InstallerSha256: $hash"
Set-Content -Path $installer -Value $text -NoNewline

foreach ($f in @(
    "DevCentr.Ibex.yaml",
    "DevCentr.Ibex.locale.en-US.yaml"
)) {
    $p = Join-Path $PSScriptRoot $f
    $t = Get-Content -Raw $p
    $t = $t -replace 'PackageVersion: .*', "PackageVersion: $Version"
    Set-Content -Path $p -Value $t -NoNewline
}

Write-Host "Updated manifests in $PSScriptRoot"
Write-Host "Next: fork microsoft/winget-pkgs and copy to manifests/d/DevCentr/Ibex/$Version/"
