# 架构要点速览

## 模块架构
- **orchestrator**: FastAPI 聚合调用 OCR / 翻译
- **ocr_service**: PaddleOCR（复用现有advanced_image_translator.py的OCR逻辑）
- **nmt_service**: 翻译占位（后续接 CTranslate2 或 Ollama 后编辑）
- **（待加）redis/postgres/minio**：TM 缓存 / 元数据 / 文件存储

## 核心流程
```
upload image -> orchestrator.save temp -> call /ocr -> lines -> call /translate -> merge -> 返回 JSON
```

## 对外暴露
```
Nginx (云) -> SSH Reverse Tunnel 端口 -> 本地 orchestrator:8000
```

## 版本控制
- models.yaml 注册模型端点与版本
- 镜像 tag: `<service>-<version>`

## 现有技术资产复用

### 图片翻译核心算法（来自advanced_image_translator.py）
```python
# OCR检测逻辑
detect_text_regions()      # 多引擎OCR支持
find_best_text_match()     # 智能文字匹配

# 文字替换算法  
replace_text_in_region()   # 精确区域替换
_analyze_background_color() # 智能背景分析
_generate_smart_background() # inpainting技术
_advanced_text_replacement() # 动态字体自适应
```

### Flask应用迁移策略
```python
# 当前Flask路由 -> 微服务映射
/translate-image -> orchestrator:/v1/process/image
OCR逻辑 -> ocr_service:/ocr  
翻译逻辑 -> nmt_service:/translate
```

## 服务间通信
- **协议**: HTTP REST API
- **格式**: JSON
- **超时**: OCR 60s, 翻译 120s
- **重试**: 各服务内部处理

## 数据流设计

### 图片处理流程
1. **上传**: `orchestrator` 接收文件，保存临时文件
2. **OCR**: 调用 `ocr_service`，返回文字区域数组
3. **翻译**: 调用 `nmt_service`，批量翻译文字
4. **合并**: 组装最终结果，包含位置、原文、译文
5. **返回**: JSON格式，前端可直接渲染

### 错误处理策略
- **OCR失败**: 返回空数组，前端提示手动输入
- **翻译失败**: 返回原文，标记翻译失败
- **服务不可用**: 降级到占位模式或错误提示

## 部署环境
- **开发**: VS Code + Docker Compose
- **生产**: SSH隧道 + 云端Nginx代理
- **监控**: 各服务health端点 + 日志聚合

## 后续待办

### 技术升级路径
1. **真 OCR**: 迁移到独立PaddleOCR服务
2. **真翻译**: CTranslate2 NLLB替换占位
3. **LLM 后编辑**: vLLM Qwen风格优化
4. **PDF/PPT/Docx**: 新增文档抽取模块
5. **术语 / TM / 缓存**: Redis + PostgreSQL

### 性能优化
- **并发处理**: 异步调用，批量翻译
- **缓存策略**: TM缓存，减少重复翻译
- **资源管理**: GPU内存池，模型预加载

### 扩展功能
- **API认证**: JWT Token或API Key
- **用户管理**: 多租户支持
- **文件存储**: MinIO对象存储
- **监控告警**: Prometheus + Grafana