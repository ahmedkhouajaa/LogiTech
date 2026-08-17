@echo off
REM ==============================================================================
REM LogiTech Pro - Secure Windows Desktop Release Build Script
REM
REM Features:
REM - Code Obfuscation (--obfuscate)
REM - Symbol Stripping (--split-debug-info)
REM - Tree Shaking & High Performance Optimization
REM ==============================================================================

echo [1/3] Cleaning previous build cache...
call flutter clean

echo [2/3] Fetching dependencies...
call flutter pub get

echo [3/3] Building Obfuscated Windows Release Binary...
call flutter build windows --release --obfuscate --split-debug-info=build\windows\symbols

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==============================================================================
    echo [SUCCESS] Secure Windows build completed successfully!
    echo Output directory: build\windows\x64\runner\Release\
    echo Debug symbols saved to: build\windows\symbols\
    echo ==============================================================================
) else (
    echo.
    echo [ERROR] Build failed with exit code %ERRORLEVEL%.
)

pause
