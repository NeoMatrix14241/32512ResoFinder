@echo off
title Ang ayaw ma ocr finder kasi malaki size
setlocal

echo Current Date and Time: %DATE% %TIME%
echo Current User's Login: %USERNAME%
echo.

REM Prompt for configuration values
set /p sourceFolder="Enter the source folder path: "
set /p destinationFolder="Enter the destination folder path: "

REM Launch PowerShell script with configuration
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {Set-Location '%~dp0'; & '.\AnalyzeLargeTiffImages.ps1' -sourceFolder '%sourceFolder%' -destinationFolder '%destinationFolder%' -maxConcurrentJobs 12}"

echo.
echo Processing completed at: %DATE% %TIME%
pause
endlocal