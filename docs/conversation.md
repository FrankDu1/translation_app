# 项目对话上下文（完整版）

> 提示：这是从单体Flask应用到微服务架构的完整迁移记录。可以把完整聊天记录粘贴进来，后续用 Copilot Chat 选中段落作为上下文。

## 项目演进历程

### 第一阶段：单体Flask应用
- **目标**：文档上传、Ollama大模型中英互译、PDF格式保持
- **技术栈**：Flask 2.3.3 + OpenWebUI风格前端 + Ollama远程API
- **核心功能**：
  - PDF翻译（多代算法迭代，最终全新引擎）
  - 图片翻译（OCR + 文字替换）
  - 支持中英文切换、自动语言检测

### 第二阶段：图片翻译攻坚
- **挑战**：PDF格式保持困难，用户建议先做图片/PPT翻译
- **技术突破**：
  - OCR自动识别：PaddleOCR、EasyOCR、Pytesseract多引擎支持
  - 智能文字替换：inpainting技术、背景智能分析、精确位置定位
  - 手动输入模式：OCR失败时友好回退
  - 视觉效果提升：圆角背景、文字阴影、动态对比度

### 第三阶段：微服务架构重构（当前阶段）
- **架构模式**：方案C（集中多模型后端 + Orchestrator）
- **服务拆分**：
  - orchestrator: FastAPI聚合调用OCR/翻译
  - ocr_service: PaddleOCR服务（初期占位）
  - nmt_service: 翻译服务（支持Ollama后编辑）
- **部署策略**：本地GPU Docker Compose + SSH反向隧道暴露到云Nginx

## 核心技术积累

### 已实现的图片翻译技术
1. **多OCR引擎支持**
   ```python
   # advanced_image_translator.py 核心方法
   - detect_text_regions(): 多引擎OCR检测
   - find_best_text_match(): 智能文字匹配
   - replace_text_in_region(): 精确文字替换
   ```

2. **智能背景处理**
   ```python
   # 核心算法
   - _analyze_background_color(): 多区域采样
   - _generate_smart_background(): inpainting + 渐变纹理
   - _advanced_text_replacement(): 动态字体自适应
   ```

3. **手动输入模式优化**
   ```python
   # 视觉效果提升
   - _simple_text_overlay(): 智能字体大小、自动换行
   - _draw_rounded_rectangle(): 圆角背景效果
   ```

### 文件结构（当前单体应用）
```
document-translator/
├── app.py                           # Flask主应用
├── advanced_image_translator.py     # 图片翻译核心引擎
├── advanced_pdf_translator.py       # PDF翻译引擎
├── templates/                       # 前端模板
├── static/                          # 静态资源
├── uploads/                         # 上传文件
├── downloads/                       # 下载文件
└── requirements.txt                 # 依赖列表
```

## 微服务架构设计

### 服务模块
- **orchestrator**: FastAPI 聚合调用 OCR / 翻译
- **ocr_service**: PaddleOCR（复用现有 advanced_image_translator.py 的OCR逻辑）
- **nmt_service**: 翻译占位（后续接 CTranslate2 或 Ollama 后编辑）
- **（待加）redis/postgres/minio**：TM 缓存 / 元数据 / 文件存储

### 流程设计
```
upload image -> orchestrator.save temp -> call /ocr -> lines -> call /translate -> merge -> 返回 JSON
```

### 对外暴露
```
Nginx (云) -> SSH Reverse Tunnel 端口 -> 本地 orchestrator:8000
```

## 技术债务和改进点

### 当前单体应用的问题
1. **OCR依赖安装复杂**：PaddleOCR权限问题，Windows下tesseract不可用
2. **翻译质量**：目前主要依赖Ollama，需要更专业的NMT引擎
3. **PDF格式保持**：虽然有多代算法，但仍然复杂度高
4. **扩展性**：单体架构难以独立扩展各个模块

### 微服务化收益
1. **服务独立扩展**：OCR、翻译、后处理可独立优化
2. **技术栈灵活**：各服务可选择最适合的技术
3. **部署灵活**：GPU资源可按需分配
4. **开发效率**：团队可并行开发不同服务

## 下一步计划（当前阶段）

### 立即执行
1. 本地跑 orchestrator + ocr + nmt 占位
2. 建立隧道，云上通过 https://chat.offerupup.cn/api/ 调用
3. 将现有 advanced_image_translator.py 的OCR逻辑迁移到 ocr_service
4. 集成现有的Ollama翻译逻辑到 nmt_service

### 后续优化
1. 替换 OCR 为独立的 PaddleOCR 服务
2. 接入真实翻译引擎：CTranslate2 NLLB
3. 添加 vLLM 后编辑服务
4. 引入 TM（翻译记忆）和缓存机制

## 技术选型决策

### OCR引擎选择
- **PaddleOCR**: 中文效果好，但安装复杂
- **EasyOCR**: 跨平台好，但准确率中等
- **Pytesseract**: 轻量但需要系统依赖

### 翻译引擎演进
1. **阶段1**: Ollama占位（当前）
2. **阶段2**: CTranslate2 + NLLB（专业NMT）
3. **阶段3**: vLLM + Qwen（后编辑）

### 部署策略
- **本地开发**: Docker Compose
- **生产部署**: SSH反向隧道 + 云端Nginx
- **未来**: K8s集群（可选）

---

*此文档将持续更新，记录关键设计决策和技术演进路径。*