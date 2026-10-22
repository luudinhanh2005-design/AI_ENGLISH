@echo off
chcp 65001 >nul
title EnglishAI - All-in-One Startup
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" %*
if errorlevel 1 pause
