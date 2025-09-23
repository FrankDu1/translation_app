# 🚀 文档翻译微服务 - Git + Docker 部署方案

## 📋 方案概览

### 🎯 推荐部署策略
我们采用 **Git + Docker 双重部署** 方案，兼具开发灵活性和生产稳定性：

```
📂 Git Repository (代码同步)
├── 开发机器 (业务逻辑服务)
│   ├── 🐳 Docker: Orchestrator + File Service + Database
│   └── 🛠️ 源码: 开发调试模式
└── GPU机器 (AI模型服务)
    ├── 🐳 Docker: OCR + NMT + Vision Services  
    └── 🛠️ 源码: 快速调试模式
```

## 🚀 一键部署指南

### 第一步：Git仓库设置
```bash
# 1. 初始化Git仓库
make git-setup

# 2. 创建远程仓库 (GitHub/GitLab)
git remote add origin https://github.com/yourusername/document-translator-microservices.git
git push -u origin main
```

### 第二步：开发机器部署
```bash
# 方式1: Docker部署 (推荐生产环境)
make docker-dev

# 方式2: 源码部署 (推荐开发调试)
make setup-dev
make dev-up
```

### 第三步：GPU机器部署
```bash
# 1. 克隆代码
git clone https://github.com/yourusername/document-translator-microservices.git
cd document-translator-microservices/microservices

# 2. 方式1: Docker部署 (推荐生产环境)
make docker-gpu

# 2. 方式2: 源码部署 (推荐开发调试)
make setup-gpu
make gpu-dev
```

### 第四步：联调测试
```bash
# 更新GPU机器IP
export GPU_MACHINE_IP="192.168.1.100"

# 运行端到端测试
make test-e2e
```

## 🐳 Docker配置详解

### 开发机器服务 (docker-compose.dev.yml)
| 服务 | 端口 | 功能 |
|------|------|------|
| **orchestrator** | 8000 | API网关和业务编排 |
| **file-service** | 8010 | 文件上传和处理 |
| **postgres** | 5432 | 数据库 |
| **redis** | 6379 | 缓存 |
| **minio** | 9000/9001 | 对象存储 |
| **nginx** | 80/443 | 反向代理 |

### GPU机器服务 (docker-compose.gpu.yml)
| 服务 | 端口 | GPU需求 | 功能 |
|------|------|---------|------|
| **ocr-service** | 7010 | 4-8GB | 文字识别 |
| **nmt-service** | 7020 | 8-16GB | 机器翻译 |
| **ollama** | 11434 | 8-16GB | LLM推理引擎 |
| **vision-service** | 7030 | 8-12GB | 图像处理 (可选) |

## 🛠️ 开发模式 vs 生产模式

### 开发模式 (源码运行)
```bash
# 开发机器
make dev            # 设置 + 启动开发环境

# GPU机器  
make gpu            # 设置 + 启动GPU服务
```

**优势：**
- ✅ 热重载，代码修改立即生效
- ✅ 便于调试和日志查看
- ✅ 资源占用较小
- ✅ 快速迭代开发

### 生产模式 (Docker运行)
```bash
# 开发机器
make docker-dev     # Docker启动开发环境

# GPU机器
make docker-gpu     # Docker启动GPU服务
```

**优势：**
- ✅ 环境完全一致
- ✅ 容器化隔离
- ✅ 自动重启和健康检查
- ✅ 易于扩展和部署

## 🔧 配置说明

### 环境变量配置
```bash
# 在.env文件中配置
GPU_MACHINE_IP=192.168.1.100      # GPU机器IP
POSTGRES_PASSWORD=your_password    # 数据库密码
MINIO_ACCESS_KEY=minioadmin       # 对象存储密钥
GRAFANA_PASSWORD=admin            # 监控面板密码
```

### GPU机器硬件需求
```yaml
最低配置:
  - GPU: RTX 3060 (12GB) 或同等级
  - 内存: 16GB RAM
  - 存储: 50GB 可用空间

推荐配置:
  - GPU: RTX 4080/4090 (16GB+)
  - 内存: 32GB RAM  
  - 存储: 100GB 可用空间
```

## 📊 监控和管理

### 健康检查
```bash
# 检查所有服务状态
make status

# 查看服务日志
make logs           # 开发机器日志
make logs-gpu       # GPU机器日志
```

### 性能监控
```bash
# 启动监控服务
make monitor

# 访问监控面板
# Grafana: http://localhost:3000
# Prometheus: http://localhost:9090
```

## 🔄 代码更新流程

### 开发机器更新
```bash
git pull origin main
make restart        # Docker模式
# 或
# 源码模式会自动热重载
```

### GPU机器更新
```bash
git pull origin main
make docker-gpu     # Docker模式重启
# 或
make gpu-dev        # 源码模式重启
```

## 🚀 扩展方案

### 多GPU机器负载均衡
```bash
# Nginx配置多个GPU后端
upstream ocr_backend {
    server 192.168.1.100:7010;
    server 192.168.1.101:7010;
}
```

### 微服务独立扩展
```bash
# 只扩展OCR服务
docker-compose -f docker-compose.gpu.yml up -d --scale ocr-service=3
```

## 📞 故障排查

### 常见问题
1. **GPU服务连接失败**
   ```bash
   # 检查网络连通性
   telnet 192.168.1.100 7010
   
   # 检查防火墙
   sudo ufw allow 7010:7030/tcp
   ```

2. **Docker GPU支持问题**
   ```bash
   # 检查nvidia-docker
   docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
   ```

3. **模型下载失败**
   ```bash
   # 手动下载Ollama模型
   ollama pull llama3.2:latest
   ```

## 🎉 部署完成验证

部署成功后，您应该能访问：

- 🌐 **主应用**: http://localhost (Nginx反向代理)
- 📊 **API文档**: http://localhost:8000/docs (Orchestrator)
- 📁 **文件服务**: http://localhost:8010/docs (File Service)
- 💾 **对象存储**: http://localhost:9001 (MinIO Console)
- 📈 **监控面板**: http://localhost:3000 (Grafana)

GPU机器服务：
- 🤖 **OCR服务**: http://gpu-ip:7010/docs
- 🔤 **翻译服务**: http://gpu-ip:7020/docs
- 🧠 **Ollama API**: http://gpu-ip:11434/api/tags

---

这个方案的核心优势：
- ✅ **开发友好**: 源码模式便于调试
- ✅ **生产稳定**: Docker模式保证一致性
- ✅ **部署简单**: 一键命令自动化
- ✅ **扩展灵活**: 支持多机器负载均衡
- ✅ **监控完善**: 完整的健康检查和监控