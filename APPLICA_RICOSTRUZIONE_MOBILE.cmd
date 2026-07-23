@echo off
chcp 65001 >nul
color 0A
title Arte In Ferro - Ricostruzione mobile integrata
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
    py -3 apply_mobile_rebuild.py
) else (
    python apply_mobile_rebuild.py
)

echo.
if errorlevel 1 (
    color 0C
    echo OPERAZIONE NON COMPLETATA.
) else (
    echo OPERAZIONE COMPLETATA.
)
echo.
pause
