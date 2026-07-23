@echo off
chcp 65001 >nul
title Arte In Ferro - Ricostruzione mobile senza Python
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply_mobile_rebuild.ps1"
echo.
if errorlevel 1 (
  color 0C
  echo OPERAZIONE NON COMPLETATA.
) else (
  color 0A
  echo OPERAZIONE COMPLETATA.
)
echo.
pause
