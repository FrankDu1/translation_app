@echo off
echo =======================================
echo      微服务快速测试
echo =======================================

:: 测试健康检查
echo 🏥 健康检查测试...
echo.

echo 🔍 OCR Service:
curl -s http://localhost:7010/health 2>nul && echo ✅ 正常 || echo ❌ 异常

echo 🌐 NMT Service:  
curl -s http://localhost:7020/health 2>nul && echo ✅ 正常 || echo ❌ 异常

echo 🎭 Orchestrator:
curl -s http://localhost:8000/health 2>nul && echo ✅ 正常 || echo ❌ 异常

echo.
echo 📊 服务状态详情:
curl -s http://localhost:8000/v1/services/status 2>nul

echo.
echo 📖 可用端点:
echo   GET  /health                    - 健康检查
echo   POST /v1/process/image          - 图片翻译  
echo   GET  /v1/services/status        - 服务状态
echo   GET  /docs                      - API文档
echo.
echo 🌐 在浏览器中打开API文档？(y/N)
set /p OPEN_DOCS=
if /i "%OPEN_DOCS%"=="y" start http://localhost:8000/docs

echo.
pause