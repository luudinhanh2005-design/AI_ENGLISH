@echo off
chcp 65001 >nul
title EnglishAI - Run on real phone
setlocal

set "PS_ARGS=%*"
set "PS_ARGS=%PS_ARGS:--wifi=-Wifi%"
set "PS_ARGS=%PS_ARGS:--host-ip=-HostIp%"
set "PS_ARGS=%PS_ARGS:--device=-Device%"
set "PS_ARGS=%PS_ARGS:--port=-Port%"
set "PS_ARGS=%PS_ARGS:--no-backend=-NoBackend%"
set "PS_ARGS=%PS_ARGS:--help=-Help%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run_phone.ps1" %PS_ARGS%
if errorlevel 1 pause
