#!/bin/bash

# GPU机器全Docker部署脚本
# 适用于所有服务(包括Ollama)都在Docker中运行的环境

set -e

echo "🎮 GPU机器全Docker部署开始..."

# 检查基本环境
echo "📋 检查GPU和Docker环境..."
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits
docker --version

# 创建必要目录
echo "📁 创建目录结构..."
mkdir -p models/{ocr,nmt,vision,huggingface}
mkdir -p temp/{uploads,processed}
mkdir -p logs

# 检查配置文件
echo "🔧 验证配置文件..."
if [ ! -f .env ]; then
    if [ -f .env.gpu.example ]; then
        cp .env.gpu.example .env
        echo "✅ 已复制GPU环境配置"
    else
        echo "❌ 缺少环境配置文件，请同步代码"
        exit 1
    fi
fi

if [ ! -f docker-compose.gpu.yml ]; then
    echo "❌ docker-compose.gpu.yml不存在"
    exit 1
fi

# 检查Ollama服务
echo "🤖 检查Ollama服务..."
if curl -f -s http://localhost:11434/api/tags &> /dev/null; then
    echo "✅ Ollama服务运行正常"
else
    echo "⚠️ Ollama服务暂未运行，将尝试启动"
    echo "💡 如果你的Ollama在其他容器中，请确保端口11434可访问"
fi

# 构建镜像
echo "🔨 构建GPU服务镜像..."
echo "  🔍 构建OCR服务..."
docker compose -f docker-compose.gpu.yml build ocr-service

echo "  🔤 构建翻译服务..."
docker compose -f docker-compose.gpu.yml build nmt-service

# 启动服务
echo "🚀 启动GPU服务..."
docker compose -f docker-compose.gpu.yml up -d ocr-service nmt-service

# 等待服务启动
echo "⏳ 等待服务初始化..."
sleep 45

# 检查服务状态
echo "🔍 检查服务状态..."
docker compose -f docker-compose.gpu.yml ps

# 健康检查
echo "🩺 执行健康检查..."
sleep 10

echo "  🔍 检查OCR服务..."
if curl -f -s http://localhost:7010/health &> /dev/null; then
    echo "  ✅ OCR服务 (7010) - 正常"
else
    echo "  ⚠️ OCR服务 (7010) - 启动中或异常"
fi

echo "  🔤 检查翻译服务..."
if curl -f -s http://localhost:7020/health &> /dev/null; then
    echo "  ✅ 翻译服务 (7020) - 正常"
else
    echo "  ⚠️ 翻译服务 (7020) - 启动中或异常"
fi

echo "  🤖 检查Ollama服务..."
if curl -f -s http://localhost:11434/api/tags &> /dev/null; then
    echo "  ✅ Ollama服务 (11434) - 正常"
else
    echo "  ⚠️ Ollama服务 (11434) - 需要检查"
fi

echo ""
echo "🎉 GPU服务部署完成！"
echo ""
echo "📊 服务访问地址："
echo "  🔍 OCR服务API: http://localhost:7010/docs"
echo "  🔤 翻译服务API: http://localhost:7020/docs"
echo "  🤖 Ollama API: http://localhost:11434"
echo ""
echo "📋 管理命令："
echo "  查看状态: docker compose -f docker-compose.gpu.yml ps"
echo "  查看日志: docker compose -f docker-compose.gpu.yml logs -f"
echo "  停止服务: docker compose -f docker-compose.gpu.yml down"