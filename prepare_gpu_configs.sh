#!/bin/bash

# 开发机器 - GPU配置管理脚本
# 用于准备和同步GPU机器的配置

set -e

echo "🏗️ 开发机器 - GPU配置管理"

prepare_gpu_configs() {
    echo "📝 准备GPU机器配置文件..."
    
    # 确保.env.gpu.example存在并更新
    cat > .env.gpu.example << 'EOF'
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
EOF

    # 创建GPU机器的.env文件
    cp .env.gpu.example .env.gpu
    
    echo "✅ GPU配置文件准备完成"
}

validate_configs() {
    echo "🔍 验证配置文件..."
    
    # 检查关键文件
    files=("docker-compose.gpu.yml" ".env.gpu.example" "deploy_gpu_simple.sh")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo "✅ $file - 存在"
        else
            echo "❌ $file - 缺失"
        fi
    done
    
    # 检查服务目录
    if [ -d "services/ocr-service" ] && [ -d "services/nmt-service" ]; then
        echo "✅ 服务目录 - 存在"
    else
        echo "❌ 服务目录 - 缺失"
    fi
}

create_sync_instructions() {
    cat > GPU_SYNC_GUIDE.md << 'EOF'
# GPU机器同步指南

## 🚀 GPU机器部署步骤

### 1. 同步代码
```bash
# 在GPU机器上
git clone <repo-url> translation_app
cd translation_app

# 或更新现有代码
git pull origin main
```

### 2. 复制环境配置
```bash
# 使用预配置的GPU环境文件
cp .env.gpu.example .env

# 或手动编辑
nano .env
```

### 3. 确保Ollama运行
```bash
# 检查Ollama状态
ollama list
curl http://localhost:11434/api/tags
```

### 4. 一键部署
```bash
# 给脚本执行权限
chmod +x deploy_gpu_simple.sh

# 执行部署
./deploy_gpu_simple.sh
```

## 🔧 配置要点

1. **Ollama配置**：使用本地Ollama (localhost:11434)
2. **GPU访问**：确保Docker有GPU访问权限
3. **端口映射**：OCR(7010)、翻译(7020)
4. **模型存储**：./models/ 目录会持久化模型

## 🩺 故障排查

### 检查服务状态
```bash
docker compose -f docker-compose.gpu.yml ps
docker compose -f docker-compose.gpu.yml logs
```

### 检查健康状态
```bash
curl http://localhost:7010/health
curl http://localhost:7020/health
curl http://localhost:11434/api/tags
```
EOF

    echo "✅ 同步指南创建完成: GPU_SYNC_GUIDE.md"
}

show_git_commit_guide() {
    echo ""
    echo "📝 提交到Git的建议："
    echo ""
    echo "git add ."
    echo "git commit -m \"Complete GPU deployment configuration\""
    echo "git push origin main"
    echo ""
    echo "然后在GPU机器上执行："
    echo "git pull origin main"
    echo "./deploy_gpu_simple.sh"
}

# 执行所有准备工作
case "${1:-all}" in
    "prepare")
        prepare_gpu_configs
        ;;
    "validate")
        validate_configs
        ;;
    "guide")
        create_sync_instructions
        ;;
    "all")
        prepare_gpu_configs
        validate_configs
        create_sync_instructions
        show_git_commit_guide
        ;;
    *)
        echo "用法: $0 [prepare|validate|guide|all]"
        ;;
esac