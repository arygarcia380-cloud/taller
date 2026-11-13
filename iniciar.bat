@echo off
rem ============================================================
rem  Taller en Vivo 2.0 - arrancar el servidor y abrir el programa
rem  Requiere: MySQL 8 encendido y haber hecho la instalacion (ver README.md).
rem  Deja abierta la ventana del servidor mientras se usa el programa.
rem ============================================================
cd /d "%~dp0backend"
if not exist ".venv\Scripts\python.exe" (
  echo Falta instalar el entorno de Python. Sigue los pasos de README.md
  pause
  exit /b 1
)
if not exist ".env" (
  echo Falta backend\.env. Ejecuta primero:  .venv\Scripts\python.exe -m app.cli configurar
  pause
  exit /b 1
)
start "Taller en Vivo - servidor (no cerrar)" /min ".venv\Scripts\python.exe" servidor.py
timeout /t 3 /nobreak >nul
start "" "http://localhost:5517/"
