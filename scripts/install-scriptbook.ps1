# Bootstrap Scriptbook without requiring Scriptbook.
# Used by `ibex plugins install-scriptbook` and as a reusable installer for other apps.
$ErrorActionPreference = "Stop"

function Find-Scriptbook {
    $cmd = Get-Command scriptbook -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $local = Join-Path $env:LOCALAPPDATA "ibex\bin\scriptbook.exe"
    if (Test-Path $local) { return $local }
    return $null
}

$existing = Find-Scriptbook
if ($existing) {
    Write-Output "Scriptbook already at $existing"
    exit 0
}

$dest = Join-Path $env:LOCALAPPDATA "ibex\bin"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$target = Join-Path $dest "scriptbook.exe"

$repoRoot = Split-Path $PSScriptRoot -Parent
$siblingCli = Join-Path $repoRoot "..\scriptbook\cli"
if (Test-Path (Join-Path $siblingCli "dub.json")) {
    Write-Output "Building Scriptbook from sibling checkout..."
    Push-Location $siblingCli
    try {
        dub build --build=release
    } finally {
        Pop-Location
    }
    $built = Join-Path $siblingCli "bin\scriptbook.exe"
    if (Test-Path $built) {
        Copy-Item -Force $built $target
        Write-Output "Installed $target"
        Write-Output "Add to PATH: ibex inplace-path add `"$dest`""
        exit 0
    }
}

if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Output "Downloading Scriptbook release..."
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("scriptbook-" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Push-Location $tmp
    try {
        gh release download -R dev-centr/scriptbook -p "scriptbook-windows-x86_64.zip" --clobber
        Expand-Archive -Force "scriptbook-windows-x86_64.zip" -DestinationPath $tmp
        $exe = Get-ChildItem -Recurse -Filter "scriptbook*.exe" | Select-Object -First 1
        if (-not $exe) { throw "No scriptbook.exe in release zip." }
        Copy-Item -Force $exe.FullName $target
    } finally {
        Pop-Location
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
    Write-Output "Installed $target"
    Write-Output "Add to PATH: ibex inplace-path add `"$dest`""
    exit 0
}

Write-Error @"
Could not install Scriptbook.
- Clone https://github.com/dev-centr/scriptbook next to ibex-install-builder and install DUB, or
- Install GitHub CLI (gh) and re-run, or
- Download https://github.com/dev-centr/scriptbook/releases
"@
exit 1
