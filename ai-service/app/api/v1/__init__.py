"""API v1 路由聚合

路径约定（重要）：
    业务后端 AiServiceClient 调用的是**顶层**路径：
        POST /api/v1/identify
        POST /api/v1/chat
        POST /api/v1/config/test
    因此这里除了带模块前缀的规范路径外，额外挂载了顶层别名，
    两个路径指向同一处理函数，避免客户端/服务端路径不一致导致 404。
"""
from fastapi import APIRouter

from app.api.v1.recognition import (
    router as recognition_router,
    identify_disease,
    chat,
    IdentifyRequest,
    ChatRequest,
)
from app.api.v1.diagnosis import router as diagnosis_router
from app.api.v1.config import router as config_router

router = APIRouter()

# 规范路径（带模块前缀）
router.include_router(recognition_router, prefix="/recognition", tags=["病虫害识别"])
router.include_router(diagnosis_router, prefix="/diagnosis", tags=["诊断Agent"])
router.include_router(config_router, prefix="/config", tags=["AI通道配置"])


# ===== 顶层别名（业务后端实际调用路径）=====
@router.post("/identify", tags=["病虫害识别"], summary="识别病虫害（顶层别名）")
async def identify_alias(request: IdentifyRequest):
    return await identify_disease(request)


@router.post("/chat", tags=["AI助手"], summary="农业对话（顶层别名）")
async def chat_alias(request: ChatRequest):
    return await chat(request)


@router.get("/health")
async def api_health():
    return {"status": "ok"}
