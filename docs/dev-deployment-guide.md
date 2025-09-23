# 开发机器部署配置

## 🖥️ 开发机器服务清单

### 1. Orchestrator Service (编排服务)
```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  orchestrator:
    build: ./services/orchestrator
    ports:
      - "8000:8000"
    environment:
      - ENVIRONMENT=development
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/document_translator
      - REDIS_URL=redis://redis:6379/0
      - OCR_SERVICE_URL=http://192.168.1.100:7010  # GPU机器IP
      - NMT_SERVICE_URL=http://192.168.1.100:7020  # GPU机器IP
      - VISION_SERVICE_URL=http://192.168.1.100:7030  # GPU机器IP
    depends_on:
      - postgres
      - redis
    volumes:
      - ./temp:/app/temp
      - ./logs:/app/logs
    restart: unless-stopped

  file-service:
    build: ./services/file-service
    ports:
      - "8010:8010"
    environment:
      - MINIO_ENDPOINT=minio:9000
      - MINIO_ACCESS_KEY=minioadmin
      - MINIO_SECRET_KEY=minioadmin
    depends_on:
      - minio
    volumes:
      - ./temp:/app/temp
    restart: unless-stopped

  postgres:
    image: postgres:15
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=document_translator
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      - MINIO_ROOT_USER=minioadmin
      - MINIO_ROOT_PASSWORD=minioadmin
    volumes:
      - minio_data:/data
    command: server /data --console-address ":9001"
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/sites-available:/etc/nginx/sites-available
      - ./frontend/dist:/var/www/html
      - ./ssl:/etc/ssl
    depends_on:
      - orchestrator
      - file-service
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

## 📁 项目结构完善

```
microservices/
├── docs/                          # 文档
│   ├── deployment-architecture.md
│   ├── gpu-deployment-guide.md
│   └── dev-deployment-guide.md
├── services/                      # 服务源码
│   ├── orchestrator/             # 编排服务
│   │   ├── app/
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── file-service/             # 文件服务 (新增)
│   │   ├── app/
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── ocr-service/              # OCR服务 (GPU机器)
│   ├── nmt-service/              # 翻译服务 (GPU机器)
│   └── vision-service/           # 图像服务 (GPU机器)
├── frontend/                     # 前端界面
│   ├── src/
│   ├── public/
│   ├── package.json
│   └── vite.config.js
├── nginx/                        # Nginx配置
│   ├── nginx.conf
│   └── sites-available/
├── sql/                          # 数据库脚本
│   ├── init.sql
│   └── migrations/
├── scripts/                      # 部署脚本
│   ├── setup-dev.sh
│   ├── setup-gpu.sh
│   └── deploy.sh
├── monitoring/                   # 监控配置
│   ├── prometheus/
│   ├── grafana/
│   └── elk/
├── docker-compose.dev.yml        # 开发环境
├── docker-compose.gpu.yml        # GPU环境
├── docker-compose.prod.yml       # 生产环境
└── Makefile                      # 自动化脚本
```

## 🚀 快速部署脚本

### scripts/setup-dev.sh
```bash
#!/bin/bash
# 开发机器快速部署脚本

echo "🚀 开始部署开发环境..."

# 1. 创建必要的目录
mkdir -p temp logs sql nginx/sites-available frontend/dist ssl

# 2. 设置环境变量
export GPU_MACHINE_IP="192.168.1.100"  # 替换为实际GPU机器IP

# 3. 生成配置文件
envsubst < nginx/nginx.conf.template > nginx/nginx.conf

# 4. 构建和启动服务
docker-compose -f docker-compose.dev.yml up -d --build

# 5. 等待服务启动
echo "⏳ 等待服务启动..."
sleep 30

# 6. 健康检查
echo "🔍 检查服务状态..."
curl -f http://localhost:8000/health || echo "❌ Orchestrator未就绪"
curl -f http://localhost:8010/health || echo "❌ File Service未就绪"
curl -f http://localhost/health || echo "❌ Nginx未就绪"

echo "✅ 开发环境部署完成！"
echo "🌐 访问地址: http://localhost"
echo "📊 管理界面: http://localhost:9001 (MinIO)"
```

### scripts/setup-gpu.sh
```bash
#!/bin/bash
# GPU机器部署脚本

echo "🎮 开始部署GPU服务..."

# 1. 检查GPU
nvidia-smi || { echo "❌ 未检测到GPU"; exit 1; }

# 2. 安装依赖
pip install -r requirements-gpu.txt

# 3. 下载模型
echo "📥 下载模型文件..."
./scripts/download-models.sh

# 4. 启动服务
docker-compose -f docker-compose.gpu.yml up -d --build

# 5. 健康检查
echo "🔍 检查GPU服务..."
curl -f http://localhost:7010/health || echo "❌ OCR Service未就绪"
curl -f http://localhost:7020/health || echo "❌ NMT Service未就绪"
curl -f http://localhost:7030/health || echo "❌ Vision Service未就绪"

echo "✅ GPU服务部署完成！"
```

## 🔧 Makefile自动化

```makefile
# Makefile for Document Translator Microservices

.PHONY: help dev gpu prod clean test

# 默认目标
help:
	@echo "Document Translator 部署命令:"
	@echo "  make dev      - 部署开发环境 (当前机器)"
	@echo "  make gpu      - 部署GPU服务 (GPU机器)"
	@echo "  make prod     - 部署生产环境"
	@echo "  make test     - 运行测试"
	@echo "  make clean    - 清理环境"

# 开发环境部署
dev:
	@echo "🚀 部署开发环境..."
	./scripts/setup-dev.sh
	@echo "✅ 开发环境就绪: http://localhost"

# GPU服务部署
gpu:
	@echo "🎮 部署GPU服务..."
	./scripts/setup-gpu.sh
	@echo "✅ GPU服务就绪"

# 生产环境部署
prod:
	@echo "🏭 部署生产环境..."
	docker-compose -f docker-compose.prod.yml up -d --build
	@echo "✅ 生产环境就绪"

# 运行测试
test:
	@echo "🧪 运行测试..."
	python -m pytest tests/
	@echo "✅ 测试完成"

# 清理环境
clean:
	@echo "🧹 清理环境..."
	docker-compose down -v
	docker system prune -f
	@echo "✅ 清理完成"

# 监控
monitor:
	@echo "📊 启动监控..."
	docker-compose -f monitoring/docker-compose.yml up -d
	@echo "📈 Grafana: http://localhost:3000"
	@echo "🔍 Prometheus: http://localhost:9090"

# 日志查看
logs:
	docker-compose logs -f --tail=100
```