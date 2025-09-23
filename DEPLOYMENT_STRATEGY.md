# 🚀 Document Translator - 部署方案

## 📦 Git + Docker 双重部署策略

### 🎯 部署架构
```
开发机器 (您当前的机器)           GPU机器 (远程部署)
┌─────────────────────────┐    ┌─────────────────────────┐
│  📂 Git Repository      │    │  📂 Git Clone          │
│  🐳 Docker Compose     │────│  🐳 GPU Docker Services │
│  🌐 Nginx              │    │  🤖 Model Services     │
│  💾 Database/Cache     │    │                         │
└─────────────────────────┘    └─────────────────────────┘
```

## 🌟 推荐部署流程

### 第一步：创建Git仓库
```bash
# 在GitHub/GitLab创建仓库
# 仓库名: document-translator-microservices

# 本地推送代码
git init
git add .
git commit -m "Initial microservices architecture"
git remote add origin https://github.com/yourusername/document-translator-microservices.git
git push -u origin main
```

### 第二步：GPU机器一键部署
```bash
# GPU机器上执行
git clone https://github.com/yourusername/document-translator-microservices.git
cd document-translator-microservices/microservices

# 方式1: Docker部署 (推荐生产环境)
make docker-gpu

# 方式2: 源码部署 (推荐开发调试)
make setup-gpu-dev
```

## 🐳 Docker配置完善

### GPU机器 Docker 配置
- ✅ 多GPU支持和资源限制
- ✅ 模型文件持久化存储
- ✅ 健康检查和自动重启
- ✅ 日志收集和监控
- ✅ 环境变量配置

### 开发机器 Docker 配置
- ✅ 数据库和缓存服务
- ✅ 反向代理配置
- ✅ 开发环境热重载
- ✅ 数据持久化

## 📋 部署选项对比

| 场景 | 开发机器 | GPU机器 | 命令 |
|------|----------|---------|------|
| **快速开发** | 源码运行 | 源码运行 | `make dev` |
| **生产部署** | Docker | Docker | `make prod` |
| **混合模式** | 源码运行 | Docker | `make hybrid` |
| **调试模式** | 源码运行 | 源码运行 | `make debug` |

## 🔧 一键部署脚本

### 开发机器
```bash
# 克隆仓库后
make setup-dev        # 设置开发环境
make start-dev         # 启动开发服务
```

### GPU机器
```bash
# 克隆仓库后
make setup-gpu         # 检查GPU环境
make docker-gpu        # Docker方式启动
# 或
make setup-gpu-dev     # 源码方式启动
```

## 📱 远程管理

### SSH隧道 (开发调试)
```bash
# 开发机器访问GPU机器服务
ssh -L 7010:localhost:7010 -L 7020:localhost:7020 gpu-machine
```

### 监控面板
```bash
# 启动监控
make monitor
# 访问: http://localhost:3000 (Grafana)
```

---

## 🎯 核心优势

1. **灵活部署**: 支持Docker和源码两种方式
2. **一键操作**: 简化的Makefile命令
3. **环境一致**: Docker保证环境一致性
4. **快速调试**: 源码模式便于开发调试
5. **远程管理**: 完整的监控和管理工具

这种方案让您可以：
- 🚀 快速在GPU机器上部署服务
- 🔄 方便地同步代码更新
- 🐳 生产环境使用Docker保证稳定性
- 🛠️ 开发时使用源码模式便于调试