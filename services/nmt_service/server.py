from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import List, Dict, Any
import logging
import os

# 导入翻译器
from translator import MultiTranslator

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Translation Service",
    version="1.0.0", 
    description="多引擎翻译服务"
)

# 初始化翻译器
translator = MultiTranslator()

class TranslateRequest(BaseModel):
    """翻译请求"""
    lines: List[str]
    target_lang: str = "zh"
    source_lang: str = "auto"  # 自动检测

class TranslateResponse(BaseModel):
    """翻译响应"""
    translations: List[str]
    engine: str
    processing_time_ms: int

@app.get("/health")
async def health():
    """健康检查"""
    available_engines = translator.get_available_engines()
    return {
        "status": "ok", 
        "service": "translation",
        "version": "1.0.0",
        "available_engines": available_engines,
        "current_engine": translator.get_current_engine()
    }

@app.post("/translate", response_model=TranslateResponse)
async def translate(request: TranslateRequest):
    """
    批量翻译文本
    
    Args:
        request: 翻译请求，包含文本列表和目标语言
        
    Returns:
        翻译结果列表
    """
    import time
    start_time = time.time()
    
    try:
        logger.info(f"开始翻译 {len(request.lines)} 行文本，目标语言: {request.target_lang}")
        
        # 执行翻译
        translations = await translator.translate_batch(
            texts=request.lines,
            target_lang=request.target_lang,
            source_lang=request.source_lang
        )
        
        processing_time = int((time.time() - start_time) * 1000)
        
        response = TranslateResponse(
            translations=translations,
            engine=translator.get_current_engine(),
            processing_time_ms=processing_time
        )
        
        logger.info(f"翻译完成，耗时: {processing_time}ms")
        
        return response
        
    except Exception as e:
        logger.error(f"翻译错误: {e}")
        raise HTTPException(500, f"Translation error: {e}")

@app.get("/engines")
async def list_engines():
    """列出可用的翻译引擎"""
    return {
        "available": translator.get_available_engines(),
        "current": translator.get_current_engine(),
        "default": translator.get_default_engine()
    }

@app.get("/languages")
async def supported_languages():
    """获取支持的语言列表"""
    return {
        "supported": translator.get_supported_languages(),
        "auto_detect": True
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7020)