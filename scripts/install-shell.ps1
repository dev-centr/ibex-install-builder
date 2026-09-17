# Register shell integration assets for local testing.
# Prefer built ibex.exe; fall back to transitional easy-installer.exe if present.
$root = Split-Path -Parent $PSScriptRoot
$exe = $null
foreach ($name in @('ibex.exe', 'easy-installer.exe')) {
    $candidate = Join-Path $root $name
    if (Test-Path $candidate) { $exe = $candidate; break }
}
if (-not $exe) {
    Write-Error "Build ibex.exe (or legacy easy-installer.exe) in the repo root first."
    exit 1
}
Write-Host "Using $exe"
# Copy built binary next to shell assets for local modern registration.
Copy-Item -Force $exe (Join-Path $PSScriptRoot 'ibex.exe')
