# ==============================================================================
# LogiTech Pro - Secure Windows Desktop Release Build Script (PowerShell)
#
# Features:
# - Code Obfuscation (--obfuscate)
# - Symbol Stripping (--split-debug-info)
# ==============================================================================

Write-Host "[1/3] Cleaning previous build cache..." -ForegroundColor Cyan
flutter clean

Write-Host "[2/3] Fetching dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "[3/3] Building Obfuscated Windows Release Binary..." -ForegroundColor Cyan
flutter build windows --release --obfuscate --split-debug-info=build/windows/symbols

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==============================================================================" -ForegroundColor Green
    Write-Host "[SUCCESS] Secure Windows build completed successfully!" -ForegroundColor Green
    Write-Host "Output directory: build\windows\x64\runner\Release\" -ForegroundColor Green
    Write-Host "Debug symbols saved to: build\windows\symbols\" -ForegroundColor Green
    Write-Host "==============================================================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[ERROR] Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}
