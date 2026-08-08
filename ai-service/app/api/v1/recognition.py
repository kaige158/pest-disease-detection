"""AI服务识别API — 接收图片，调用Provider，返回标准化结果"""
import base64
import io
import time

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.ai_providers.factory import get_ai_provider
from app.services.ai_providers.parser import AIResponseParser

router = APIRouter()


class IdentifyRequest(BaseModel):
    image: str             # Base64编码的图片
    crop_name: str = ""     # 作物名(可选)
    language: str = "zh"    # zh/lo
    version: str = "vegetable"  # vegetable/fruit


class ChatRequest(BaseModel):
    message: str
    language: str = "zh"
    version: str = "vegetable"
    session_id: str = ""
    history: list = []


@router.post("/identify")
async def identify_disease(request: IdentifyRequest):
    """
    病虫害图片识别接口

    流程: 解码图片 → 调用AI Provider → 解析标准化 → 返回DiagnosisResult
    """
    start_time = time.time()

    try:
        # 1. 解码Base64图片
        image_bytes = base64.b64decode(request.image)
    except Exception:
        raise HTTPException(status_code=400, detail="图片Base64编码无效")

    # 2. 构建作物信息
    crop_info = None
    if request.crop_name:
        crop_info = {"crop_name": request.crop_name}

    # 3. 调用AI Provider
    try:
        provider = get_ai_provider()
        results = await provider.identify_disease(
            image_bytes=image_bytes,
            crop_info=crop_info,
            language=request.language,
            version=request.version,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI识别服务异常: {str(e)}")

    # 4. 如果Provider返回的是原始文本(str), 用Parser解析
    #    MockProvider直接返回DiagnosisResult列表, 其他Provider可能返回str
    if results and isinstance(results[0], str):
        raw_text = "\n".join(results)
        results = AIResponseParser.parse(raw_text, provider.provider_name, request.language)

    # 5. 转换为API响应格式
    elapsed_ms = int((time.time() - start_time) * 1000)

    if not results:
        raise HTTPException(status_code=500, detail="AI未能识别出病虫害，请重新拍摄")

    top_result = results[0]
    response_data = top_result.to_dict()
    response_data["task_id"] = f"rec_{int(time.time())}_{hash(request.image) % 10000:04d}"
    response_data["total_time_ms"] = elapsed_ms

    return response_data


@router.post("/chat")
async def chat(request: ChatRequest):
    """AI农业诊断Agent对话"""
    try:
        provider = get_ai_provider()
        reply = await provider.chat(
            message=request.message,
            history=request.history,
            language=request.language,
            version=request.version,
        )
        return {"reply": reply, "session_id": request.session_id or f"sess_{int(time.time())}"}
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"AI对话服务异常: {str(e)}")


@router.get("/health")
async def health():
    provider = get_ai_provider()
    return {"status": "ok", "provider": provider.provider_name}
