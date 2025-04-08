@echo off
echo Windows PATH Repair Tool (2025)
echo Running with administrator privileges...
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Windows-PATH-Repair.ps1\"' -Verb RunAs"
