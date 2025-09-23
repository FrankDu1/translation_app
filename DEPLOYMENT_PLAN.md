# 🏗️ 文档翻译微服务完整部署方案

## 📋 部署总览

### 当前状态
✅ **微服务框架完成**: Orchestrator + OCR + NMT + 文件服务
✅ **API结构设计**: REST API + 异步处理
✅ **数据流设计**: 完整的端到端处理流程
✅ **Docker配置**: 开发环境 + GPU环境配置
✅ **Nginx配置**: 反向代理 + 负载均衡

### 部署架构
```
开发机器 (您当前的机器)           GPU机器 (需要部署的机器)
┌─────────────────────────┐    ┌─────────────────────────┐
│  🌐 Nginx (80/443)      │    │  🤖 OCR Service (7010)  │
│  🎯 Orchestrator (8000) │────│  🔤 NMT Service (7020)  │
│  📁 File Service (8010)  │    │  🎨 Vision Service (7030)│
│  💾 PostgreSQL (5432)   │    │  🧠 Ollama (11434)      │
│  🔴 Redis (6379)        │    └─────────────────────────┘
│  📦 MinIO (9000)        │
└─────────────────────────┘
```

## 🎯 推荐的部署步骤

### 第一阶段: 完善开发机器框架 (立即可做)

1. **完善Orchestrator服务**
   ```bash
   cd microservices/services/orchestrator
   # 已完成: 基础API结构、异步处理、错误处理
   # 需要完善: 数据库集成、缓存机制、监控
   ```

2. **部署File Service**
   ```bash
   cd microservices/services/file-service
   pip install fastapi uvicorn python-multipart pillow PyPDF2 python-docx
   uvicorn app.main:app --host 0.0.0.0 --port 8010
   ```

3. **配置数据库和缓存**
   ```bash
   # PostgreSQL (用Docker)
   docker run -d --name postgres \
     -e POSTGRES_DB=document_translator \
     -e POSTGRES_USER=postgres \
     -e POSTGRES_PASSWORD=password \
     -p 5432:5432 postgres:15

   # Redis (用Docker)
   docker run -d --name redis -p 6379:6379 redis:7-alpine
   ```

4. **配置Nginx**
   ```bash
   # 复制nginx配置
   sudo cp docs/nginx.conf /etc/nginx/sites-available/document-translator
   sudo ln -s /etc/nginx/sites-available/document-translator /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```

### 第二阶段: GPU机器部署准备

1. **准备GPU机器环境**
   ```bash
   # 检查GPU
   nvidia-smi
   
   # 安装Docker + NVIDIA Container Runtime
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   sudo apt-get update && sudo apt-get install -y nvidia-docker2
   sudo systemctl restart docker
   ```

2. **部署模型服务**
   ```bash
   # 克隆项目到GPU机器
   git clone <your-repo> document-translator
   cd document-translator/microservices
   
   # 启动GPU服务
   docker-compose -f docker-compose.gpu.yml up -d
   ```

### 第三阶段: 联调和测试

1. **更新开发机器配置**
   ```bash
   # 更新环境变量，指向GPU机器
   export OCR_SERVICE_URL="http://192.168.1.100:7010"    # 替换为GPU机器IP
   export NMT_SERVICE_URL="http://192.168.1.100:7020"
   export VISION_SERVICE_URL="http://192.168.1.100:7030"
   ```

2. **端到端测试**
   ```bash
   # 测试完整流程
   python test_e2e.py
   ```

## 🚀 GPU机器需要的服务详解

### 1. OCR服务 (Port 7010)
```yaml
硬件需求:
  - GPU内存: 4-8GB
  - 系统内存: 8GB+
  - 存储: 10GB (模型文件)

模型选择:
  - EasyOCR: 通用多语言OCR
  - PaddleOCR: 高精度中文OCR  
  - TrOCR: 基于Transformer的OCR (可选)

部署命令:
  docker run -d --gpus all \
    -p 7010:7010 \
    -v ./models:/app/models \
    document-translator/ocr-service
```

