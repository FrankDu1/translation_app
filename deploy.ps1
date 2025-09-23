# Document Translator 微服务部署脚本 (Windows PowerShell)
# Git + Docker 双重部署方案

param(
    [Parameter(Mandatory=$true)]
    [string]$Command,
    
    [string]$GpuMachineIP = "192.168.1.100",
    [string]$PostgresPassword = "password",
    [string]$MinioAccessKey = "minioadmin",
    [string]$MinioSecretKey = "minioadmin"
)

function Show-Help {
    Write-Host "🚀 Document Translator 微服务部署命令" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 Git + Docker 部署:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1 git-setup      - 初始化Git仓库"
    Write-Host "  .\deploy.ps1 docker-dev     - Docker启动开发环境"
    Write-Host "  .\deploy.ps1 docker-gpu     - Docker启动GPU服务"
    Write-Host ""
    Write-Host "🏗️ 开发环境:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1 setup-dev      - 设置开发环境"
    Write-Host "  .\deploy.ps1 dev-up         - 开发模式启动"
    Write-Host "  .\deploy.ps1 setup-gpu      - 设置GPU环境"
    Write-Host "  .\deploy.ps1 gpu-dev        - GPU开发模式"
    Write-Host ""
    Write-Host "🧪 测试和监控:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1 test           - 快速API测试"
    Write-Host "  .\deploy.ps1 test-e2e       - 端到端测试"
    Write-Host "  .\deploy.ps1 status         - 检查服务状态"
    Write-Host "  .\deploy.ps1 monitor        - 启动监控服务"
    Write-Host ""
    Write-Host "🔧 工具:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1 clean          - 清理环境"
    Write-Host "  .\deploy.ps1 logs           - 查看日志"
    Write-Host ""
    Write-Host "示例:" -ForegroundColor Cyan
    Write-Host "  .\deploy.ps1 git-setup"
    Write-Host "  .\deploy.ps1 docker-dev -GpuMachineIP 192.168.1.100"
}

function Initialize-GitRepository {
    Write-Host "📂 初始化Git仓库..." -ForegroundColor Green
    
    if (-not (Test-Path ".git")) {
        git init
        
        # 创建.gitignore
        @"
# Python
__pycache__/
*.py[cod]
*.so
.Python
env/
venv/
.venv/
pip-log.txt
pip-delete-this-directory.txt

# Node.js
node_modules/
npm-debug.log*

# Environment
.env*
.DS_Store

# Logs
logs/
*.log

# Temporary files
temp/
*.tmp
*.temp

# Models and data
models/
data/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Docker
.dockerignore

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini
"@ | Out-File -FilePath ".gitignore" -Encoding UTF8
        
        git add .
        git commit -m "Initial microservices architecture"
        
        # 重命名为main分支 (现代Git标准)
        git branch -M main
        
        Write-Host "✅ Git仓库初始化完成" -ForegroundColor Green
        Write-Host "💡 请添加远程仓库: git remote add origin <your-repo-url>" -ForegroundColor Yellow
        Write-Host "💡 然后推送: git push -u origin main" -ForegroundColor Yellow
    } else {
        Write-Host "✅ Git仓库已存在" -ForegroundColor Green
    }
}

function Start-DockerDev {
    Write-Host "🐳 Docker启动开发环境..." -ForegroundColor Green
    
    # 设置环境变量
    $env:GPU_MACHINE_IP = $GpuMachineIP
    $env:POSTGRES_PASSWORD = $PostgresPassword
    $env:MINIO_ACCESS_KEY = $MinioAccessKey
    $env:MINIO_SECRET_KEY = $MinioSecretKey
    
    Write-Host "🔧 环境变量设置:" -ForegroundColor Cyan
    Write-Host "  GPU_MACHINE_IP = $GpuMachineIP"
    Write-Host "  POSTGRES_PASSWORD = $PostgresPassword"
    
    # 检查Docker是否运行
    try {
        docker version | Out-Null
        Write-Host "✅ Docker运行正常" -ForegroundColor Green
    } catch {
        Write-Host "❌ Docker未运行，请启动Docker Desktop" -ForegroundColor Red
        return
    }
    
    # 启动服务
    docker-compose -f docker-compose.dev.yml up -d --build
    
    Write-Host "⏳ 等待服务启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    Test-ServiceStatus
    
    Write-Host "✅ 开发环境就绪!" -ForegroundColor Green
    Write-Host "🌐 访问地址: http://localhost" -ForegroundColor Cyan
    Write-Host "📊 API文档: http://localhost:8000/docs" -ForegroundColor Cyan
    Write-Host "📁 文件服务: http://localhost:8010/docs" -ForegroundColor Cyan
    Write-Host "💾 MinIO: http://localhost:9001" -ForegroundColor Cyan
}

