@echo off
setlocal EnableExtensions

if not defined FRAMEWORK_ROOT set "FRAMEWORK_ROOT=%~dp0"
if "%FRAMEWORK_ROOT:~-1%"=="\" set "FRAMEWORK_ROOT=%FRAMEWORK_ROOT:~0,-1%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%FRAMEWORK_ROOT%\scripts\cursor-install.ps1" %*
