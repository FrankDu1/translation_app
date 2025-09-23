# 开发机器 - GPU配置管理脚本 (PowerShell版本)

param(
    [string]$Action = "all"
)

Write-Host "🏗️ 开发机器 - GPU配置管理" -ForegroundColor Green

function Prepare-GpuConfigs {
    Write-Host "📝 准备GPU机器配置文件..." -ForegroundColor Blue
    
    # 创建.env.gpu.example
    $envContent = @"
# GPU机器环境变量配置
CUDA_VISIBLE_DEVICES=0
OCR_ENGINES=easyocr,paddleocr
MAX_BATCH_SIZE=8
WORKER_TIMEOUT=300

# 使用本地Ollama
OLLAMA_HOST=http://host.docker.internal:11434
OLLAMA_MODELS=llama3.2:latest

# 模型路径
HF_HOME=/app/models/huggingface
MODEL_CACHE_DIR=/app/models
DEBUG=true
LOG_LEVEL=INFO
PYTHONPATH=/app
"@
    
    $envContent | Out-File -FilePath ".env.gpu.example" -Encoding UTF8
    Copy-Item ".env.gpu.example" ".env.gpu"
    
    Write-Host "✅ GPU配置文件准备完成" -ForegroundColor Green
}

function Test-Configs {
    Write-Host "🔍 验证配置文件..." -ForegroundColor Blue
    
    $files = @("docker-compose.gpu.yml", ".env.gpu.example", "deploy_gpu_simple.sh")
    foreach ($file in $files) {
        if (Test-Path $file) {
            Write-Host "✅ $file - 存在" -ForegroundColor Green
        } else {
            Write-Host "❌ $file - 缺失" -ForegroundColor Red
        }
    }
    
    if ((Test-Path "services\ocr-service") -and (Test-Path "services\nmt-service")) {
        Write-Host "✅ 服务目录 - 存在" -ForegroundColor Green
    } else {
        Write-Host "❌ 服务目录 - 缺失" -ForegroundColor Red
    }
}

function New-SyncGuide {
    $guideContent = @"
# GPU机器同步指南

## 🚀 GPU机器部署步骤

### 1. 同步代码
``````bash
# 在GPU机器上
git clone <repo-url> translation_app
cd translation_app

# 或更新现有代码
git pull origin main
``````

### 2. 复制环境配置
``````bash
# 使用预配置的GPU环境文件
cp .env.gpu.example .env

# 或手动编辑
nano .env
``````

### 3. 确保Ollama运行
``````bash
# 检查Ollama状态
ollama list
curl http://localhost:11434/api/tags
``````

### 4. 一键部署
``````bash
# 给脚本执行权限
chmod +x deploy_gpu_simple.sh

# 执行部署
./deploy_gpu_simple.sh
``````

## 🔧 配置要点

1. **Ollama配置**：使用本地Ollama (localhost:11434)
2. **GPU访问**：确保Docker有GPU访问权限
3. **端口映射**：OCR(7010)、翻译(7020)
4. **模型存储**：./models/ 目录会持久化模型

## 🩺 故障排查

### 检查服务状态
``````bash
docker compose -f docker-compose.gpu.yml ps
docker compose -f docker-compose.gpu.yml logs
``````

### 检查健康状态
``````bash
curl http://localhost:7010/health
curl http://localhost:7020/health
curl http://localhost:11434/api/tags
``````
"@
    
    $guideContent | Out-File -FilePath "GPU_SYNC_GUIDE.md" -Encoding UTF8
    Write-Host "✅ 同步指南创建完成: GPU_SYNC_GUIDE.md" -ForegroundColor Green
}

function Show-GitGuide {
    Write-Host ""
    Write-Host "📝 提交到Git的建议：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "git add ." -ForegroundColor White
    Write-Host "git commit -m `"Complete GPU deployment configuration`"" -ForegroundColor White
    Write-Host "git push origin main" -ForegroundColor White
    Write-Host ""
    Write-Host "然后在GPU机器上执行：" -ForegroundColor Cyan
    Write-Host "git pull origin main" -ForegroundColor White
    Write-Host "./deploy_gpu_simple.sh" -ForegroundColor White
}

# 执行操作
switch ($Action) {
    "prepare" {
        Prepare-GpuConfigs
    }
    "validate" {
        Test-Configs
    }
    "guide" {
        New-SyncGuide
    }
    "all" {
        Prepare-GpuConfigs
        Test-Configs
        New-SyncGuide
        Show-GitGuide
    }
    default {
        Write-Host "用法: .\prepare_gpu_configs.ps1 [prepare|validate|guide|all]"
    }
}