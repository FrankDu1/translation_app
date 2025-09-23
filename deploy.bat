# Document Translator - 微服务部署 (Windows批处理)
# 简单的一键启动脚本

@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo.
    echo 🚀 Document Translator 微服务部署
    echo.
    echo ⚡ 快速命令:
    echo   git-init     - 初始化Git仓库
    echo   dev          - 开发环境
    echo   gpu          - GPU环境
    echo   test         - 快速测试
    echo   status       - 服务状态
    echo.
    echo 📋 详细帮助: .\deploy.ps1 help
    goto :eof
)

set COMMAND=%~1

if "%COMMAND%"=="git-init" goto git_init
if "%COMMAND%"=="dev" goto dev_mode
if "%COMMAND%"=="gpu" goto gpu_mode
if "%COMMAND%"=="test" goto test_api
if "%COMMAND%"=="status" goto check_status

echo ❌ 未知命令: %COMMAND%
goto :eof

:git_init
echo 📂 初始化Git仓库...
if not exist ".git" (
    git init
    git add .
    git commit -m "Initial microservices architecture"
    echo ✅ Git仓库初始化完成
    echo 💡 请添加远程仓库: git remote add origin ^<your-repo-url^>
) else (
    echo ✅ Git仓库已存在
)
goto :eof

:dev_mode
echo 🏗️ 启动开发环境...
echo 📋 启动编排服务...
start "Orchestrator" cmd /k "cd services\orchestrator && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
timeout /t 3 >nul
echo 📁 启动文件服务...
start "File Service" cmd /k "cd services\file-service && uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload"
echo ✅ 开发服务已启动
echo 🔗 访问地址: http://localhost:8000/docs
goto :eof

:gpu_mode
echo 🎮 启动GPU服务...
echo 🤖 启动OCR服务...
start "OCR Service" cmd /k "cd services\ocr-service && uvicorn app.main:app --host 0.0.0.0 --port 7010 --reload"
timeout /t 3 >nul
echo 🔤 启动翻译服务...
start "NMT Service" cmd /k "cd services\nmt-service && uvicorn app.main:app --host 0.0.0.0 --port 7020 --reload"
echo ✅ GPU服务已启动
goto :eof

:test_api
echo 🧪 快速API测试...
curl -s http://localhost:8000/health && echo ✅ API正常 || echo ❌ API异常
goto :eof

:check_status
echo 📊 检查服务状态...
curl -s http://localhost:8000/health > nul && echo Orchestrator: ✅ || echo Orchestrator: ❌
curl -s http://localhost:8010/health > nul && echo File Service: ✅ || echo File Service: ❌
goto :eof