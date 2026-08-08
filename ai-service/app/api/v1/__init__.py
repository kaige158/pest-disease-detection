"""API v1 路由聚合"""
from fastapi import APIRouter

# 各模块路由（后续阶段逐个实现）
# from app.api.v1.recognition import router as recognition_router
# from app.api.v1.knowledge import router as knowledge_router
# from app.api.v1.assistant import router as assistant_router

router = APIRouter()

# router.include_router(recognition_router, prefix="/recognition", tags=["病虫害识别"])
# router.include_router(knowledge_router, prefix="/knowledge", tags=["知识库"])
# router.include_router(assistant_router, prefix="/assistant", tags=["AI助手"])

# 临时健康检查
@router.get("/health")
async def api_health():
    return {"status": "ok"}
