"""AI服务识别API — 接收图片，调用Provider，返回标准化结果

Sprint 10.3 升级: 图片质量前置检测 + 置信度策略管理
"""
import base64
import io
import logging
import time

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.ai_providers.factory import build_provider
from app.services.ai_providers.base import ProviderConfig
from app.services.ai_providers.parser import AIResponseParser
from app.services.quality.image_quality_checker import image_quality_checker, QualityGrade
from app.services.quality.confidence_manager import confidence_manager

logger = logging.getLogger(__name__)

router = APIRouter()


class IdentifyRequest(BaseModel):
    image: str             # Base64编码的图片
    crop_name: str = ""     # 作物名(可选)
    language: str = "zh"    # zh/lo
    version: str = "vegetable"  # vegetable/fruit
    # 运行时 AI 通道配置 —— 业务后端从数据库读取当前生效通道后下发，
    # 这样后台改配置立即生效，AI 服务无需重启、也无需直连数据库
    provider_config: dict = {}


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

    # 1.5 图片质量检测 (Sprint 10.3)
    quality = image_quality_checker.check(image_bytes)
    if not quality.is_acceptable:
        raise HTTPException(
            status_code=422,
            detail={
                "error": "图片质量不合格",
                "issues": quality.issues,
                "suggestions_zh": quality.suggestions_zh,
                "suggestions_lo": quality.suggestions_lo,
                "score": quality.score,
                "grade": quality.grade.value,
            }
        )

    # 2. 构建作物信息
    crop_info = None
    if request.crop_name:
        crop_info = {"crop_name": request.crop_name}

    # 3. 调用AI Provider（使用后台配置的当前生效通道）
    provider = None
    try:
        provider = build_provider(ProviderConfig.from_dict(request.provider_config))
        logger.info(
            "识别请求: provider=%s model=%s 图片=%d字节 language=%s crop=%s",
            provider.provider_name, getattr(provider, "model", "?"),
            len(image_bytes), request.language, request.crop_name or "-",
        )
        results = await provider.identify_disease(
            image_bytes=image_bytes,
            crop_info=crop_info,
            language=request.language,
            version=request.version,
        )
    except Exception as e:
        # ⚠️ 必须打日志：以前这里只抛 502、不打日志，
        #    结果"识别不可用"排查时完全看不到真实原因（用户实际踩过）。
        #    常见原因：模型不支持图片输入、模型名写错、Key 无权限、图片过大。
        logger.exception(
            "识别失败: provider=%s model=%s 图片=%d字节 错误=%s",
            getattr(provider, "provider_name", "?"),
            getattr(provider, "model", "?"),
            len(image_bytes), e,
        )
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

    # 5.5 置信度策略管理 (Sprint 10.3)
    decision = confidence_manager.decide(
        confidence=top_result.confidence,
        top_result_name=top_result.disease_name_zh,
        alternatives=[r.disease_name_zh for r in results[1:4]] if len(results) > 1 else [],
        language=request.language,
    )
    response_data = confidence_manager.enrich_api_response(response_data, decision)

    # 质量报告（用于调试和数据积累）
    response_data["image_quality"] = {
        "score": quality.score,
        "grade": quality.grade.value,
        "sharpness": quality.sharpness_score,
        "brightness": quality.brightness_score,
        "green_ratio": quality.green_ratio,
        "width": quality.width,
        "height": quality.height,
    }

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
