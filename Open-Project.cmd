@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build.ps1"
for %%F in ("%~dp0build\*.slnx" "%~dp0build\*.sln") do if exist "%%~fF" start "" "%%~fF" & exit /b 0
exit /b 1

