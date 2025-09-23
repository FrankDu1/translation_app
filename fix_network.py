#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
网络问题诊断和修复工具
"""

import os
import requests
import subprocess
import time

def diagnose_network_issues():
    """诊断网络连接问题"""
    
    print("🔍 网络连接问题诊断")
    print("=" * 50)
    
    # 检查代理设置
    print("1. 📡 检查代理设置...")
    proxy_vars = ['HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy']
    proxy_found = False
    
    for var in proxy_vars:
        value = os.environ.get(var)
        if value:
            print(f"   发现代理设置: {var}={value}")
            proxy_found = True
    
    if not proxy_found:
        print("   ✅ 环境变量中无代理设置")
    
    # 检查本地服务连通性
    print("\n2. 🔗 检查本地服务连通性...")
    services = [
        ("OCR Service", "http://localhost:7010/health"),
        ("NMT Service", "http://localhost:7020/health"),
        ("Orchestrator", "http://localhost:8000/health")
    ]
    
    for name, url in services:
        try:
            # 直接连接，绕过代理
            response = requests.get(url, timeout=5, proxies={})
            if response.status_code == 200:
                print(f"   ✅ {name}: 直连正常")
            else:
                print(f"   ⚠️ {name}: 响应异常 ({response.status_code})")
        except Exception as e:
            print(f"   ❌ {name}: 连接失败 - {e}")
    
    # 检查服务间通信
    print("\n3. 🔄 检查服务间通信...")
    try:
        # 测试orchestrator到OCR的连接
        response = requests.get("http://localhost:8000/v1/services/status", timeout=10, proxies={})
        if response.status_code == 200:
            status = response.json()
            print("   📊 服务状态检查:")
            for service, info in status.items():
                status_text = info.get('status', 'unknown')
                error = info.get('error', '')
                print(f"      {service}: {status_text}")
                if error:
                    print(f"         错误: {error}")
        else:
            print(f"   ❌ 服务状态检查失败: {response.status_code}")
    except Exception as e:
        print(f"   ❌ 服务状态检查异常: {e}")

def fix_proxy_issues():
    """修复代理问题"""
    
    print("\n🔧 代理问题修复")
    print("=" * 30)
    
    # 方案1: 为Python进程设置无代理环境
    print("1. 设置Python无代理环境...")
    
    # 清除代理环境变量
    proxy_vars = ['HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy', 'ALL_PROXY', 'all_proxy']
    for var in proxy_vars:
        if var in os.environ:
            del os.environ[var]
            print(f"   清除: {var}")
    
    # 设置no_proxy，确保本地地址不走代理
    os.environ['NO_PROXY'] = 'localhost,127.0.0.1,0.0.0.0'
    os.environ['no_proxy'] = 'localhost,127.0.0.1,0.0.0.0'
    print("   设置: NO_PROXY=localhost,127.0.0.1,0.0.0.0")
    
    print("   ✅ 代理环境变量已清理")

def create_no_proxy_services():
    """创建无代理版本的服务启动脚本"""
    
    print("\n📝 创建无代理服务启动脚本...")
    
    # 创建无代理启动脚本
    script_content = '''@echo off
echo 🚫 启动无代理微服务
echo =========================

:: 清除所有代理设置
set HTTP_PROXY=
set HTTPS_PROXY=
set http_proxy=
set https_proxy=
set ALL_PROXY=
set all_proxy=

:: 设置无代理列表
set NO_PROXY=localhost,127.0.0.1,0.0.0.0
set no_proxy=localhost,127.0.0.1,0.0.0.0

echo ✅ 代理设置已清除
echo 📡 NO_PROXY设置为: %NO_PROXY%

:: 杀死现有进程
echo 🛑 停止现有服务...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :7010') do taskkill /f /pid %%a >nul 2>&1
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :7020') do taskkill /f /pid %%a >nul 2>&1  
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :8000') do taskkill /f /pid %%a >nul 2>&1

timeout /t 3 >nul

:: 启动服务
echo 🚀 启动无代理微服务...

start "OCR Service (No Proxy)" cmd /k "cd services\\ocr_service && python -m uvicorn server:app --host 0.0.0.0 --port 7010 --reload"
timeout /t 2 >nul

start "NMT Service (No Proxy)" cmd /k "cd services\\nmt_service && python -m uvicorn server:app --host 0.0.0.0 --port 7020 --reload"  
timeout /t 2 >nul

start "Orchestrator (No Proxy)" cmd /k "cd services\\orchestrator && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
timeout /t 3 >nul

echo ✨ 无代理微服务启动完成！
echo 🧪 测试命令: python test_no_proxy.py
pause
'''
    
    with open("start_no_proxy.bat", "w", encoding="utf-8") as f:
        f.write(script_content)
    
    print("   ✅ 创建完成: start_no_proxy.bat")

def test_no_proxy_connection():
    """测试无代理连接"""
    
    print("\n🧪 测试无代理连接...")
    
    # 等待服务启动
    print("   ⏳ 等待服务启动...")
    time.sleep(5)
    
    # 测试连接
    services = [
        ("OCR Service", "http://localhost:7010/health"),
        ("NMT Service", "http://localhost:7020/health"),
        ("Orchestrator", "http://localhost:8000/health")
    ]
    
    all_ok = True
    for name, url in services:
        try:
            # 明确指定不使用代理
            response = requests.get(url, timeout=5, proxies={
                'http': None,
                'https': None
            })
            if response.status_code == 200:
                print(f"   ✅ {name}: 连接正常")
            else:
                print(f"   ⚠️ {name}: 响应异常 ({response.status_code})")
                all_ok = False
        except Exception as e:
            print(f"   ❌ {name}: 连接失败 - {e}")
            all_ok = False
    
    return all_ok

def main():
    """主诊断流程"""
    
    print("🩺 微服务网络问题诊断工具")
    print("=" * 60)
    
    # 步骤1: 诊断问题
    diagnose_network_issues()
    
    # 步骤2: 修复代理设置
    fix_proxy_issues()
    
    # 步骤3: 创建无代理启动脚本
    create_no_proxy_services()
    
    print("\n" + "=" * 60)
    print("🎯 问题分析和解决方案:")
    print()
    print("❌ 问题: Privoxy代理配置错误，导致服务间通信失败")
    print()
    print("✅ 解决方案:")
    print("1. 运行无代理启动脚本: start_no_proxy.bat")
    print("2. 或者手动清除代理设置后重启服务")
    print("3. 确保本地地址(localhost, 127.0.0.1)不走代理")
    print()
    print("🚀 下一步:")
    print("1. 运行: start_no_proxy.bat")
    print("2. 测试: python test_e2e.py")
    print("3. 验证: 访问 http://localhost:8000/docs")

if __name__ == "__main__":
    main()