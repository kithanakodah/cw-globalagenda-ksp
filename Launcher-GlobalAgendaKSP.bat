@echo off
REM ===========================================================================
REM  Global Agenda KSP - Launcher
REM  Double-click this file to open the launcher GUI.
REM
REM  -ExecutionPolicy Bypass applies to this one process only; it does not
REM  change any system-wide PowerShell setting.
REM ===========================================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0launcher\Launcher-GlobalAgendaKSP.ps1"
