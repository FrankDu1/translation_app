#!/bin/bash

# GPU机器超简化部署脚本
# 前提：开发机器已配置好所有文件

set -e

echo "🎮 GPU机器一键部署开始..."

# 检查基本环境
echo "📋 检查环境..."
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits
docker --version

# 创建目录
echo "📁 创建必要目录..."
mkdir -p models/{ocr,nmt,vision,huggingface}
mkdir -p temp/{uploads,processed}
mkdir -p logs

# 检查配置文件
echo "🔧 检查配置文件..."
if [ ! -f .env ]; then
    echo "❌ .env文件不存在，请从开发机器同步"
    exit 1
fi

if [ ! -f docker-compose.gpu.yml ]; then
    echo "❌ docker-compose.gpu.yml不存在，请从开发机器同步"
    exit 1
fi

# 检查Ollama服务
echo "🤖 检查Ollama服务..."
if curl -s http://localhost:11434/api/tags &> /dev/null; then
    echo "✅ Ollama服务运行正常"
    echo "📋 当前可用模型："
    curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || echo "  (使用API查询模型列表)"
else
    echo "❌ Ollama服务未运行，请先启动Ollama Docker容器"
    echo "💡 确保Ollama在localhost:11434可访问"
    exit 1
fi

# 构建和启动
echo "🔨 构建Docker镜像..."
docker compose -f docker-compose.gpu.yml build

echo "🚀 启动服务..."
docker compose -f docker-compose.gpu.yml up -d ocr-service nmt-service

echo "⏳ 等待服务启动..."
sleep 30

echo "🔍 检查服务状态..."
docker compose -f docker-compose.gpu.yml ps

echo "🩺 健康检查..."
sleep 10
curl -f http://localhost:7010/health && echo "✅ OCR服务正常"
curl -f http://localhost:7020/health && echo "✅ 翻译服务正常"

echo ""
echo "🎉 GPU服务部署完成！"
echo "📊 服务地址："
echo "  OCR服务: http://localhost:7010/docs"
echo "  翻译服务: http://localhost:7020/docs"
echo "  Ollama: http://localhost:11434"