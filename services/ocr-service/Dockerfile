# OCR服务 Dockerfile
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
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libgl1-mesa-glx \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip3 install --no-cache-dir -r requirements.txt

# 安装OCR相关依赖
RUN pip3 install --no-cache-dir \
    easyocr \
    paddlepaddle-gpu \
    paddleocr \
    torch \
    torchvision \
    opencv-python-headless \
    pillow

# 复制应用代码
COPY . .

# 创建必要的目录
RUN mkdir -p /app/models /app/temp /app/logs

# 设置权限
RUN chmod +x /app/entrypoint.sh

# 预下载模型
RUN python3 -c "import easyocr; reader = easyocr.Reader(['ch_sim', 'en'], gpu=False, download_enabled=True)"

# 暴露端口
EXPOSE 7010

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:7010/health || exit 1

# 启动命令
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7010"]