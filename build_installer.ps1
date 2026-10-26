param(
    [switch]$SkipFlutterBuild = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  ARION DAQ - Windows Installer Builder  " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Locate Inno Setup Compiler (ISCC.exe)
$isccCandidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    (Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)

$isccPath = $null
foreach ($candidate in $isccCandidates) {
    if ($candidate -and (Test-Path $candidate)) {
        $isccPath = $candidate
        break
    }
}

if (-not $isccPath) {
    Write-Error "Inno Setup Compiler (ISCC.exe) was not found. Please install Inno Setup 6."
    exit 1
}

Write-Host "[OK] Found Inno Setup Compiler at: $isccPath" -ForegroundColor Green

# 2. Build Flutter Release (if not skipped)
$projectRoot = $PSScriptRoot
$releaseDir = Join-Path $projectRoot "build\windows\x64\runner\Release"
$exePath = Join-Path $releaseDir "arion_daq.exe"

if (-not $SkipFlutterBuild) {
    Write-Host ""
    Write-Host "[INFO] Running: flutter build windows --release..." -ForegroundColor Yellow
    Push-Location $projectRoot
    try {
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Flutter build failed with exit code $LASTEXITCODE."
            exit $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host ""
    Write-Host "[INFO] Skipping Flutter build as requested." -ForegroundColor Yellow
}

if (-not (Test-Path $exePath)) {
    Write-Error "Executable not found at: $exePath. Ensure the project is built successfully."
    exit 1
}

Write-Host "[OK] Release executable verified: $exePath" -ForegroundColor Green

# 3. Compile Inno Setup Script
$issScript = Join-Path $projectRoot "installer\arion_daq_setup.iss"
if (-not (Test-Path $issScript)) {
    Write-Error "Installer script not found at: $issScript"
    exit 1
}

Write-Host ""
Write-Host "[INFO] Compiling Inno Setup script: $issScript..." -ForegroundColor Yellow
& "$isccPath" "$issScript"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Inno Setup compilation failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

# 4. Verification & Summary
$installersDir = Join-Path $projectRoot "installers"
$installerFiles = Get-ChildItem -Path $installersDir -Filter "*.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending

if ($installerFiles.Count -gt 0) {
    $latestInstaller = $installerFiles[0]
    $sizeMB = [math]::Round($latestInstaller.Length / 1MB, 2)
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "  INSTALLER CREATED SUCCESSFULLY!        " -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "File: $($latestInstaller.FullName)" -ForegroundColor White
    Write-Host "Size: $sizeMB MB" -ForegroundColor White
    Write-Host "Date: $($latestInstaller.LastWriteTime)" -ForegroundColor White
} else {
    Write-Warning "Could not find any output .exe in: $installersDir"
}
