@echo off
echo � 快速重启Orchestrator服务
echo ============================

:: 杀死占用端口8000的进程
echo � 停止现有服务...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000') do (
    taskkill /f /pid %%a >nul 2>&1
)

timeout /t 2 >nul

:: 重新启动服务
echo � 重新启动Orchestrator...
cd services\orchestrator
start "Orchestrator" cmd /k "python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"

echo ✅ 服务已重启
timeout /t 3 >nul

:: 测试健康检查
echo � 测试服务状态...
curl -s http://localhost:8000/health

echo.
echo � 重启完成！
pause