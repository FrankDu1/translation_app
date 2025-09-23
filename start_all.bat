@echo off
echo =========================================
echo   微服务架构启动助手 (Windows版)
echo =========================================
echo.

set "SERVICES_DIR=%~dp0services"

:: 检查Python是否可用
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python未安装或不在PATH中
    pause
    exit /b 1
)

:: 检查依赖
echo 📦 检查Python依赖...
python -c "import fastapi, uvicorn" >nul 2>&1
if errorlevel 1 (
    echo ⚠️ 缺少必要依赖，开始安装...
    pip install fastapi uvicorn httpx python-multipart pydantic pillow
    echo.
)

:: 检查Ollama
echo 🔍 检查Ollama服务...
curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo ⚠️ Ollama服务未运行，翻译将使用占位模式
) else (
    echo ✅ Ollama服务运行正常
)

echo.
echo 🚀 启动微服务...
echo.

:: 设置环境变量
set OCR_URL=http://localhost:7010/ocr
set TRANSLATE_URL=http://localhost:7020/translate
set OLLAMA_HOST=http://localhost:11434
set OLLAMA_MODEL=llama3:7b
set USE_OLLAMA=true
set DEBUG=true

:: 创建启动批处理文件
echo @echo off > start_ocr.bat
echo cd /d "%SERVICES_DIR%\ocr_service" >> start_ocr.bat
echo echo 🔍 启动OCR服务 (端口 7010)... >> start_ocr.bat
echo python -m uvicorn server:app --host 0.0.0.0 --port 7010 --reload >> start_ocr.bat

echo @echo off > start_nmt.bat
echo cd /d "%SERVICES_DIR%\nmt_service" >> start_nmt.bat
echo echo 🌐 启动翻译服务 (端口 7020)... >> start_nmt.bat
echo python -m uvicorn server:app --host 0.0.0.0 --port 7020 --reload >> start_nmt.bat

echo @echo off > start_orchestrator.bat
echo cd /d "%SERVICES_DIR%\orchestrator" >> start_orchestrator.bat  
echo echo 🎭 启动编排服务 (端口 8000)... >> start_orchestrator.bat
echo python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload >> start_orchestrator.bat

:: 启动服务（新窗口）
echo 📂 在新窗口启动各服务...
start "OCR Service" cmd /k start_ocr.bat
timeout /t 2 >nul

start "NMT Service" cmd /k start_nmt.bat  
timeout /t 2 >nul

start "Orchestrator" cmd /k start_orchestrator.bat
timeout /t 3 >nul

echo.
echo ✨ 所有服务已启动！
echo.
echo 📡 服务地址:
echo   - OCR Service:    http://localhost:7010/health
echo   - NMT Service:    http://localhost:7020/health  
echo   - Orchestrator:   http://localhost:8000/health
echo   - API文档:        http://localhost:8000/docs
echo.
echo 🧪 测试命令:
echo   python test_microservices.py --test-apis
echo.
echo 按任意键测试API...
pause >nul

:: 测试API
python test_microservices.py --test-apis

echo.
echo 🎉 微服务架构启动完成！
echo 📝 查看日志请关注各个服务窗口
echo 🛑 停止服务请关闭对应的命令行窗口
echo.
pause