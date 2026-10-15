@echo off
title LogiTech ERP - Service IA Extraction
color 0B
echo ========================================================
echo   LogiTech ERP - Demarrage du Service d'Extraction IA
echo ========================================================
echo.
cd /d "%~dp0"

echo [1/2] Verification des dependances Python...
python -m pip install -q -r requirements.txt

echo.
echo [2/2] Lancement du microservice FastAPI sur le port 8000...
echo   - Local:      http://localhost:8000
echo   - Swagger UI: http://localhost:8000/docs
echo   - Reseau:     http://0.0.0.0:8000
echo.
echo Pour configurer le modele IA de votre ami, modifiez le fichier .env
echo Appuyez sur Ctrl+C pour arreter le service.
echo ========================================================
echo.

python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
pause
