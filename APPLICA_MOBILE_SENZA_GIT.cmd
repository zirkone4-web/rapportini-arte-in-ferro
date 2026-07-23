@echo off
chcp 65001 >nul
title Arte In Ferro - Ricostruzione mobile senza Git e senza Python
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply_mobile_rebuild_no_git.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
  color 0C
  echo OPERAZIONE NON COMPLETATA.
) else (
  color 0A
  echo OPERAZIONE COMPLETATA.
  echo Torna in GitHub Desktop: vedrai le modifiche reali dell'app mobile.
)
echo.
pause
exit /b %RESULT%
