#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
微服务架构本地测试脚本
不依赖Docker，直接在本地启动各个服务进行测试
"""

import subprocess
import time
import requests
import sys
import os
from pathlib import Path

def test_service_locally():
    """在本地测试微服务架构"""
    
    print("🚀 开始微服务架构本地测试")
    print("=" * 60)
    
    # 设置环境变量
    os.environ.update({
        "OCR_URL": "http://localhost:7010/ocr",
        "TRANSLATE_URL": "http://localhost:7020/translate", 
        "OLLAMA_HOST": "http://localhost:11434",
        "OLLAMA_MODEL": "llama3:7b",
        "USE_OLLAMA": "true",
        "DEBUG": "true"
    })
    
    services_dir = Path("services")
    
    print("📋 准备启动的服务:")
    print("  - OCR Service (7010)")
    print("  - NMT Service (7020)")
    print("  - Orchestrator (8000)")
    print()
    
    # 检查Ollama是否运行
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            print("✅ Ollama服务运行正常")
        else:
            print("⚠️ Ollama服务响应异常")
    except:
        print("❌ Ollama服务未运行，翻译服务将使用占位模式")
    
    print("\n" + "="*60)
    print("🔧 服务启动说明:")
    print("1. 请在3个不同的终端窗口手动启动以下命令:")
    print() 
    print("终端1 - OCR Service:")
    print(f"cd {services_dir}/ocr_service")
    print("python -m uvicorn server:app --host 0.0.0.0 --port 7010 --reload")
    print()
    print("终端2 - NMT Service:")  
    print(f"cd {services_dir}/nmt_service")
    print("python -m uvicorn server:app --host 0.0.0.0 --port 7020 --reload")
    print()
    print("终端3 - Orchestrator:")
    print(f"cd {services_dir}/orchestrator")
    print("python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload")
    print()
    print("2. 启动完成后，运行以下命令测试:")
    print("python test_microservices.py --test-apis")
    print()
    print("=" * 60)

def test_apis():
    """测试API端点"""
    print("🧪 开始API测试")
    print("=" * 40)
    
    # 测试各服务健康检查
    services = [
        ("OCR Service", "http://localhost:7010/health"),
        ("NMT Service", "http://localhost:7020/health"), 
        ("Orchestrator", "http://localhost:8000/health")
    ]
    
    for name, url in services:
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                print(f"✅ {name}: 运行正常")
                print(f"   响应: {response.json()}")
            else:
                print(f"❌ {name}: 响应异常 ({response.status_code})")
        except Exception as e:
            print(f"❌ {name}: 连接失败 - {e}")
        print()
    
    # 测试服务状态端点
    try:
        print("🔍 测试服务状态检查...")
        response = requests.get("http://localhost:8000/v1/services/status", timeout=15)
        if response.status_code == 200:
            print("✅ 服务状态检查成功:")
            status = response.json()
            for service, info in status.items():
                print(f"   {service}: {info.get('status', 'unknown')}")
        else:
            print(f"❌ 服务状态检查失败: {response.status_code}")
    except Exception as e:
        print(f"❌ 服务状态检查出错: {e}")
    
    print("\n" + "=" * 40)
    print("✨ API测试完成")

def show_architecture():
    """显示架构图"""
    print("🏗️ 微服务架构图")
    print("=" * 50)
    print("""
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│                 │    │                  │    │                 │
│   Orchestrator  │◄──►│   OCR Service    │    │  NMT Service    │
│   (FastAPI)     │    │   (Multi-OCR)    │    │ (Multi-Engine)  │
│   Port: 8000    │    │   Port: 7010     │    │  Port: 7020     │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
    处理图片请求              OCR文字识别              文本翻译
    编排服务调用              返回文字区域              返回翻译结果
    合并最终结果              支持多引擎               支持Ollama
""")
    print("=" * 50)

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--test-apis":
        test_apis()
    elif len(sys.argv) > 1 and sys.argv[1] == "--architecture":
        show_architecture()
    else:
        show_architecture()
        test_service_locally()

if __name__ == "__main__":
    main()