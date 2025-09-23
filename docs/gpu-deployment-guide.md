# GPU机器部署指南

## 🎯 GPU机器需要部署的服务

### 1. OCR服务 (Port: 7010)
```bash
# 依赖安装
pip install easyocr paddleocr torch torchvision
pip install transformers opencv-python pillow

# 服务特点
- 支持中英文OCR
- GPU加速推理
- 多引擎降级机制
- 内存需求: 4-8GB GPU
```

### 2. 翻译服务 (Port: 7020)
```bash
# Ollama安装
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llama3.2:latest
ollama pull qwen2.5:latest

# CTranslate2安装
pip install ctranslate2 transformers sentencepiece

# 服务特点
- 支持多种翻译引擎
- 批量翻译优化
- 内存需求: 8-16GB GPU
```

### 3. 图像处理服务 (Port: 7030)
```bash
# Stable Diffusion依赖
pip install diffusers accelerate xformers
pip install controlnet-aux

# 服务特点
- 图像修复和重绘
- 文字区域智能填充
- 内存需求: 8-12GB GPU
```

## 🔧 Nginx配置 (开发机器)

### /etc/nginx/sites-available/document-translator
```nginx
# 文档翻译服务 Nginx配置
upstream orchestrator_backend {
    server localhost:8000;
}

upstream file_service_backend {
    server localhost:8010;
}

# GPU机器的模型服务 (替换为实际GPU机器IP)
upstream ocr_service_backend {
    server 192.168.1.100:7010;  # GPU机器IP
}

upstream nmt_service_backend {
    server 192.168.1.100:7020;  # GPU机器IP
}

upstream vision_service_backend {
    server 192.168.1.100:7030;  # GPU机器IP
}

server {
    listen 80;
    server_name localhost document-translator.local;
    
    # 前端静态文件
    location / {
        root /var/www/document-translator/frontend/dist;
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    # API网关 - 编排服务
    location /api/ {
        proxy_pass http://orchestrator_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 长时间请求支持
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        
        # 大文件上传
        client_max_body_size 100M;
    }
    
    # 文件服务
    location /files/ {
        proxy_pass http://file_service_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # 大文件上传
        client_max_body_size 100M;
    }
    
    # OCR服务代理 (到GPU机器)
    location /ocr/ {
        proxy_pass http://ocr_service_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # OCR可能需要较长时间
        proxy_read_timeout 120s;
        proxy_connect_timeout 30s;
    }
    
    # 翻译服务代理 (到GPU机器)
    location /translate/ {
        proxy_pass http://nmt_service_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # 翻译可能需要较长时间
        proxy_read_timeout 180s;
        proxy_connect_timeout 30s;
    }
    
    # 图像处理服务代理 (到GPU机器)
    location /vision/ {
        proxy_pass http://vision_service_backend/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # 图像处理需要很长时间
        proxy_read_timeout 300s;
        proxy_connect_timeout 30s;
    }
    
    # 健康检查
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # WebSocket支持 (如果需要实时更新)
    location /ws/ {
        proxy_pass http://orchestrator_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

# HTTPS配置 (生产环境)
server {
    listen 443 ssl http2;
    server_name document-translator.yourdomain.com;
    
    ssl_certificate /etc/ssl/certs/document-translator.crt;
    ssl_certificate_key /etc/ssl/private/document-translator.key;
    
    # SSL安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # 重定向到上面的配置
    location / {
        proxy_pass http://localhost:80;
    }
}
```

## 🐳 Docker Compose (GPU机器)

### gpu-services/docker-compose.yml
```yaml
version: '3.8'

services:
  ocr-service:
    build: ./ocr-service
    ports:
      - "7010:7010"
    environment:
      - CUDA_VISIBLE_DEVICES=0
      - PYTHONPATH=/app
    volumes:
      - ./models:/app/models
      - ./temp:/app/temp
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7010/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nmt-service:
    build: ./nmt-service
    ports:
      - "7020:7020"
    environment:
      - CUDA_VISIBLE_DEVICES=0
      - OLLAMA_HOST=http://localhost:11434
    volumes:
      - ./models:/app/models
      - ./temp:/app/temp
      - ollama_data:/root/.ollama
    depends_on:
      - ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped

  vision-service:
    build: ./vision-service
    ports:
      - "7030:7030"
    environment:
      - CUDA_VISIBLE_DEVICES=0
      - HF_HOME=/app/models/huggingface
    volumes:
      - ./models:/app/models
      - ./temp:/app/temp
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped

  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    environment:
      - CUDA_VISIBLE_DEVICES=0
    volumes:
      - ollama_data:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped

volumes:
  ollama_data:
```

## 🔄 部署流程

### 第一阶段: 开发机器框架搭建
1. 完善Orchestrator服务
2. 开发File Service
3. 搭建前端界面
4. 配置Nginx反向代理
5. 设置PostgreSQL + Redis

### 第二阶段: GPU机器模型部署
1. 部署OCR服务 (EasyOCR + PaddleOCR)
2. 部署翻译服务 (Ollama + CTranslate2)
3. 部署图像处理服务
4. 配置服务发现和健康检查

### 第三阶段: 联调测试
1. 网络连通性测试
2. 端到端功能测试
3. 性能和负载测试
4. 监控和日志配置