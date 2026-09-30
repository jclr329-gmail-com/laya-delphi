@echo off
rem Servidor LAYA con el modelo base multilingue de Hugging Face.
rem LAYA_HOME: carpeta con el entorno virtual (venv) y los modelos.
set "LAYA_HOME=C:\LAYA"

set "LAYA_MODELO_HUB=convaiinnovations/laya-multilingual"
set "LAYA_MODELO_RUTA="
set "LAYA_MODELO_NOMBRE=convaiinnovations/laya-multilingual"
rem 0 la primera vez (descarga el modelo); despues 1
set "LAYA_OFFLINE=1"

rem Preguntas de este modelo (GET /preguntas). Ruta relativa a la carpeta Servidor.
set "LAYA_PREGUNTAS=..\json_maestros\Preguntas_Cliente.json"

cd /d "%~dp0"
"%LAYA_HOME%\venv\Scripts\python.exe" -m uvicorn servidor:app --host 127.0.0.1 --port 8000 --log-config log_config.json
pause
