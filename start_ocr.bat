@echo off 
cd /d "D:\offerdataplatform\document-translator\microservices\services\ocr_service" 
echo 🔍 启动OCR服务 (端口 7010)... 
python -m uvicorn server:app --host 0.0.0.0 --port 7010 --reload 