function Start-DockerGpu {
    Write-Host "🎮 Docker启动GPU服务..." -ForegroundColor Green
    
    # 检查NVIDIA Docker支持
    try {
        docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
        Write-Host "✅ NVIDIA Docker支持正常" -ForegroundColor Green
    } catch {
        Write-Host "❌ NVIDIA Docker支持异常，请安装nvidia-docker2" -ForegroundColor Red
        return
    }
    
    docker-compose -f docker-compose.gpu.yml up -d --build
    
    Write-Host "⏳ 等待GPU服务启动..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
    
    Test-GpuServiceStatus
    
    Write-Host "✅ GPU服务就绪!" -ForegroundColor Green
    Write-Host "🤖 OCR服务: http://localhost:7010/docs" -ForegroundColor Cyan
    Write-Host "🔤 翻译服务: http://localhost:7020/docs" -ForegroundColor Cyan
    Write-Host "🧠 Ollama: http://localhost:11434" -ForegroundColor Cyan
}

function Setup-DevEnvironment {
    Write-Host "🏗️ 设置开发环境..." -ForegroundColor Green
    
    # 创建必要目录
    $directories = @("temp/uploads", "temp/processed", "logs", "ssl", "models/ocr", "models/nmt", "models/vision")
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "📁 创建目录: $dir" -ForegroundColor Gray
        }
    }
    
    # 检查Python环境
    Write-Host "📦 检查Python依赖..." -ForegroundColor Yellow
    try {
        python --version | Out-Null
        Write-Host "✅ Python环境正常" -ForegroundColor Green
    } catch {
        Write-Host "❌ Python未安装或不在PATH中" -ForegroundColor Red
        return
    }
    
    # 安装基础依赖
    $packages = @("fastapi", "uvicorn", "requests", "httpx")
    foreach ($package in $packages) {
        try {
            pip show $package | Out-Null
            Write-Host "✅ $package 已安装" -ForegroundColor Gray
        } catch {
            Write-Host "📦 安装 $package..." -ForegroundColor Yellow
            pip install $package
        }
    }
    
    Write-Host "✅ 开发环境准备完成!" -ForegroundColor Green
}

function Start-DevMode {
    Write-Host "🚀 开发模式启动..." -ForegroundColor Green
    
    # 设置环境变量
    $env:GPU_MACHINE_IP = $GpuMachineIP
    
    Write-Host "📋 启动编排服务..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd 'services/orchestrator'; uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
    
    Start-Sleep -Seconds 3
    
    Write-Host "📁 启动文件服务..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd 'services/file-service'; uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload"
    
    Write-Host "✅ 开发服务已启动!" -ForegroundColor Green
    Write-Host "🔗 访问地址:" -ForegroundColor Cyan
    Write-Host "  - Orchestrator: http://localhost:8000/docs"
    Write-Host "  - File Service: http://localhost:8010/docs"
}

function Setup-GpuEnvironment {
    Write-Host "🎮 GPU环境设置..." -ForegroundColor Green
    
    # 检查GPU
    try {
        nvidia-smi | Out-Null
        Write-Host "✅ GPU检测正常" -ForegroundColor Green
    } catch {
        Write-Host "❌ 未检测到GPU或驱动未安装" -ForegroundColor Red
        return
    }
    
    # 检查Ollama
    try {
        ollama --version | Out-Null
        Write-Host "✅ Ollama已安装" -ForegroundColor Green
    } catch {
        Write-Host "🤖 安装Ollama..." -ForegroundColor Yellow
        Write-Host "💡 请手动下载并安装 Ollama: https://ollama.ai/" -ForegroundColor Yellow
    }
    
    # 下载模型
    Write-Host "📥 下载模型..." -ForegroundColor Yellow
    try {
        ollama pull llama3.2:latest
        Write-Host "✅ 模型下载完成" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ 模型下载失败，请手动执行: ollama pull llama3.2:latest" -ForegroundColor Yellow
    }
    
    Write-Host "✅ GPU环境设置完成!" -ForegroundColor Green
}

function Start-GpuDevMode {
    Write-Host "🎮 GPU开发模式启动..." -ForegroundColor Green
    
    Write-Host "🤖 启动OCR服务..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd 'services/ocr-service'; uvicorn app.main:app --host 0.0.0.0 --port 7010 --reload"
    
    Start-Sleep -Seconds 3
    
    Write-Host "🔤 启动翻译服务..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd 'services/nmt-service'; uvicorn app.main:app --host 0.0.0.0 --port 7020 --reload"
    
    Write-Host "✅ GPU服务已启动!" -ForegroundColor Green
}

