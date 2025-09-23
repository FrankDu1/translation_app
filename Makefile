# Document Translator Microservices - Git + Docker 部署
# 支持开发机器和GPU机器的完整部署方案

.PHONY: help build up down logs restart tunnel test clean dev-up status setup-dev setup-gpu

# 配置变量
GPU_MACHINE_IP ?= 192.168.1.100
POSTGRES_PASSWORD ?= password
MINIO_ACCESS_KEY ?= minioadmin
MINIO_SECRET_KEY ?= minioadmin
GRAFANA_PASSWORD ?= admin

# 默认目标 - 显示帮助
help:
	@echo "🚀 Document Translator 微服务部署命令"
	@echo ""
	@echo "📦 Git + Docker 部署:"
	@echo "  make git-setup     - 初始化Git仓库"
	@echo "  make docker-dev    - Docker启动开发环境"
	@echo "  make docker-gpu    - Docker启动GPU服务"
	@echo "  make docker-full   - 完整Docker部署"
	@echo ""
	@echo "🏗️ 开发环境:"
	@echo "  make setup-dev     - 设置开发环境"
	@echo "  make dev-up        - 开发模式启动"
	@echo "  make setup-gpu     - 设置GPU环境"
	@echo "  make gpu-dev       - GPU开发模式"
	@echo ""
	@echo "🧪 测试和监控:"
	@echo "  make test          - 快速API测试"
	@echo "  make test-e2e      - 端到端测试"
	@echo "  make status        - 检查服务状态"
	@echo "  make monitor       - 启动监控服务"
	@echo ""
	@echo "🔧 工具:"
	@echo "  make tunnel        - 启动SSH隧道"
	@echo "  make clean         - 清理环境"
	@echo "  make logs          - 查看日志"

# Git仓库设置
git-setup:
	@echo "📂 初始化Git仓库..."
	@if [ ! -d .git ]; then \
		git init; \
		echo "node_modules/" >> .gitignore; \
		echo "__pycache__/" >> .gitignore; \
		echo "*.pyc" >> .gitignore; \
		echo ".env*" >> .gitignore; \
		echo "temp/" >> .gitignore; \
		echo "logs/" >> .gitignore; \
		echo "models/" >> .gitignore; \
		git add .; \
		git commit -m "Initial microservices architecture"; \
		echo "✅ Git仓库初始化完成"; \
		echo "💡 请添加远程仓库: git remote add origin <your-repo-url>"; \
		echo "💡 然后推送: git push -u origin main"; \
	else \
		echo "✅ Git仓库已存在"; \
	fi

# Docker部署 - 开发环境
docker-dev:
	@echo "🐳 Docker启动开发环境..."
	@export GPU_MACHINE_IP=$(GPU_MACHINE_IP) && \
	 export POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) && \
	 export MINIO_ACCESS_KEY=$(MINIO_ACCESS_KEY) && \
	 export MINIO_SECRET_KEY=$(MINIO_SECRET_KEY) && \
	 docker-compose -f docker-compose.dev.yml up -d --build
	@echo "⏳ 等待服务启动..."
	@sleep 30
	@make status-dev
	@echo "✅ 开发环境就绪!"
	@echo "🌐 访问地址: http://localhost"
	@echo "📊 API文档: http://localhost:8000/docs"
	@echo "📁 文件服务: http://localhost:8010/docs"
	@echo "💾 MinIO: http://localhost:9001"

# Docker部署 - GPU服务
docker-gpu:
	@echo "🎮 Docker启动GPU服务..."
	@docker-compose -f docker-compose.gpu.yml up -d --build
	@echo "⏳ 等待GPU服务启动..."
	@sleep 60
	@make status-gpu
	@echo "✅ GPU服务就绪!"
	@echo "🤖 OCR服务: http://localhost:7010/docs"
	@echo "🔤 翻译服务: http://localhost:7020/docs"
	@echo "🧠 Ollama: http://localhost:11434"

# Docker部署 - 完整环境
docker-full:
	@echo "🚀 完整Docker部署..."
	@make docker-dev
	@echo "💡 请在GPU机器上运行: make docker-gpu"
	@echo "📋 然后更新GPU_MACHINE_IP并运行: make test-e2e"

# 原有的Docker命令兼容
build:
	docker-compose -f docker-compose.dev.yml build

up: docker-dev

down:
	docker-compose -f docker-compose.dev.yml down
	docker-compose -f docker-compose.gpu.yml down

# 开发环境设置
setup-dev:
	@echo "🏗️ 设置开发环境..."
	@mkdir -p temp/uploads temp/processed logs ssl models/ocr models/nmt models/vision
	@echo "📦 检查Python依赖..."
	@pip list | grep fastapi || pip install fastapi uvicorn
	@pip list | grep requests || pip install requests httpx
	@echo "✅ 开发环境准备完成!"

