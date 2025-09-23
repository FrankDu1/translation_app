# GPU机器部署脚本 (PowerShell版本)
# 使用方法: .\deploy_gpu.ps1 [步骤]

param(
    [string]$Step = "help"
)

# 颜色函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Log-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Green"
}

function Log-Warn {
    param([string]$Message)
    Write-ColorOutput "[WARN] $Message" "Yellow"
}

function Log-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Log-Step {
    param([string]$Message)
    Write-ColorOutput "[STEP] $Message" "Blue"
}

# 检查GPU环境
function Test-GpuEnvironment {
    Log-Step "检查GPU环境..."
    
    try {
        $gpuInfo = nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader,nounits
        Log-Info "GPU状态:"
        Write-Host $gpuInfo
    } catch {
        Log-Error "未找到nvidia-smi，请安装NVIDIA驱动"
        exit 1
    }
    
    # 检查NVIDIA Docker支持
    try {
        docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi | Out-Null
        Log-Info "✅ GPU环境检查通过"
    } catch {
        Log-Error "NVIDIA Docker支持异常，请安装nvidia-docker2"
        exit 1
    }
}

# 准备环境
function Initialize-Environment {
    Log-Step "准备环境配置..."
    
    # 复制环境变量文件
    if (-not (Test-Path ".env")) {
        Copy-Item ".env.gpu.example" ".env"
        Log-Info "已创建 .env 文件，请根据需要修改配置"
    } else {
        Log-Info ".env 文件已存在"
    }
    
    # 创建必要目录
    $directories = @(
        "models\ocr", "models\nmt", "models\vision", 
        "models\huggingface", "models\diffusers",
        "temp\uploads", "temp\processed", "logs"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }
    
    Log-Info "✅ 环境准备完成"
}

# 构建镜像
function Build-DockerImages {
    Log-Step "构建Docker镜像..."
    
    Log-Info "构建OCR服务镜像..."
    docker compose -f docker-compose.gpu.yml build ocr-service
    
    Log-Info "构建翻译服务镜像..."
    docker compose -f docker-compose.gpu.yml build nmt-service
    
    # 检查是否有Vision服务
    $services = docker compose -f docker-compose.gpu.yml config --services
    if ($services -contains "vision-service") {
        Log-Info "构建Vision服务镜像..."
        docker compose -f docker-compose.gpu.yml build vision-service
    }
    
    Log-Info "✅ 镜像构建完成"
}

# 下载模型
function Download-Models {
    Log-Step "下载AI模型..."
    
    # 启动Ollama
    Log-Info "启动Ollama服务..."
    docker compose -f docker-compose.gpu.yml up -d ollama
    
    # 等待Ollama启动
    Log-Info "等待Ollama服务就绪..."
    $timeout = 60
    $elapsed = 0
    
    do {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -TimeoutSec 2 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                break
            }
        } catch {
            Start-Sleep -Seconds 2
            $elapsed += 2
            Write-Host "." -NoNewline
        }
    } while ($elapsed -lt $timeout)
    
    Write-Host ""
    
    if ($elapsed -ge $timeout) {
        Log-Error "Ollama服务启动超时"
        return
    }
    
    # 下载模型
    Log-Info "下载Llama模型..."
    docker compose -f docker-compose.gpu.yml exec ollama ollama pull llama3.2:latest
    
    Log-Info "下载Qwen模型..."
    try {
        docker compose -f docker-compose.gpu.yml exec ollama ollama pull qwen2.5:latest
    } catch {
        Log-Warn "Qwen模型下载失败，可跳过"
    }
    
    Log-Info "✅ 模型下载完成"
}

# 启动服务
function Start-GpuServices {
    Log-Step "启动GPU服务..."
    
    # 启动核心服务
    Log-Info "启动核心服务..."
    docker compose -f docker-compose.gpu.yml up -d ocr-service nmt-service ollama
    
    # 等待服务启动
    Log-Info "等待服务启动..."
    Start-Sleep -Seconds 30
    
    # 检查服务状态
    Log-Info "检查服务状态..."
    docker compose -f docker-compose.gpu.yml ps
    
    Log-Info "✅ 服务启动完成"
}

