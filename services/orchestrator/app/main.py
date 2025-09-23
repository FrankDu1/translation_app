from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from fastapi.responses import JSONResponse
import httpx
import os
import uuid
import json
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from pathlib import Path
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 环境变量配置
OCR_URL = os.getenv("OCR_URL", "http://ocr:7010/ocr")
TRANSLATE_URL = os.getenv("TRANSLATE_URL", "http://nmt:7020/translate")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

app = FastAPI(
    title="Document Translation Orchestrator", 
    version="1.0.0",
    description="微服务架构的文档翻译编排服务"
)

class TranslationItem(BaseModel):
    """翻译结果项"""
    bbox: List[int]  # [x1, y1, x2, y2]
    src: str         # 原文
    tgt: str         # 译文  
    conf: float      # 置信度

class ProcessResult(BaseModel):
    """处理结果"""
    image_id: str
    line_count: int
    items: List[TranslationItem]
    processing_time_ms: int

@app.get("/health")
async def health():
    """健康检查端点"""
    return {
        "status": "ok",
        "service": "orchestrator",
        "version": "1.0.0",
        "ocr_url": OCR_URL,
        "translate_url": TRANSLATE_URL
    }

@app.get("/")
async def root():
    """根路径"""
    return {
        "message": "Document Translation Orchestrator API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "process_image": "/v1/process/image",
            "docs": "/docs"
        }
    }

@app.post("/v1/process/image", response_model=ProcessResult)
async def process_image(
    file: UploadFile = File(...), 
    target_lang: str = Query(default="zh", description="目标语言")
):
    """
    处理图片翻译
    
    流程：
    1. 保存上传的图片
    2. 调用OCR服务识别文字
    3. 调用翻译服务翻译文字
    4. 合并结果返回
    """
    import time
    start_time = time.time()
    
    try:
        # 生成唯一ID
        image_id = str(uuid.uuid4())
        
        # 保存上传文件
        content = await file.read()
        
        # 确保uploads目录存在
        uploads_dir = Path("uploads")
        uploads_dir.mkdir(exist_ok=True)
        
        tmp_path = uploads_dir / f"{image_id}_{file.filename}"
        
        with open(tmp_path, "wb") as f:
            f.write(content)
        
        logger.info(f"图片已保存: {tmp_path}, 大小: {len(content)} bytes")
        
        # 调用OCR服务
        logger.info(f"调用OCR服务: {OCR_URL}")
        async with httpx.AsyncClient(timeout=60, proxies={}) as client:
            with open(tmp_path, "rb") as f:
                ocr_resp = await client.post(
                    OCR_URL, 
                    files={"file": (file.filename, f, file.content_type)}
                )
        
        if ocr_resp.status_code != 200:
            logger.error(f"OCR服务错误: {ocr_resp.status_code} - {ocr_resp.text}")
            raise HTTPException(500, f"OCR error: {ocr_resp.text}")
        
        ocr_data = ocr_resp.json()
        blocks = ocr_data.get("blocks", [])
        lines = [block["text"] for block in blocks if block["text"].strip()]
        
        logger.info(f"OCR识别到 {len(lines)} 行文字")
        
        if not lines:
            # 没有识别到文字，返回空结果
            processing_time = int((time.time() - start_time) * 1000)
            return ProcessResult(
                image_id=image_id,
                line_count=0,
                items=[],
                processing_time_ms=processing_time
            )
        
        # 调用翻译服务
        logger.info(f"调用翻译服务: {TRANSLATE_URL}")
        async with httpx.AsyncClient(timeout=120, proxies={}) as client:
            trans_resp = await client.post(
                TRANSLATE_URL, 
                json={"lines": lines, "target_lang": target_lang}
            )
        
        if trans_resp.status_code != 200:
            logger.error(f"翻译服务错误: {trans_resp.status_code} - {trans_resp.text}")
            raise HTTPException(500, f"Translate error: {trans_resp.text}")
        
        translation_data = trans_resp.json()
        translations = translation_data.get("translations", [])
        
        logger.info(f"翻译完成，共 {len(translations)} 条")
        
        # 合并OCR和翻译结果
        merged_items = []
        for i, (block, translation) in enumerate(zip(blocks, translations)):
            item = TranslationItem(
                bbox=block.get("bbox", [0, 0, 0, 0]),
                src=block["text"],
                tgt=translation,
                conf=block.get("conf", 1.0)
            )
            merged_items.append(item)
        
        processing_time = int((time.time() - start_time) * 1000)
        
        result = ProcessResult(
            image_id=image_id,
            line_count=len(merged_items), 
            items=merged_items,
            processing_time_ms=processing_time
        )
        
        logger.info(f"处理完成，耗时: {processing_time}ms")
        
        return result
        
    except httpx.RequestError as e:
        logger.error(f"网络请求错误: {e}")
        raise HTTPException(500, f"Service communication error: {e}")
    except Exception as e:
        logger.error(f"处理错误: {e}")
        raise HTTPException(500, f"Processing error: {e}")

@app.get("/v1/services/status")
async def service_status():
    """检查各服务状态"""
    status = {}
    
    # 检查OCR服务
    try:
        async with httpx.AsyncClient(timeout=10, proxies={}) as client:
            ocr_resp = await client.get(f"{OCR_URL.replace('/ocr', '/health')}")
            status["ocr"] = {
                "status": "ok" if ocr_resp.status_code == 200 else "error",
                "url": OCR_URL,
                "response_time_ms": int(ocr_resp.elapsed.total_seconds() * 1000)
            }
    except Exception as e:
        status["ocr"] = {"status": "error", "url": OCR_URL, "error": str(e)}
    
    # 检查翻译服务  
    try:
        async with httpx.AsyncClient(timeout=10, proxies={}) as client:
            nmt_resp = await client.get(f"{TRANSLATE_URL.replace('/translate', '/health')}")
            status["nmt"] = {
                "status": "ok" if nmt_resp.status_code == 200 else "error", 
                "url": TRANSLATE_URL,
                "response_time_ms": int(nmt_resp.elapsed.total_seconds() * 1000)
            }
    except Exception as e:
        status["nmt"] = {"status": "error", "url": TRANSLATE_URL, "error": str(e)}
    
    return status

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)