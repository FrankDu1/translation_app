from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image
import io
import logging
from typing import List, Dict, Any
from pydantic import BaseModel
import os

# 导入OCR引擎
from ocr_engine import MultiOCREngine

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="OCR Service", 
    version="1.0.0",
    description="多引擎OCR文字识别服务"
)

# 初始化OCR引擎
ocr_engine = MultiOCREngine()

class OCRBlock(BaseModel):
    """OCR识别的文字块"""
    text: str           # 识别的文字
    bbox: List[int]     # 边界框 [x1, y1, x2, y2]  
    conf: float         # 置信度

class OCRResult(BaseModel):
    """OCR识别结果"""
    blocks: List[OCRBlock]
    engine: str         # 使用的OCR引擎
    processing_time_ms: int

@app.get("/health")
async def health():
    """健康检查"""
    available_engines = ocr_engine.get_available_engines()
    return {
        "status": "ok",
        "service": "ocr",
        "version": "1.0.0",
        "available_engines": available_engines,
        "default_engine": ocr_engine.get_default_engine()
    }

@app.post("/ocr", response_model=OCRResult)
async def ocr_recognize(file: UploadFile = File(...)):
    """
    OCR文字识别
    
    输入：图片文件
    输出：识别的文字块列表，包含文字、位置、置信度
    """
    import time
    start_time = time.time()
    
    try:
        # 读取图片
        img_bytes = await file.read()
        image = Image.open(io.BytesIO(img_bytes))
        
        # 确保是RGB格式
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        logger.info(f"开始OCR识别，图片大小: {image.size}")
        
        # 调用OCR引擎识别
        detected_regions = ocr_engine.detect_text_regions(image)
        
        # 转换为标准格式
        blocks = []
        for region in detected_regions:
            block = OCRBlock(
                text=region.get('text', ''),
                bbox=region.get('bbox', [0, 0, 0, 0]),
                conf=region.get('confidence', 0.0)
            )
            blocks.append(block)
        
        processing_time = int((time.time() - start_time) * 1000)
        
        result = OCRResult(
            blocks=blocks,
            engine=ocr_engine.get_current_engine(),
            processing_time_ms=processing_time
        )
        
        logger.info(f"OCR识别完成，检测到 {len(blocks)} 个文字块，耗时: {processing_time}ms")
        
        return result
        
    except Exception as e:
        logger.error(f"OCR识别错误: {e}")
        raise HTTPException(500, f"OCR recognition error: {e}")

@app.get("/engines")
async def list_engines():
    """列出可用的OCR引擎"""
    return {
        "available": ocr_engine.get_available_engines(),
        "current": ocr_engine.get_current_engine(),
        "default": ocr_engine.get_default_engine()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7010)