# 健康检查
function Test-ServiceHealth {
    Log-Step "执行健康检查..."
    
    $services = @(
        @{Url="http://localhost:7010/health"; Name="OCR服务"},
        @{Url="http://localhost:7020/health"; Name="翻译服务"},
        @{Url="http://localhost:11434/api/tags"; Name="Ollama服务"}
    )
    
    foreach ($service in $services) {
        try {
            $response = Invoke-WebRequest -Uri $service.Url -TimeoutSec 10 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Log-Info "✅ $($service.Name) 健康检查通过"
            } else {
                Log-Error "❌ $($service.Name) 健康检查失败"
            }
        } catch {
            Log-Error "❌ $($service.Name) 健康检查失败"
            Log-Info "尝试查看日志: docker compose -f docker-compose.gpu.yml logs"
        }
    }
}

# 显示使用说明
function Show-Help {
    Write-Host "GPU机器部署脚本使用说明:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  .\deploy_gpu.ps1 [步骤]" -ForegroundColor White
    Write-Host ""
    Write-Host "可用步骤:" -ForegroundColor Yellow
    Write-Host "  check      - 检查GPU环境"
    Write-Host "  prepare    - 准备环境配置" 
    Write-Host "  build      - 构建Docker镜像"
    Write-Host "  models     - 下载AI模型"
    Write-Host "  start      - 启动服务"
    Write-Host "  health     - 健康检查"
    Write-Host "  all        - 执行完整部署流程"
    Write-Host "  logs       - 查看服务日志"
    Write-Host "  status     - 查看服务状态"
    Write-Host "  stop       - 停止服务"
    Write-Host "  clean      - 清理环境"
    Write-Host ""
    Write-Host "示例:" -ForegroundColor Green
    Write-Host "  .\deploy_gpu.ps1 all       # 完整部署"
    Write-Host "  .\deploy_gpu.ps1 check     # 只检查环境"
    Write-Host "  .\deploy_gpu.ps1 start     # 只启动服务"
}

# 查看日志
function Show-ServiceLogs {
    Log-Info "显示服务日志..."
    docker compose -f docker-compose.gpu.yml logs -f --tail=50
}

# 查看状态
function Show-ServiceStatus {
    Log-Info "服务状态:"
    docker compose -f docker-compose.gpu.yml ps
    Write-Host ""
    Log-Info "GPU使用情况:"
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
}

# 停止服务
function Stop-GpuServices {
    Log-Info "停止GPU服务..."
    docker compose -f docker-compose.gpu.yml down
    Log-Info "✅ 服务已停止"
}

# 清理环境
function Clear-Environment {
    $response = Read-Host "这将删除所有容器和数据，确定要继续吗? (y/N)"
    if ($response -match "^[yY]") {
        Log-Info "清理Docker环境..."
        docker compose -f docker-compose.gpu.yml down -v
        docker system prune -f
        Log-Info "✅ 环境清理完成"
    } else {
        Log-Info "取消清理操作"
    }
}

# 主函数
function Invoke-DeploymentStep {
    param([string]$StepName)
    
    switch ($StepName) {
        "check" {
            Test-GpuEnvironment
        }
        "prepare" {
            Initialize-Environment
        }
        "build" {
            Build-DockerImages
        }
        "models" {
            Download-Models
        }
        "start" {
            Start-GpuServices
        }
        "health" {
            Test-ServiceHealth
        }
        "all" {
            Log-Info "🚀 开始GPU机器完整部署流程..."
            Test-GpuEnvironment
            Initialize-Environment
            Build-DockerImages
            Download-Models
            Start-GpuServices
            Test-ServiceHealth
            
            Write-Host ""
            Log-Info "🎉 GPU机器部署完成!" 
            Log-Info "📊 服务地址:"
            Log-Info "  OCR服务: http://localhost:7010/docs"
            Log-Info "  翻译服务: http://localhost:7020/docs"  
            Log-Info "  Ollama: http://localhost:11434"
        }
        "logs" {
            Show-ServiceLogs
        }
        "status" {
            Show-ServiceStatus
        }
        "stop" {
            Stop-GpuServices
        }
        "clean" {
            Clear-Environment
        }
        default {
            Show-Help
        }
    }
}

# 执行指定步骤
Invoke-DeploymentStep -StepName $Step