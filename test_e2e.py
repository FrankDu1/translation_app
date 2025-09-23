#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
端到端微服务图片翻译测试
"""

import requests
import json
import time
from pathlib import Path

def test_image_translation():
    """测试完整的图片翻译流程"""
    
    print("🖼️ 微服务图片翻译端到端测试")
    print("=" * 60)
    
    # 检查测试图片
    test_image_path = Path("../test.PNG")
    if not test_image_path.exists():
        print(f"❌ 测试图片不存在: {test_image_path}")
        print("💡 请将测试图片放在上级目录，文件名为 test.PNG")
        return False
    
    print(f"📁 使用测试图片: {test_image_path}")
    print(f"📊 图片大小: {test_image_path.stat().st_size} bytes")
    
    # 测试参数
    orchestrator_url = "http://localhost:8000"
    target_languages = ["zh", "en", "ja"]
    
    for target_lang in target_languages:
        print(f"\n🌐 测试翻译目标语言: {target_lang}")
        print("-" * 40)
        
        start_time = time.time()
        
        try:
            # 发送翻译请求
            with open(test_image_path, 'rb') as f:
                files = {'file': ('test.PNG', f, 'image/png')}
                params = {'target_lang': target_lang}
                
                print("📤 发送翻译请求...")
                response = requests.post(
                    f"{orchestrator_url}/v1/process/image",
                    files=files,
                    params=params,
                    timeout=60
                )
            
            processing_time = time.time() - start_time
            
            if response.status_code == 200:
                result = response.json()
                
                print(f"✅ 翻译成功！")
                print(f"⏱️ 处理时间: {processing_time:.2f}s")
                print(f"🆔 图片ID: {result.get('image_id', 'N/A')}")
                print(f"📝 识别行数: {result.get('line_count', 0)}")
                print(f"⚡ 服务处理时间: {result.get('processing_time_ms', 0)}ms")
                
                # 显示翻译结果
                items = result.get('items', [])
                if items:
                    print(f"📋 翻译结果:")
                    for i, item in enumerate(items[:3], 1):  # 只显示前3条
                        src_text = item.get('src', '')
                        tgt_text = item.get('tgt', '')
                        conf = item.get('conf', 0)
                        bbox = item.get('bbox', [])
                        
                        print(f"  {i}. 原文: '{src_text}'")
                        print(f"     译文: '{tgt_text}'")
                        print(f"     置信度: {conf:.2f}")
                        print(f"     位置: {bbox}")
                        print()
                else:
                    print("📝 没有识别到文字（这是正常的，OCR使用占位模式）")
                
            else:
                print(f"❌ 翻译失败: {response.status_code}")
                print(f"📄 错误详情: {response.text}")
                
        except requests.exceptions.Timeout:
            print(f"⏰ 请求超时 (>{60}s)")
        except Exception as e:
            print(f"❌ 请求异常: {e}")
    
    print("\n" + "=" * 60)
    print("✨ 端到端测试完成")
    
    # 显示API使用示例
    print("\n📚 API使用示例:")
    print("curl命令:")
    print(f'curl -X POST \\')
    print(f'  "http://localhost:8000/v1/process/image?target_lang=zh" \\')
    print(f'  -F "file=@test.PNG" \\')
    print(f'  -H "accept: application/json"')
    
    print("\nPython请求:")
    print("""
import requests

with open('test.PNG', 'rb') as f:
    files = {'file': ('test.PNG', f, 'image/png')}
    params = {'target_lang': 'zh'}
    response = requests.post(
        'http://localhost:8000/v1/process/image',
        files=files, 
        params=params
    )
    result = response.json()
    print(result)
""")

def test_individual_services():
    """测试各个服务的独立功能"""
    
    print("\n🔧 独立服务功能测试")
    print("=" * 40)
    
    # 测试OCR服务
    print("1. 🔍 测试OCR服务...")
    try:
        with open("../test.PNG", 'rb') as f:
            files = {'file': ('test.PNG', f, 'image/png')}
            response = requests.post("http://localhost:7010/ocr", files=files, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ OCR识别成功")
            print(f"   📝 识别块数: {len(result.get('blocks', []))}")
            print(f"   🔧 使用引擎: {result.get('engine', 'unknown')}")
        else:
            print(f"   ❌ OCR识别失败: {response.status_code}")
    except Exception as e:
        print(f"   ❌ OCR测试异常: {e}")
    
    # 测试翻译服务
    print("\n2. 🌐 测试翻译服务...")
    try:
        test_data = {
            "lines": ["Hello World", "This is a test", "机器翻译"],
            "target_lang": "zh"
        }
        response = requests.post(
            "http://localhost:7020/translate", 
            json=test_data, 
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ 翻译成功")
            print(f"   🔧 使用引擎: {result.get('engine', 'unknown')}")
            print(f"   📝 翻译结果:")
            for i, translation in enumerate(result.get('translations', [])):
                print(f"      {i+1}. {translation}")
        else:
            print(f"   ❌ 翻译失败: {response.status_code}")
    except Exception as e:
        print(f"   ❌ 翻译测试异常: {e}")

def main():
    """主测试函数"""
    test_image_translation()
    test_individual_services()

if __name__ == "__main__":
    main()