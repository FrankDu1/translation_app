#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
简单的微服务架构验证脚本
单独验证每个服务的代码是否正确
"""

import sys
import os
from pathlib import Path
import importlib.util

def test_import_modules():
    """测试各个服务模块是否可以正常导入"""
    
    print("🧪 微服务模块导入测试")
    print("=" * 50)
    
    services_dir = Path("services")
    
    # 测试OCR服务
    print("1. 🔍 测试OCR服务模块...")
    try:
        ocr_dir = services_dir / "ocr_service"
        sys.path.insert(0, str(ocr_dir))
        
        # 测试OCR引擎模块
        spec = importlib.util.spec_from_file_location("ocr_engine", ocr_dir / "ocr_engine.py")
        ocr_engine = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(ocr_engine)
        
        # 创建OCR引擎实例
        engine = ocr_engine.MultiOCREngine()
        available_engines = engine.get_available_engines()
        
        print(f"   ✅ OCR引擎模块正常")
        print(f"   📋 可用引擎: {available_engines}")
        print(f"   🎯 当前引擎: {engine.get_current_engine()}")
        
    except Exception as e:
        print(f"   ❌ OCR引擎模块错误: {e}")
    
    print()
    
    # 测试翻译服务
    print("2. 🌐 测试翻译服务模块...")
    try:
        nmt_dir = services_dir / "nmt_service"
        sys.path.insert(0, str(nmt_dir))
        
        # 设置环境变量
        os.environ.update({
            "USE_OLLAMA": "true",
            "OLLAMA_HOST": "http://localhost:11434",
            "OLLAMA_MODEL": "llama3:7b"
        })
        
        # 测试翻译器模块
        spec = importlib.util.spec_from_file_location("translator", nmt_dir / "translator.py")
        translator_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(translator_module)
        
        # 创建翻译器实例
        translator = translator_module.MultiTranslator()
        available_engines = translator.get_available_engines()
        supported_languages = translator.get_supported_languages()
        
        print(f"   ✅ 翻译引擎模块正常")
        print(f"   📋 可用引擎: {available_engines}")
        print(f"   🎯 当前引擎: {translator.get_current_engine()}")
        print(f"   🌍 支持语言: {list(supported_languages.keys())}")
        
    except Exception as e:
        print(f"   ❌ 翻译引擎模块错误: {e}")
    
    print()
    
    # 测试编排服务
    print("3. 🎭 测试编排服务模块...")
    try:
        orchestrator_dir = services_dir / "orchestrator"
        sys.path.insert(0, str(orchestrator_dir))
        
        # 设置环境变量
        os.environ.update({
            "OCR_URL": "http://localhost:7010/ocr",
            "TRANSLATE_URL": "http://localhost:7020/translate",
            "DEBUG": "true"
        })
        
        # 测试主模块
        spec = importlib.util.spec_from_file_location("main", orchestrator_dir / "app" / "main.py")
        main_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(main_module)
        
        # 检查FastAPI应用
        app = main_module.app
        
        print(f"   ✅ 编排服务模块正常")
        print(f"   📋 应用标题: {app.title}")
        print(f"   📋 应用版本: {app.version}")
        print(f"   🔗 OCR_URL: {os.getenv('OCR_URL')}")
        print(f"   🔗 TRANSLATE_URL: {os.getenv('TRANSLATE_URL')}")
        
    except Exception as e:
        print(f"   ❌ 编排服务模块错误: {e}")
    
    print()
    print("=" * 50)
    print("✨ 模块导入测试完成")

def show_startup_guide():
    """显示启动指南"""
    print("🚀 微服务启动指南")
    print("=" * 50)
    print("""
📋 手动启动步骤:

1️⃣ 启动OCR服务 (终端1):
   cd services/ocr_service
   python -m uvicorn server:app --host 0.0.0.0 --port 7010 --reload

2️⃣ 启动翻译服务 (终端2):
   cd services/nmt_service  
   python -m uvicorn server:app --host 0.0.0.0 --port 7020 --reload

3️⃣ 启动编排服务 (终端3):
   cd services/orchestrator
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

4️⃣ 测试服务:
   浏览器访问: http://localhost:8000/docs
   健康检查: curl http://localhost:8000/health

📝 VS Code启动:
   1. 打开 microservices.code-workspace
   2. 使用调试配置 "Run All Services (Host)"
   3. 或者分别启动各个服务的调试配置

🐳 Docker启动 (需要网络连接):
   docker compose -f docker/docker-compose.core.yml up --build

📱 快速测试:
   python test_microservices.py --test-apis
""")
    print("=" * 50)

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--guide":
        show_startup_guide()
    else:
        test_import_modules()
        print()
        show_startup_guide()

if __name__ == "__main__":
    main()