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
