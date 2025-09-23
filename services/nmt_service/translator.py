"""
多引擎翻译模块
支持Ollama和未来的CTranslate2等翻译引擎
"""

import httpx
import asyncio
import os
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

class MultiTranslator:
    """多引擎翻译器"""
    
    def __init__(self):
        self.engines = {}
        self.current_engine = None
        self._initialize_engines()
    
    def _initialize_engines(self):
        """初始化可用的翻译引擎"""
        
        # Ollama翻译引擎
        use_ollama = os.getenv("USE_OLLAMA", "true").lower() == "true"
        ollama_host = os.getenv("OLLAMA_HOST", "http://host.docker.internal:11434")
        ollama_model = os.getenv("OLLAMA_MODEL", "llama3.2:latest")
        
        if use_ollama:
            try:
                self.engines['ollama'] = {
                    'host': ollama_host,
                    'model': ollama_model,
                    'type': 'ollama'
                }
                self.current_engine = 'ollama'
                logger.info(f"✅ Ollama翻译引擎初始化成功: {ollama_host}, 模型: {ollama_model}")
            except Exception as e:
                logger.warning(f"⚠️ Ollama翻译引擎初始化失败: {e}")
        
        # 占位翻译引擎（测试用）
        self.engines['placeholder'] = {
            'type': 'placeholder'
        }
        
        # 如果没有其他引擎，使用占位引擎
        if not self.current_engine:
            self.current_engine = 'placeholder'
            logger.warning("⚠️ 使用占位翻译引擎")
    
    def get_available_engines(self) -> List[str]:
        """获取可用的翻译引擎列表"""
        return list(self.engines.keys())
    
    def get_current_engine(self) -> str:
        """获取当前使用的翻译引擎"""
        return self.current_engine or 'placeholder'
    
    def get_default_engine(self) -> str:
        """获取默认翻译引擎"""
        if 'ollama' in self.engines:
            return 'ollama'
        else:
            return 'placeholder'
    
    def get_supported_languages(self) -> Dict[str, str]:
        """获取支持的语言列表"""
        return {
            "zh": "中文",
            "en": "English", 
            "ja": "日本語",
            "ko": "한국어",
            "fr": "Français",
            "de": "Deutsch",
            "es": "Español",
            "auto": "自动检测"
        }
    
    async def translate_batch(self, texts: List[str], target_lang: str, source_lang: str = "auto") -> List[str]:
        """
        批量翻译文本
        
        Args:
            texts: 要翻译的文本列表
            target_lang: 目标语言
            source_lang: 源语言（auto为自动检测）
            
        Returns:
            翻译结果列表
        """
        
        if not texts:
            return []
        
        if self.current_engine == 'ollama':
            return await self._ollama_translate_batch(texts, target_lang, source_lang)
        elif self.current_engine == 'placeholder':
            return self._placeholder_translate_batch(texts, target_lang, source_lang)
        else:
            raise ValueError(f"Unknown engine: {self.current_engine}")
    
    async def _ollama_translate_batch(self, texts: List[str], target_lang: str, source_lang: str) -> List[str]:
        """使用Ollama进行批量翻译"""
        
        engine_config = self.engines['ollama']
        host = engine_config['host']
        model = engine_config['model']
        
        # 语言映射
        lang_map = {
            'zh': '中文',
            'en': 'English',
            'ja': '日本語', 
            'ko': '한국어',
            'fr': 'Français',
            'de': 'Deutsch',
            'es': 'Español'
        }
        
        target_lang_name = lang_map.get(target_lang, target_lang)
        
        translations = []
        
        async with httpx.AsyncClient(timeout=120) as client:
            # 设置环境变量来绕过代理
            import os
            os.environ['NO_PROXY'] = 'localhost,127.0.0.1'
            
            for text in texts:
                try:
                    # 构建翻译提示
                    if source_lang == "auto":
                        prompt = f"Please translate the following text into {target_lang_name}. Only return the translation result, no explanation:\n\n{text}"
                    else:
                        source_lang_name = lang_map.get(source_lang, source_lang)
                        prompt = f"Please translate the following {source_lang_name} text into {target_lang_name}. Only return the translation result, no explanation:\n\n{text}"
                    
                    # 调用Ollama API
                    response = await client.post(
                        f"{host}/api/generate",
                        json={
                            "model": model,
                            "prompt": prompt,
                            "stream": False,
                            "options": {
                                "temperature": 0.3,
                                "top_p": 0.9,
                                "max_tokens": 1000
                            }
                        }
                    )
                    
                    if response.status_code == 200:
                        result = response.json()
                        translation = result.get("response", "").strip()
                        
                        # 简单的后处理，移除可能的解释文本
                        if translation.startswith("Translation:") or translation.startswith("翻译:"):
                            translation = translation.split(":", 1)[-1].strip()
                        
                        translations.append(translation if translation else text)
                    else:
                        logger.warning(f"Ollama翻译失败: {response.status_code} - {response.text}")
                        translations.append(f"[ERR] {text}")
                        
                except Exception as e:
                    logger.error(f"翻译单条文本时出错: {e}")
                    translations.append(f"[ERR] {text}")
        
        return translations
    
    def _placeholder_translate_batch(self, texts: List[str], target_lang: str, source_lang: str) -> List[str]:
        """占位翻译（用于测试）"""
        
        # 简单的占位逻辑
        translations = []
        for text in texts:
            if target_lang == 'zh':
                translation = f"[中文翻译] {text}"
            elif target_lang == 'en':
                translation = f"[English Translation] {text}"
            else:
                translation = f"[{target_lang}] {text}"
            
            translations.append(translation)
        
        return translations