function Test-ServiceStatus {
    Write-Host "📊 开发机器服务状态:" -ForegroundColor Yellow
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 5
        Write-Host "  Orchestrator: ✅ $($response.status)" -ForegroundColor Green
    } catch {
        Write-Host "  Orchestrator: ❌ DOWN" -ForegroundColor Red
    }
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8010/health" -TimeoutSec 5
        Write-Host "  File Service: ✅ $($response.status)" -ForegroundColor Green
    } catch {
        Write-Host "  File Service: ❌ DOWN" -ForegroundColor Red
    }
}

function Test-GpuServiceStatus {
    Write-Host "🎮 GPU机器服务状态:" -ForegroundColor Yellow
    
    try {
        $response = Invoke-RestMethod -Uri "http://${GpuMachineIP}:7010/health" -TimeoutSec 5
        Write-Host "  OCR Service: ✅ $($response.status)" -ForegroundColor Green
    } catch {
        Write-Host "  OCR Service: ❌ DOWN" -ForegroundColor Red
    }
    
    try {
        $response = Invoke-RestMethod -Uri "http://${GpuMachineIP}:7020/health" -TimeoutSec 5
        Write-Host "  NMT Service: ✅ $($response.status)" -ForegroundColor Green
    } catch {
        Write-Host "  NMT Service: ❌ DOWN" -ForegroundColor Red
    }
}

function Test-QuickApi {
    Write-Host "🧪 快速API测试..." -ForegroundColor Green
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 10
        Write-Host "✅ API测试成功: $($response.status)" -ForegroundColor Green
    } catch {
        Write-Host "❌ API测试失败" -ForegroundColor Red
    }
}

function Test-EndToEnd {
    Write-Host "🌐 端到端测试..." -ForegroundColor Green
    python test_e2e.py
}

function Start-Monitoring {
    Write-Host "📊 启动监控服务..." -ForegroundColor Green
    
    $env:GRAFANA_PASSWORD = "admin"
    docker-compose -f docker-compose.dev.yml --profile monitoring up -d
    
    Write-Host "✅ 监控服务已启动" -ForegroundColor Green
    Write-Host "📈 Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Cyan
    Write-Host "🔍 Prometheus: http://localhost:9090" -ForegroundColor Cyan
}

function Show-Logs {
    Write-Host "📋 查看服务日志..." -ForegroundColor Green
    docker-compose -f docker-compose.dev.yml logs --tail=50
}

function Clean-Environment {
    Write-Host "🧹 清理环境..." -ForegroundColor Green
    
    docker-compose -f docker-compose.dev.yml down -v
    docker-compose -f docker-compose.gpu.yml down -v
    docker system prune -f
    
    Write-Host "✅ 清理完成" -ForegroundColor Green
}

function Show-DeployGuide {
    Write-Host "🚀 一键部署指南:" -ForegroundColor Green
    Write-Host ""
    Write-Host "1️⃣ 初始化Git仓库 (首次):" -ForegroundColor Yellow
    Write-Host "   .\deploy.ps1 git-setup"
    Write-Host "   git remote add origin <your-repo-url>"
    Write-Host "   git push -u origin main"
    Write-Host ""
    Write-Host "2️⃣ 开发机器部署:" -ForegroundColor Yellow
    Write-Host "   .\deploy.ps1 docker-dev     # Docker方式"
    Write-Host "   # 或"
    Write-Host "   .\deploy.ps1 setup-dev"
    Write-Host "   .\deploy.ps1 dev-up         # 源码方式"
    Write-Host ""
    Write-Host "3️⃣ GPU机器部署:" -ForegroundColor Yellow
    Write-Host "   git clone <your-repo-url>"
    Write-Host "   cd microservices"
    Write-Host "   .\deploy.ps1 docker-gpu     # Docker方式"
    Write-Host "   # 或"
    Write-Host "   .\deploy.ps1 setup-gpu"
    Write-Host "   .\deploy.ps1 gpu-dev        # 源码方式"
    Write-Host ""
    Write-Host "4️⃣ 联调测试:" -ForegroundColor Yellow
    Write-Host "   .\deploy.ps1 test-e2e"
}

# 主逻辑
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "git-setup" { Initialize-GitRepository }
    "docker-dev" { Start-DockerDev }
    "docker-gpu" { Start-DockerGpu }
    "setup-dev" { Setup-DevEnvironment }
    "dev-up" { Start-DevMode }
    "setup-gpu" { Setup-GpuEnvironment }
    "gpu-dev" { Start-GpuDevMode }
    "test" { Test-QuickApi }
    "test-e2e" { Test-EndToEnd }
    "status" { Test-ServiceStatus; Test-GpuServiceStatus }
    "monitor" { Start-Monitoring }
    "logs" { Show-Logs }
    "clean" { Clean-Environment }
    "deploy-guide" { Show-DeployGuide }
    default { 
        Write-Host "❌ 未知命令: $Command" -ForegroundColor Red
        Write-Host ""
        Show-Help
    }
}