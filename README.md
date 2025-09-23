# 多文档/图片翻译微服务架构

## 项目概述

这是从单体Flask应用重构为微服务架构的文档翻译系统，支持图片、PDF、PPT等多种格式的智能翻译。

## 架构设计

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│                 │    │                  │    │                 │
│   Orchestrator  │◄──►│   OCR Service    │    │  NMT Service    │
│   (FastAPI)     │    │   (Multi-OCR)    │    │ (Multi-Engine)  │
│   Port: 8000    │    │   Port: 7010     │    │  Port: 7020     │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────────┐
                    │                     │
                    │   Docker Network    │
                    │      (core)         │
                    │                     │
                    └─────────────────────┘
```

## 快速开始

### 1. 环境准备

确保安装了以下依赖：
- Docker & Docker Compose
- Make (可选，用于快捷命令)
- Git

### 2. 启动服务

```bash
# 构建并启动所有服务
make build
make up

# 或者直接使用docker compose
docker compose -f docker/docker-compose.core.yml up -d --build
```

### 3. 验证服务

```bash
# 检查服务状态
make status

# 或手动检查
curl http://localhost:8000/health
curl http://localhost:7010/health  
curl http://localhost:7020/health
```

### 4. 测试翻译

```bash
# 上传图片进行翻译（需要准备测试图片）
make test

# 或手动测试
curl -F "file=@test.png" "http://localhost:8000/v1/process/image?target_lang=zh"
```

## 服务详情

### Orchestrator (编排服务)
- **端口**: 8000
- **功能**: 接收请求，协调OCR和翻译服务
- **技术栈**: FastAPI + httpx
- **主要端点**:
  - `GET /health` - 健康检查
  - `POST /v1/process/image` - 图片翻译
  - `GET /v1/services/status` - 服务状态

### OCR Service (文字识别服务)  
- **端口**: 7010
- **功能**: 多引擎OCR文字识别
- **支持引擎**: PaddleOCR、EasyOCR、Pytesseract
- **主要端点**:
  - `GET /health` - 健康检查
  - `POST /ocr` - OCR识别
  - `GET /engines` - 引擎列表

### NMT Service (翻译服务)
- **端口**: 7020  
- **功能**: 多引擎文本翻译
- **支持引擎**: Ollama、占位翻译器
- **主要端点**:
  - `GET /health` - 健康检查
  - `POST /translate` - 批量翻译
  - `GET /languages` - 支持语言

## VS Code 开发

### 开发模式启动

1. 打开VS Code，安装推荐插件
2. 使用 `Ctrl+Shift+P` → `Tasks: Run Task` → `Compose Up` 启动容器
3. 或使用调试配置 `Run All Services (Host)` 在本地Python环境运行

### 调试配置

- **单服务调试**: 选择对应的launch配置
- **多服务调试**: 使用compound配置同时启动所有服务  
- **容器调试**: 使用Docker插件attach到容器

## SSH隧道部署

### 配置隧道

1. 编辑 `infra/scripts/start_tunnel.sh`
2. 设置正确的远程服务器信息：
   ```bash
   REMOTE_USER="your_user"
   REMOTE_HOST="your.server.com"  
   ```

3. 启动隧道：
   ```bash
   make tunnel
   ```

### 云端Nginx配置

```nginx
location /api/ {
    proxy_pass http://127.0.0.1:18000/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}

location /ocr/ {
    proxy_pass http://127.0.0.1:18010/;
}

location /translate/ {
    proxy_pass http://127.0.0.1:18020/;
}
```

## 技术迁移

### 从单体应用复用的技术

- **OCR算法**: 来自 `advanced_image_translator.py`
- **翻译逻辑**: 来自现有Flask应用的Ollama集成
- **图片处理**: PIL + OpenCV的图像处理管线

### API兼容性

现有Flask应用的 `/translate-image` 端点可以通过代理映射到微服务：

```nginx
location /translate-image {
    proxy_pass http://127.0.0.1:18000/v1/process/image;
}
```

## 扩展计划

### 短期目标
- [ ] 替换OCR占位为完整PaddleOCR
- [ ] 集成CTranslate2 NLLB翻译引擎
- [ ] 添加PDF和PPT处理服务
- [ ] 引入Redis缓存层

### 中期目标  
- [ ] 添加vLLM后编辑服务
- [ ] 实现翻译记忆(TM)功能
- [ ] 支持API认证和用户管理
- [ ] 添加监控和日志聚合

### 长期目标
- [ ] Kubernetes部署支持
- [ ] 多语言支持扩展
- [ ] 实时协作翻译
- [ ] AI辅助术语管理

## 故障排除

### 常见问题

1. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tulpn | grep :8000
   # 修改docker-compose.yml中的端口映射
   ```

2. **OCR引擎不可用**
   ```bash
   # 查看OCR服务日志
   docker logs ocr
   # 检查引擎状态
   curl http://localhost:7010/engines
   ```

3. **翻译服务连接失败**
   ```bash
   # 检查Ollama是否运行
   curl http://localhost:11434/api/tags
   # 检查容器网络连接
   docker exec orchestrator curl http://nmt:7020/health
   ```

4. **隧道连接问题**
   ```bash
   # 检查SSH连接
   ssh -T user@your.server.com
   # 查看隧道日志
   journalctl -u ssh-tunnel -f
   ```

## 贡献指南

1. Fork项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)  
5. 打开Pull Request

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

## 联系方式

如有问题请提交Issue或联系项目维护者。