# GPU环境设置 (源码模式)
setup-gpu:
	@echo "🎮 GPU环境设置..."
	@echo "🔍 检查GPU状态..."
	@nvidia-smi || (echo "❌ 未检测到GPU" && exit 1)
	@echo "🤖 安装Ollama..."
	@which ollama || curl -fsSL https://ollama.ai/install.sh | sh
	@echo "📥 下载模型..."
	@ollama pull llama3.2:latest || echo "⚠️ 模型下载失败，请手动执行"
	@echo "📦 安装依赖..."
	@pip install -r services/ocr-service/requirements.txt || echo "请安装OCR依赖"
	@pip install -r services/nmt-service/requirements.txt || echo "请安装NMT依赖"
	@echo "✅ GPU环境设置完成!"

# 开发模式启动
dev-up:
	@echo "🚀 开发模式启动..."
	@export GPU_MACHINE_IP=$(GPU_MACHINE_IP)
	@echo "📋 启动编排服务..."
	@cd services/orchestrator && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
	@echo "📁 启动文件服务..."
	@cd services/file-service && uvicorn app.main:app --host 0.0.0.0 --port 8010 --reload &
	@echo "✅ 开发服务已启动!"

# GPU开发模式
gpu-dev:
	@echo "🎮 GPU开发模式启动..."
	@echo "🤖 启动OCR服务..."
	@cd services/ocr-service && uvicorn app.main:app --host 0.0.0.0 --port 7010 --reload &
	@echo "🔤 启动翻译服务..."
	@cd services/nmt-service && uvicorn app.main:app --host 0.0.0.0 --port 7020 --reload &
	@echo "✅ GPU服务已启动!"

# 监控服务
monitor:
	@echo "📊 启动监控服务..."
	@export GRAFANA_PASSWORD=$(GRAFANA_PASSWORD) && \
	 docker-compose -f docker-compose.dev.yml --profile monitoring up -d
	@echo "✅ 监控服务已启动"
	@echo "📈 Grafana: http://localhost:3000 (admin/$(GRAFANA_PASSWORD))"
	@echo "🔍 Prometheus: http://localhost:9090"

# 测试命令
test:
	@echo "🧪 快速API测试..."
	@curl -s "http://localhost:8000/health" | jq . || echo "❌ Orchestrator 测试失败"

test-e2e:
	@echo "🌐 端到端测试..."
	@python test_e2e.py

# 状态检查
status:
	@make status-dev
	@make status-gpu

status-dev:
	@echo "� 开发机器服务状态:"
	@curl -s http://localhost:8000/health | jq -r '.status // "❌"' | sed 's/^/  Orchestrator: /' || echo "  Orchestrator: ❌"
	@curl -s http://localhost:8010/health | jq -r '.status // "❌"' | sed 's/^/  File Service: /' || echo "  File Service: ❌"

status-gpu:
	@echo "🎮 GPU机器服务状态:"
	@curl -s http://$(GPU_MACHINE_IP):7010/health | jq -r '.status // "❌"' | sed 's/^/  OCR Service: /' || echo "  OCR Service: ❌"
	@curl -s http://$(GPU_MACHINE_IP):7020/health | jq -r '.status // "❌"' | sed 's/^/  NMT Service: /' || echo "  NMT Service: ❌"

# 日志查看
logs:
	@echo "� 查看服务日志..."
	@docker-compose -f docker-compose.dev.yml logs --tail=50

logs-gpu:
	@echo "� 查看GPU服务日志..."
	@docker-compose -f docker-compose.gpu.yml logs --tail=50

# SSH隧道
tunnel:
	@echo "🔗 启动SSH隧道..."
	@bash infra/scripts/start_tunnel.sh

# 清理环境
clean:
	@echo "🧹 清理环境..."
	@docker-compose -f docker-compose.dev.yml down -v
	@docker-compose -f docker-compose.gpu.yml down -v
	@docker system prune -f
	@echo "✅ 清理完成"

# 快捷方式
dev: setup-dev dev-up
	@echo "🎉 开发环境就绪!"

gpu: setup-gpu gpu-dev
	@echo "🎉 GPU环境就绪!"

# 一键部署指南
deploy-guide:
	@echo "🚀 一键部署指南:"
	@echo ""
	@echo "1️⃣ 初始化Git仓库 (首次):"
	@echo "   make git-setup"
	@echo "   git remote add origin <your-repo-url>"
	@echo "   git push -u origin main"
	@echo ""
	@echo "2️⃣ 开发机器部署:"
	@echo "   make docker-dev     # Docker方式"
	@echo "   # 或"
	@echo "   make dev           # 源码方式"
	@echo ""
	@echo "3️⃣ GPU机器部署:"
	@echo "   git clone <your-repo-url>"
	@echo "   cd microservices"
	@echo "   make docker-gpu    # Docker方式"
	@echo "   # 或"
	@echo "   make gpu          # 源码方式"
	@echo ""
	@echo "4️⃣ 联调测试:"
	@echo "   make test-e2e"