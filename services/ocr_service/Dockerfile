FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖（用于OCR）
RUN apt-get update && apt-get install -y \
    libglib2.0-0 \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件并安装
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY server.py .
COPY ocr_engine.py .

# 设置环境变量
ENV PYTHONUNBUFFERED=1

EXPOSE 7010

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:7010/health || exit 1

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "7010"]