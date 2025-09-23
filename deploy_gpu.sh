#!/bin/bash

# GPU机器一键部署脚本
# 使用方法: ./deploy_gpu.sh [step]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查GPU环境
check_gpu() {
    log_step "检查GPU环境..."
    
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "未找到nvidia-smi，请安装NVIDIA驱动"
        exit 1
    fi
    
    log_info "GPU状态:"
    nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader,nounits
    
    # 检查NVIDIA Docker支持
    if ! docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi &> /dev/null; then
        log_error "NVIDIA Docker支持异常，请安装nvidia-docker2"
        exit 1
    fi
    
    log_info "✅ GPU环境检查通过"
}

# 准备环境
prepare_env() {
    log_step "准备环境配置..."
    
    # 复制环境变量文件
    if [ ! -f .env ]; then
        cp .env.gpu.example .env
        log_info "已创建 .env 文件，请根据需要修改配置"
    else
        log_info ".env 文件已存在"
    fi
    
    # 创建必要目录
    mkdir -p models/{ocr,nmt,vision,huggingface,diffusers}
    mkdir -p temp/{uploads,processed}
    mkdir -p logs
    
    log_info "✅ 环境准备完成"
}

# 构建镜像
build_images() {
    log_step "构建Docker镜像..."
    
    log_info "构建OCR服务镜像..."
    docker compose -f docker-compose.gpu.yml build ocr-service
    
    log_info "构建翻译服务镜像..."
    docker compose -f docker-compose.gpu.yml build nmt-service
    
    # 如果存在Vision服务，也构建
    if docker compose -f docker-compose.gpu.yml config --services | grep -q vision-service; then
        log_info "构建Vision服务镜像..."
        docker compose -f docker-compose.gpu.yml build vision-service
    fi
    
    log_info "✅ 镜像构建完成"
}

# 下载模型
download_models() {
    log_step "下载AI模型..."
    
    # 启动Ollama
    log_info "启动Ollama服务..."
    docker compose -f docker-compose.gpu.yml up -d ollama
    
    # 等待Ollama启动
    log_info "等待Ollama服务就绪..."
    for i in {1..30}; do
        if curl -s http://localhost:11434/api/tags &> /dev/null; then
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    # 下载模型
    log_info "下载Llama模型..."
    docker compose -f docker-compose.gpu.yml exec ollama ollama pull llama3.2:latest
    
    log_info "下载Qwen模型..."
    docker compose -f docker-compose.gpu.yml exec ollama ollama pull qwen2.5:latest || log_warn "Qwen模型下载失败，可跳过"
    
    log_info "✅ 模型下载完成"
}

# 启动服务
start_services() {
    log_step "启动GPU服务..."
    
    # 启动核心服务
    log_info "启动核心服务..."
    docker compose -f docker-compose.gpu.yml up -d ocr-service nmt-service ollama
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 30
    
    # 检查服务状态
    log_info "检查服务状态..."
    docker compose -f docker-compose.gpu.yml ps
    
    log_info "✅ 服务启动完成"
}

# 健康检查
health_check() {
    log_step "执行健康检查..."
    
    services=("http://localhost:7010/health" "http://localhost:7020/health" "http://localhost:11434/api/tags")
    names=("OCR服务" "翻译服务" "Ollama服务")
    
    for i in "${!services[@]}"; do
        url="${services[$i]}"
        name="${names[$i]}"
        
        if curl -f -s "$url" &> /dev/null; then
            log_info "✅ $name 健康检查通过"
        else
            log_error "❌ $name 健康检查失败"
            log_info "尝试查看日志: docker compose -f docker-compose.gpu.yml logs ${url##*/}"
        fi
    done
}

# 显示使用说明
show_help() {
    echo "GPU机器部署脚本使用说明:"
    echo ""
    echo "  ./deploy_gpu.sh [步骤]"
    echo ""
    echo "可用步骤:"
    echo "  check      - 检查GPU环境"
    echo "  prepare    - 准备环境配置" 
    echo "  build      - 构建Docker镜像"
    echo "  models     - 下载AI模型"
    echo "  start      - 启动服务"
    echo "  health     - 健康检查"
    echo "  all        - 执行完整部署流程"
    echo "  logs       - 查看服务日志"
    echo "  status     - 查看服务状态"
    echo "  stop       - 停止服务"
    echo "  clean      - 清理环境"
    echo ""
    echo "示例:"
    echo "  ./deploy_gpu.sh all       # 完整部署"
    echo "  ./deploy_gpu.sh check     # 只检查环境"
    echo "  ./deploy_gpu.sh start     # 只启动服务"
}

# 查看日志
show_logs() {
    log_info "显示服务日志..."
    docker compose -f docker-compose.gpu.yml logs -f --tail=50
}

# 查看状态
show_status() {
    log_info "服务状态:"
    docker compose -f docker-compose.gpu.yml ps
    echo ""
    log_info "GPU使用情况:"
    nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
}

# 停止服务
stop_services() {
    log_info "停止GPU服务..."
    docker compose -f docker-compose.gpu.yml down
    log_info "✅ 服务已停止"
}

# 清理环境
clean_env() {
    log_warn "这将删除所有容器和数据，确定要继续吗? (y/N)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        log_info "清理Docker环境..."
        docker compose -f docker-compose.gpu.yml down -v
        docker system prune -f
        log_info "✅ 环境清理完成"
    else
        log_info "取消清理操作"
    fi
}

# 主函数
main() {
    case "${1:-help}" in
        "check")
            check_gpu
            ;;
        "prepare")
            prepare_env
            ;;
        "build")
            build_images
            ;;
        "models")
            download_models
            ;;
        "start")
            start_services
            ;;
        "health")
            health_check
            ;;
        "all")
            log_info "🚀 开始GPU机器完整部署流程..."
            check_gpu
            prepare_env
            build_images
            download_models
            start_services
            health_check
            log_info "🎉 GPU机器部署完成!"
            log_info "📊 服务地址:"
            log_info "  OCR服务: http://localhost:7010/docs"
            log_info "  翻译服务: http://localhost:7020/docs"  
            log_info "  Ollama: http://localhost:11434"
            ;;
        "logs")
            show_logs
            ;;
        "status")
            show_status
            ;;
        "stop")
            stop_services
            ;;
        "clean")
            clean_env
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 执行主函数
main "$@"