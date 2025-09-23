"""
文件服务 - 处理文件上传、存储、下载
负责文档预处理、格式转换、临时文件管理
"""

from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uuid
import json
import asyncio
from pathlib import Path
from typing import Dict, List, Optional
import logging
from datetime import datetime, timedelta
import mimetypes
import shutil

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Document Translator - File Service",
    description="文件处理服务：上传、存储、预处理、格式转换",
    version="1.0.0"
)

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 配置
UPLOAD_DIR = Path(os.getenv("UPLOAD_DIR", "./temp/uploads"))
PROCESSED_DIR = Path(os.getenv("PROCESSED_DIR", "./temp/processed"))
MAX_FILE_SIZE = int(os.getenv("MAX_FILE_SIZE", "100")) * 1024 * 1024  # 100MB
ALLOWED_EXTENSIONS = {".pdf", ".docx", ".doc", ".txt", ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff"}

# 确保目录存在
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

# 文件存储
file_storage: Dict[str, Dict] = {}

class FileProcessor:
    """文件处理器"""
    
    def __init__(self):
        self.supported_formats = {
            'image': ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tiff'],
            'document': ['.pdf', '.docx', '.doc', '.txt'],
            'presentation': ['.pptx', '.ppt']
        }
    
    def get_file_type(self, filename: str) -> str:
        """获取文件类型"""
        ext = Path(filename).suffix.lower()
        for file_type, extensions in self.supported_formats.items():
            if ext in extensions:
                return file_type
        return 'unknown'
    
    async def preprocess_image(self, file_path: Path) -> Dict:
        """预处理图像文件"""
        try:
            from PIL import Image
            
            with Image.open(file_path) as img:
                # 基本信息
                info = {
                    'width': img.width,
                    'height': img.height,
                    'format': img.format,
                    'mode': img.mode,
                    'has_transparency': img.mode in ('RGBA', 'LA') or 'transparency' in img.info
                }
                
                # 如果图片太大，创建缩略图
                if img.width > 2048 or img.height > 2048:
                    thumbnail_path = file_path.parent / f"thumb_{file_path.name}"
                    img.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
                    img.save(thumbnail_path, format='JPEG', quality=85)
                    info['thumbnail'] = str(thumbnail_path)
                
                return info
                
        except Exception as e:
            logger.error(f"图像预处理失败: {e}")
            return {"error": str(e)}
    
    async def preprocess_document(self, file_path: Path) -> Dict:
        """预处理文档文件"""
        try:
            info = {'pages': 0, 'text_preview': ''}
            
            if file_path.suffix.lower() == '.pdf':
                # PDF处理
                try:
                    import PyPDF2
                    with open(file_path, 'rb') as file:
                        reader = PyPDF2.PdfReader(file)
                        info['pages'] = len(reader.pages)
                        
                        # 提取前几页文本作为预览
                        preview_text = ""
                        for i, page in enumerate(reader.pages[:3]):  # 只处理前3页
                            preview_text += page.extract_text() + "\n"
                        info['text_preview'] = preview_text[:500]  # 限制预览长度
                        
                except Exception as e:
                    logger.warning(f"PDF处理失败，尝试其他方法: {e}")
            
            elif file_path.suffix.lower() in ['.docx']:
                # Word文档处理
                try:
                    import python_docx
                    doc = python_docx.Document(file_path)
                    info['pages'] = len(doc.sections)
                    
                    # 提取文本预览
                    preview_text = ""
                    for para in doc.paragraphs[:10]:  # 前10段
                        preview_text += para.text + "\n"
                    info['text_preview'] = preview_text[:500]
                    
                except Exception as e:
                    logger.warning(f"Word文档处理失败: {e}")
            
            return info
            
        except Exception as e:
            logger.error(f"文档预处理失败: {e}")
            return {"error": str(e)}

file_processor = FileProcessor()

@app.get("/health")
async def health_check():
    """健康检查"""
    return {
        "status": "ok",
        "service": "file-service",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
        "storage": {
            "upload_dir": str(UPLOAD_DIR),
            "processed_dir": str(PROCESSED_DIR),
            "disk_usage": shutil.disk_usage(UPLOAD_DIR)._asdict()
        }
    }

@app.post("/upload")
async def upload_file(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    category: str = "general"
):
    """
    上传文件
    
    Args:
        file: 上传的文件
        category: 文件分类 (general, image, document, etc.)
    """
    try:
        # 验证文件
        if not file.filename:
            raise HTTPException(status_code=400, detail="未提供文件名")
        
        file_ext = Path(file.filename).suffix.lower()
        if file_ext not in ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=400, 
                detail=f"不支持的文件格式: {file_ext}"
            )
        
        # 检查文件大小
        content = await file.read()
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"文件过大，最大支持 {MAX_FILE_SIZE // 1024 // 1024}MB"
            )
        
        # 生成文件ID和路径
        file_id = str(uuid.uuid4())
        safe_filename = f"{file_id}_{file.filename}"
        file_path = UPLOAD_DIR / safe_filename
        
        # 保存文件
        with open(file_path, "wb") as f:
            f.write(content)
        
        # 获取文件信息
        file_type = file_processor.get_file_type(file.filename)
        file_info = {
            "file_id": file_id,
            "original_name": file.filename,
            "safe_filename": safe_filename,
            "file_path": str(file_path),
            "file_size": len(content),
            "file_type": file_type,
            "category": category,
            "mime_type": mimetypes.guess_type(file.filename)[0],
            "uploaded_at": datetime.now().isoformat(),
            "status": "uploaded"
        }
        
        # 存储文件信息
        file_storage[file_id] = file_info
        
        # 后台处理文件
        background_tasks.add_task(process_file_background, file_id, file_path, file_type)
        
        return {
            "success": True,
            "file_id": file_id,
            "filename": file.filename,
            "file_size": len(content),
            "file_type": file_type,
            "upload_time": file_info["uploaded_at"]
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"文件上传失败: {e}")
        raise HTTPException(status_code=500, detail=f"文件上传失败: {str(e)}")