### 2. 翻译服务 (Port 7020)
```yaml
硬件需求:
  - GPU内存: 8-16GB
  - 系统内存: 16GB+
  - 存储: 20GB (模型文件)

模型选择:
  - Ollama: llama3.2/qwen2.5 (本地推理)
  - CTranslate2: 优化的翻译模型
  - NLLB: Meta多语言翻译模型

部署命令:
  docker run -d --gpus all \
    -p 7020:7020 \
    -v ./models:/app/models \
    document-translator/nmt-service
```

### 3. 图像处理服务 (Port 7030, 可选)
```yaml
硬件需求:
  - GPU内存: 8-12GB
  - 系统内存: 16GB+
  - 存储: 15GB (模型文件)

功能:
  - 图像修复 (Stable Diffusion Inpainting)
  - 文字区域智能填充
  - 背景重建

部署命令:
  docker run -d --gpus all \
    -p 7030:7030 \
    -v ./models:/app/models \
    document-translator/vision-service
```

## 📋 部署检查清单

### 开发机器检查清单
- [ ] Orchestrator服务正常启动 (Port 8000)
- [ ] File Service正常启动 (Port 8010)  
- [ ] PostgreSQL数据库连接正常 (Port 5432)
- [ ] Redis缓存服务正常 (Port 6379)
- [ ] Nginx反向代理配置正确 (Port 80/443)
- [ ] 健康检查接口响应正常
- [ ] 日志记录正常工作

### GPU机器检查清单
- [ ] nvidia-smi显示GPU正常
- [ ] Docker支持GPU (nvidia-docker2)
- [ ] OCR服务启动并响应健康检查
- [ ] 翻译服务启动并响应健康检查
- [ ] Ollama模型下载完成
- [ ] 服务间网络连通性正常

### 网络连通性检查
- [ ] 开发机器可以访问GPU机器的7010端口 (OCR)
- [ ] 开发机器可以访问GPU机器的7020端口 (翻译)
- [ ] 防火墙规则配置正确
- [ ] 负载测试通过

## 🔧 配置参考

### 环境变量配置 (.env)
```bash
# 开发机器
DATABASE_URL=postgresql://postgres:password@localhost:5432/document_translator
REDIS_URL=redis://localhost:6379/0
OCR_SERVICE_URL=http://192.168.1.100:7010
NMT_SERVICE_URL=http://192.168.1.100:7020
VISION_SERVICE_URL=http://192.168.1.100:7030
MAX_FILE_SIZE=100MB
UPLOAD_DIR=./temp/uploads

# GPU机器
CUDA_VISIBLE_DEVICES=0
OLLAMA_MODELS=llama3.2:latest,qwen2.5:latest
OCR_ENGINES=easyocr,paddleocr
NMT_ENGINES=ollama,ctranslate2
HF_HOME=/app/models/huggingface
```

### 性能调优建议
```yaml
OCR服务优化:
  - batch_size: 4-8 (根据GPU内存)
  - max_workers: 2-4
  - model_cache: 启用

翻译服务优化:
  - context_length: 512-1024
  - beam_size: 4
  - length_penalty: 1.0
  - batch_size: 8-16

系统级优化:
  - 启用GPU内存池
  - 设置合适的worker数量
  - 配置请求超时
  - 启用缓存机制
```

## 📞 技术支持

部署过程中如果遇到问题，可以检查：

1. **服务日志**: `docker-compose logs -f service-name`
2. **健康检查**: `curl http://localhost:port/health`
3. **网络连通**: `telnet gpu-machine-ip port`
4. **资源使用**: `nvidia-smi` / `htop`

这个架构设计支持：
- ✅ 横向扩展 (多GPU机器)
- ✅ 服务降级 (GPU服务不可用时使用CPU)
- ✅ 负载均衡 (Nginx)
- ✅ 监控告警 (Prometheus + Grafana)
- ✅ 容器化部署 (Docker)

您觉得这个部署方案如何？我们可以先从完善开发机器的框架开始！