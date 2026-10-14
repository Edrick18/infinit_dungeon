@echo off
rem Doppelklick: baut build\InfinitDungeon.exe (alles in einer Datei) und
rem packt daneben eine ZIP zum Weitergeben. Braucht die portable Godot-
rem Engine in godot\ und die Export-Vorlagen 4.7 (sind installiert).
setlocal
cd /d "%~dp0"
set GODOT=godot\Godot_v4.7-stable_win64_console.exe

if not exist "%GODOT%" (
    echo Godot nicht gefunden: %GODOT%
    pause
    exit /b 1
)
if not exist build mkdir build

echo [1/3] Importiere Ressourcen ...
"%GODOT%" --headless --path . --import --quit >nul 2>&1

echo [2/3] Baue build\InfinitDungeon.exe ...
"%GODOT%" --headless --path . --export-release "Windows Desktop" build\InfinitDungeon.exe
if errorlevel 1 goto fehler
if not exist build\InfinitDungeon.exe goto fehler

echo [3/3] Packe build\InfinitDungeon.zip ...
powershell -NoProfile -Command "Compress-Archive -Path 'build\InfinitDungeon.exe' -DestinationPath 'build\InfinitDungeon.zip' -Force"

echo.
echo Fertig: build\InfinitDungeon.exe
explorer build
pause
exit /b 0

:fehler
echo.
echo Export fehlgeschlagen - siehe Meldungen oben.
pause
exit /b 1
