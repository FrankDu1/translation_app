# NMT服务 Dockerfile
FROM nvidia/cuda:11.8-devel-ubuntu20.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    curl \
    wget \
    git \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip3 install --no-cache-dir -r requirements.txt

# 安装翻译相关依赖
RUN pip3 install --no-cache-dir \
    torch \
    transformers \
    ctranslate2 \
    sentencepiece \
    sacremoses \
    httpx \
    asyncio

# 复制应用代码
COPY . .

# 创建必要的目录
RUN mkdir -p /app/models /app/temp /app/logs

# 设置权限
RUN chmod +x /app/entrypoint.sh

# 暴露端口
EXPOSE 7020

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:7020/health || exit 1

# 启动命令
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7020"]