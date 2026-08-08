"""API v1 路由聚合"""
from fastapi import APIRouter

from app.api.v1.recognition import router as recognition_router

router = APIRouter()

router.include_router(recognition_router, prefix="/recognition", tags=["病虫害识别"])

@router.get("/health")
async def api_health():
    return {"status": "ok"}