async def process_file_background(file_id: str, file_path: Path, file_type: str):
    """后台处理文件"""
    try:
        logger.info(f"开始处理文件: {file_id}")
        
        # 更新状态
        if file_id in file_storage:
            file_storage[file_id]["status"] = "processing"
        
        # 根据文件类型进行预处理
        if file_type == "image":
            process_info = await file_processor.preprocess_image(file_path)
        elif file_type == "document":
            process_info = await file_processor.preprocess_document(file_path)
        else:
            process_info = {"message": "无需特殊处理"}
        
        # 更新文件信息
        if file_id in file_storage:
            file_storage[file_id]["process_info"] = process_info
            file_storage[file_id]["status"] = "ready"
            file_storage[file_id]["processed_at"] = datetime.now().isoformat()
        
        logger.info(f"文件处理完成: {file_id}")
        
    except Exception as e:
        logger.error(f"文件处理失败 {file_id}: {e}")
        if file_id in file_storage:
            file_storage[file_id]["status"] = "error"
            file_storage[file_id]["error"] = str(e)

@app.get("/file/{file_id}")
async def get_file_info(file_id: str):
    """获取文件信息"""
    if file_id not in file_storage:
        raise HTTPException(status_code=404, detail="文件不存在")
    
    return file_storage[file_id]

@app.get("/download/{file_id}")
async def download_file(file_id: str):
    """下载文件"""
    if file_id not in file_storage:
        raise HTTPException(status_code=404, detail="文件不存在")
    
    file_info = file_storage[file_id]
    file_path = file_info["file_path"]
    
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="文件已被删除")
    
    return FileResponse(
        file_path,
        filename=file_info["original_name"],
        media_type=file_info.get("mime_type", "application/octet-stream")
    )

@app.delete("/file/{file_id}")
async def delete_file(file_id: str):
    """删除文件"""
    if file_id not in file_storage:
        raise HTTPException(status_code=404, detail="文件不存在")
    
    file_info = file_storage[file_id]
    file_path = file_info["file_path"]
    
    # 删除物理文件
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
        
        # 删除缩略图
        if "process_info" in file_info and "thumbnail" in file_info["process_info"]:
            thumb_path = file_info["process_info"]["thumbnail"]
            if os.path.exists(thumb_path):
                os.remove(thumb_path)
    except Exception as e:
        logger.warning(f"删除文件失败: {e}")
    
    # 从存储中删除
    del file_storage[file_id]
    
    return {"success": True, "message": "文件已删除"}

@app.get("/files")
async def list_files(
    category: Optional[str] = None,
    file_type: Optional[str] = None,
    limit: int = 50
):
    """列出文件"""
    files = []
    
    for file_id, file_info in file_storage.items():
        # 过滤条件
        if category and file_info.get("category") != category:
            continue
        if file_type and file_info.get("file_type") != file_type:
            continue
        
        files.append({
            "file_id": file_id,
            "filename": file_info["original_name"],
            "file_size": file_info["file_size"],
            "file_type": file_info["file_type"],
            "status": file_info["status"],
            "uploaded_at": file_info["uploaded_at"]
        })
        
        if len(files) >= limit:
            break
    
    return {
        "files": files,
        "total": len(files)
    }

@app.post("/cleanup")
async def cleanup_old_files(older_than_hours: int = 24):
    """清理旧文件"""
    deleted_count = 0
    cutoff_time = datetime.now() - timedelta(hours=older_than_hours)
    
    to_delete = []
    for file_id, file_info in file_storage.items():
        uploaded_time = datetime.fromisoformat(file_info["uploaded_at"])
        if uploaded_time < cutoff_time:
            to_delete.append(file_id)
    
    for file_id in to_delete:
        try:
            # 删除物理文件
            file_info = file_storage[file_id]
            file_path = file_info["file_path"]
            if os.path.exists(file_path):
                os.remove(file_path)
            
            # 从存储中删除
            del file_storage[file_id]
            deleted_count += 1
            
        except Exception as e:
            logger.warning(f"清理文件失败 {file_id}: {e}")
    
    return {
        "success": True,
        "deleted_count": deleted_count,
        "message": f"清理了 {deleted_count} 个超过 {older_than_hours} 小时的文件"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8010)