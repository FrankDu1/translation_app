@echo off 
cd /d "D:\offerdataplatform\document-translator\microservices\services\orchestrator"   
echo 🎭 启动编排服务 (端口 8000)... 
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload 
