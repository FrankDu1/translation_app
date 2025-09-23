@echo off 
cd /d "D:\offerdataplatform\document-translator\microservices\services\nmt_service" 
echo 🌐 启动翻译服务 (端口 7020)... 
python -m uvicorn server:app --host 0.0.0.0 --port 7020 --reload 
