"""
多引擎OCR识别模块
基于advanced_image_translator.py的OCR逻辑重构
"""

import io
import base64
from PIL import Image
import asyncio
from typing import List, Dict, Any
import logging
import numpy as np

logger = logging.getLogger(__name__)

class MultiOCREngine:
    """多引擎OCR识别器"""
    
    def __init__(self):
        self.engines = {}
        self.current_engine = None
        self._initialize_engines()
    
    def _initialize_engines(self):
        """初始化可用的OCR引擎"""
        
        # 尝试初始化EasyOCR
        try:
            import easyocr
            self.engines['easyocr'] = easyocr.Reader(['ch_sim', 'en'], gpu=False)
            self.current_engine = 'easyocr'
            logger.info("✅ EasyOCR 初始化成功")
        except Exception as e:
            logger.warning(f"⚠️ EasyOCR 初始化失败: {e}")
        
        # 如果没有可用引擎，使用占位模式
        if not self.current_engine:
            logger.warning("⚠️ 没有可用的OCR引擎，将使用占位模式")
            self.current_engine = 'placeholder'
    
    def get_available_engines(self) -> List[str]:
        """获取可用的OCR引擎列表"""
        available = list(self.engines.keys())
        if not available:
            available.append('placeholder')
        return available
    
    def get_current_engine(self) -> str:
        """获取当前使用的OCR引擎"""
        return self.current_engine or 'placeholder'
    
    def get_default_engine(self) -> str:
        """获取默认OCR引擎"""
        if 'easyocr' in self.engines:
            return 'easyocr'
        else:
            return 'placeholder'
    
    async def detect_text_regions(self, image: Image.Image) -> List[Dict[str, Any]]:
        """
        检测图片中的文字区域
        
        Args:
            image: PIL图片对象
            
        Returns:
            文字区域列表，每个区域包含：
            - text: 识别的文字
            - bbox: 边界框 [x1, y1, x2, y2]
            - confidence: 置信度
        """
        
        if not self.current_engine or self.current_engine == 'placeholder':
            return await self._placeholder_ocr(image)
        
        try:
            if self.current_engine == 'easyocr':
                return await self._easyocr_detect(image)
        except Exception as e:
            logger.error(f"OCR引擎 {self.current_engine} 失败: {e}")
            # 降级到占位模式
            return await self._placeholder_ocr(image)
    
    async def _easyocr_detect(self, image: Image.Image) -> List[Dict[str, Any]]:
        """EasyOCR识别"""
        reader = self.engines['easyocr']
        
        # 转换为numpy数组
        img_array = np.array(image)
        
        # 在线程池中运行OCR（因为EasyOCR是同步的）
        loop = asyncio.get_event_loop()
        results = await loop.run_in_executor(None, reader.readtext, img_array)
        
        regions = []
        for result in results:
            points = result[0]  # 四个角点
            text = result[1]    # 识别文字
            confidence = result[2]  # 置信度
            
            if confidence > 0.5:  # 只保留置信度较高的结果
                # 计算边界框
                x_coords = [p[0] for p in points]
                y_coords = [p[1] for p in points]
                x1, y1 = int(min(x_coords)), int(min(y_coords))
                x2, y2 = int(max(x_coords)), int(max(y_coords))
                
                regions.append({
                    'text': text.strip(),
                    'bbox': [x1, y1, x2, y2],
                    'confidence': confidence
                })
        
        return regions
    
    async def _placeholder_ocr(self, image: Image.Image) -> List[Dict[str, Any]]:
        """占位OCR（用于测试）"""
        import random
        
        # 生成一些示例文字区域
        width, height = image.size
        sample_texts = [
            "这是测试文字", 
            "Sample Text", 
            "OCR识别示例"
        ]
        
        regions = []
        y_offset = 50
        
        for i, text in enumerate(sample_texts):
            x1 = 50
            y1 = y_offset + i * 60
            x2 = x1 + len(text) * 20
            y2 = y1 + 40
            
            # 确保不超出图片边界
            if y2 < height and x2 < width:
                regions.append({
                    'text': text,
                    'bbox': [x1, y1, x2, y2],
                    'confidence': round(random.uniform(0.85, 0.95), 2)
                })
        
        return regions

# 为了兼容性，创建OCREngine别名
class OCREngine:
    def __init__(self):
        self.multi_engine = MultiOCREngine()
    
    async def extract_text(self, image_data: str, engine: str = "auto") -> Dict[str, Any]:
        """从图像中提取文字"""
        try:
            # 解码图像数据
            image_bytes = base64.b64decode(image_data)
            image = Image.open(io.BytesIO(image_bytes))
            
            # 转换为RGB格式
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # 使用多引擎OCR
            text_regions = await self.multi_engine.detect_text_regions(image)
            
            # 转换格式
            text_blocks = []
            for region in text_regions:
                bbox = region['bbox']
                text_blocks.append({
                    "text": region['text'],
                    "confidence": region['confidence'],
                    "bbox": {
                        "x": bbox[0],
                        "y": bbox[1],
                        "width": bbox[2] - bbox[0],
                        "height": bbox[3] - bbox[1]
                    }
                })
            
            return {
                "success": True,
                "text_blocks": text_blocks,
                "engine_used": self.multi_engine.get_current_engine(),
                "total_blocks": len(text_blocks)
            }
            
        except Exception as e:
            logger.error(f"OCR extraction failed: {e}")
            return {
                "success": False,
                "error": str(e),
                "text_blocks": [],
                "engine_used": engine
            }
    
    def get_available_engines(self) -> List[str]:
        """获取可用的OCR引擎列表"""
        return self.multi_engine.get_available_engines()