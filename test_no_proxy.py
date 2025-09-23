#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
无代理环境下的直接测试脚本
"""

import os
import sys
import asyncio
from pathlib import Path
from PIL import Image
import json

def setup_no_proxy_environment():
    """设置无代理环境"""
    # 清除所有代理环境变量
    proxy_vars = ['HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy', 'ALL_PROXY', 'all_proxy']
    for var in proxy_vars:
        if var in os.environ:
            del os.environ[var]
    
    # 设置NO_PROXY
    os.environ['NO_PROXY'] = 'localhost,127.0.0.1,::1'
    print("🔄 已设置无代理环境")

async def test_ollama_direct():
    """直接测试Ollama连接"""
    import httpx
    
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            # 测试Ollama健康检查
            response = await client.get("http://127.0.0.1:11434/api/tags")
            if response.status_code == 200:
                models = response.json()
                print(f"✅ Ollama连接成功，可用模型: {[m['name'] for m in models['models']]}")
                return True
            else:
                print(f"❌ Ollama连接失败: {response.status_code}")
                return False
    except Exception as e:
        print(f"❌ Ollama连接异常: {e}")
        return False

async def test_translation_direct():
    """直接测试翻译功能"""
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'services', 'nmt_service'))
    
    from translator import OllamaTranslator
    
    translator = OllamaTranslator()
    
    test_texts = ["Hello World", "How are you?", "这是一个测试"]
    
    print("\n🔤 测试直接翻译功能...")
    for target_lang in ['zh', 'en', 'ja']:
        print(f"\n📝 翻译到 {target_lang}:")
        try:
            results = await translator.translate_batch(test_texts, target_lang, "auto")
            for orig, trans in zip(test_texts, results):
                print(f"  原文: {orig}")
                print(f"  译文: {trans}")
        except Exception as e:
            print(f"  ❌ 翻译失败: {e}")

async def main():
    """主函数"""
    print("🚀 无代理直接测试")
    print("=" * 60)
    
    # 设置无代理环境
    setup_no_proxy_environment()
    
    # 测试Ollama连接
    ollama_ok = await test_ollama_direct()
    
    if ollama_ok:
        # 测试翻译功能
        await test_translation_direct()
    else:
        print("⚠️ Ollama连接失败，跳过翻译测试")
    
    print("\n✨ 无代理测试完成")

if __name__ == "__main__":
    asyncio.run(main())