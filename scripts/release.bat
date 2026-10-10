@echo off
setlocal enabledelayedexpansion

:: Resolve project root directory
cd /d "%~dp0\.."

if not exist pubspec.yaml (
    echo [ERROR] pubspec.yaml not found! Run this script from the project root.
    exit /b 1
)

:: Extract version line from pubspec.yaml
set "VERSION="
for /f "tokens=2 delims=: " %%a in ('findstr /b "version:" pubspec.yaml') do (
    set "VERSION=%%a"
)

if "%VERSION%"=="" (
    echo [ERROR] Could not extract version from pubspec.yaml
    exit /b 1
)

:: Trim quotes or whitespace
set "VERSION=%VERSION:"=%"
set "VERSION=%VERSION:'=%"
set "TAG=v%VERSION%"
set "FORCE_RETRY=0"

if "%1"=="--retry" set "FORCE_RETRY=1"
if "%1"=="--force" set "FORCE_RETRY=1"
if "%1"=="-f" set "FORCE_RETRY=1"

echo [INFO] Target version in pubspec.yaml: %VERSION%
echo [INFO] Release tag: %TAG%

:: Check if tag already exists locally
git rev-parse "%TAG%" >nul 2>&1
if not errorlevel 1 (
    if "!FORCE_RETRY!"=="0" (
        echo.
        echo [WARNING] Tag %TAG% already exists locally or remotely.
        set /p CONFIRM="Would you like to overwrite/re-publish this tag to retry the build? [y/N]: "
        if /i "!CONFIRM!"=="y" (
            set "FORCE_RETRY=1"
        ) else if /i "!CONFIRM!"=="yes" (
            set "FORCE_RETRY=1"
        ) else (
            echo [INFO] Cancelled. Please update the version in pubspec.yaml before releasing.
            exit /b 1
        )
    )

    echo [INFO] Removing existing tag %TAG%...
    git tag -d "%TAG%" >nul 2>&1
    git push origin --delete "%TAG%" >nul 2>&1
)

echo [INFO] Staging and committing changes...
git add .
git commit -m "chore: release %TAG%" --allow-empty
if errorlevel 1 (
    echo [ERROR] Git commit failed.
    exit /b 1
)

git tag "%TAG%"
if errorlevel 1 (
    echo [ERROR] Git tagging failed.
    exit /b 1
)

echo [INFO] Pushing to origin...
git push origin HEAD
if errorlevel 1 (
    echo [ERROR] Failed to push branch to origin.
    exit /b 1
)

git push origin "%TAG%"
if errorlevel 1 (
    echo [ERROR] Failed to push tag %TAG% to origin.
    exit /b 1
)

echo =============================================
echo [SUCCESS] Release %TAG% triggered successfully!
echo GitHub Actions should now build and publish it.
echo =============================================
