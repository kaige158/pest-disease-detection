"""AI 通道配置自检 API

用途：管理后台「AI 配置中心」的「测试连接」按钮。
由业务后端把待测配置传进来，AI 服务在其所属网络环境里发起一次
**最小真实调用**（不是只探测端口），因此能真正验证：
    Key 是否有效 / 模型名是否正确 / 网络是否可达 / 是否被限流
"""
import time

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.ai_providers.base import ProviderConfig
from app.services.ai_providers.factory import build_provider, SUPPORTED_PROVIDERS

router = APIRouter()


class ProviderTestRequest(BaseModel):
    provider: str = ""
    api_key: str = ""
    model: str = ""
    base_url: str = ""


@router.get("/providers")
async def list_providers():
    """可用通道类型 + 厂商预设 —— 供后台下拉框动态渲染

    `preset` 里给出该厂商的官方请求地址与推荐模型名，
    后台选中后自动预填，运维不必去翻文档拼路径。
    """
    from app.services.ai_providers.compatible_provider import PROVIDER_PRESETS

    def preset_of(key: str) -> dict:
        p = PROVIDER_PRESETS.get(key)
        return dict(p) if p else {}

    return {
        "providers": [
            {"value": "gemini", "label": "Google Gemini", "need_key": True,
             "note": "有免费额度，https://aistudio.google.com/apikey", "preset": {}},
            {"value": "deepseek", "label": "DeepSeek（深度求索）", "need_key": True,
             "note": "国内直连；视觉能力需用 vision 系列模型",
             "preset": preset_of("deepseek")},
            {"value": "kimi", "label": "月之暗面 Kimi", "need_key": True,
             "note": "国内可直连，https://platform.moonshot.cn", "preset": {}},
            {"value": "openai", "label": "OpenAI GPT-4o", "need_key": True,
             "note": "需要海外网络环境", "preset": {}},
            {"value": "claude", "label": "Anthropic Claude", "need_key": True,
             "note": "需要海外网络环境", "preset": {}},
            {"value": "custom", "label": "自定义 / 代理（兼容 OpenAI 协议）", "need_key": True,
             "note": "填 base_url 指向自建或代理服务；通义千问、智谱等也可用此项",
             "preset": {}},
            {"value": "mock", "label": "Mock（离线演示，不调外部API）", "need_key": False,
             "note": "无需密钥，用于演示与联调", "preset": {}},
        ],
        "compatible_presets": PROVIDER_PRESETS,
        "supported": list(SUPPORTED_PROVIDERS),
    }


@router.post("/test")
async def test_provider(request: ProviderTestRequest):
    """测试指定配置是否可用

    返回结构：
        {ok, message, elapsed_ms, provider, model}
    注意：mock 通道永远返回 ok=true（它就是离线桩）。
    """
    start = time.time()
    cfg = ProviderConfig(
        provider=request.provider,
        api_key=request.api_key,
        model=request.model,
        base_url=request.base_url,
    )

    if not cfg.provider:
        return {"ok": False, "message": "未指定通道类型", "elapsed_ms": 0}

    if cfg.provider not in SUPPORTED_PROVIDERS:
        return {
            "ok": False,
            "message": f"不支持的通道类型: {cfg.provider}",
            "elapsed_ms": 0,
        }

    if cfg.provider != "mock" and not cfg.api_key:
        return {"ok": False, "message": "未提供 API Key", "elapsed_ms": 0}

    try:
        provider = build_provider(cfg)

        if cfg.provider == "mock":
            return {
                "ok": True,
                "message": "Mock 通道可用（离线桩，不调用外部 API）",
                "elapsed_ms": int((time.time() - start) * 1000),
                "provider": provider.provider_name,
                "model": provider.model,
            }

        # 最小真实调用：一句极短的文本对话，成本可忽略
        reply = await provider.chat(
            message="回复两个字：可用",
            history=[],
            language="zh",
            version="vegetable",
        )
        elapsed = int((time.time() - start) * 1000)
        snippet = (reply or "").strip().replace("\n", " ")[:100]
        return {
            "ok": True,
            "message": f"连接成功，模型回复：{snippet}" if snippet else "连接成功",
            "elapsed_ms": elapsed,
            "provider": provider.provider_name,
            "model": provider.model,
        }
    except Exception as e:
        elapsed = int((time.time() - start) * 1000)
        return {
            "ok": False,
            "message": f"连接失败：{type(e).__name__}: {str(e)[:300]}",
            "elapsed_ms": elapsed,
            "provider": cfg.provider,
            "model": cfg.model,
        }
