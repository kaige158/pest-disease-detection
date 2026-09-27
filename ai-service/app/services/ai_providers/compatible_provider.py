"""OpenAI 兼容 Provider —— 覆盖 DeepSeek / 通义千问 / 智谱 / 自建代理等

为什么单独抽一层：
    DeepSeek、通义千问、智谱、以及各家的自建代理，都兼容 OpenAI 的
    `/v1/chat/completions` 协议（含 `image_url` 传图）。如果每接一家就抄一份代码，
    后面维护会失控。这里把"协议"与"厂商"分开：
        · 协议实现只有这一份
        · 厂商差异（地址、默认模型）由后台「AI 配置中心」的预设提供

安全约定：
    api_key / base_url / model 全部来自后台配置（`ProviderConfig`），
    代码里只保留公开的官方地址与默认模型名，不含任何密钥。
"""
import base64
from typing import List, Optional

import httpx

from app.services.ai_providers.base import AIProvider, ChatMessage
from app.services.ai_providers.openai_provider import OpenAIProvider
from app.services.ai_providers.parser import AIResponseParser

#: 厂商预设 —— 后台「AI 配置中心」选完通道类型后自动预填这些默认值
#: 需要新增厂商时只改这里（或在后台直接手填地址与模型名）
PROVIDER_PRESETS = {
    "deepseek": {
        "label": "DeepSeek（深度求索）",
        "base_url": "https://api.deepseek.com/v1/chat/completions",
        "model": "deepseek-chat",
        "note": "官方 API 目前只有文本模型（deepseek-chat / deepseek-reasoner），"
                "可以做 AI 助手，**不能做拍照识别**；识别请用 Gemini / 通义千问 / 智谱",
        "supports_vision": False,
    },
    "qwen": {
        "label": "通义千问（阿里云百炼）",
        "base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
        "model": "qwen-vl-max",
        "note": "国内直连，支持视觉；模型名以阿里云百炼控制台为准",
        "supports_vision": True,
    },
    "zhipu": {
        "label": "智谱 GLM",
        "base_url": "https://open.bigmodel.cn/api/paas/v4/chat/completions",
        "model": "glm-4v",
        "note": "国内直连，支持视觉",
        "supports_vision": True,
    },
}


class OpenAICompatibleProvider(OpenAIProvider):
    """兼容 OpenAI 协议的第三方厂商

    继承 {@link OpenAIProvider} 复用请求体构造与解析逻辑，
    只覆盖「默认地址 / 默认模型 / 名称」，避免协议实现被复制多份。

    注意构造顺序：父类 `__init__` 会用 `self.DEFAULT_MODEL` 兜底，
    所以子类必须在 `super().__init__()` **之前**先改好 `DEFAULT_MODEL`，
    否则会拿到 OpenAI 的默认模型（这个坑已被单元测试覆盖）。
    """

    #: 厂商预设键；子类覆盖
    PRESET_KEY = ""

    def __init__(self, config=None):
        preset = PROVIDER_PRESETS.get(self.PRESET_KEY, {})
        # 必须在 super().__init__ 之前赋值：父类构造时就会读取这两个属性
        if preset.get("base_url"):
            self.DEFAULT_URL = preset["base_url"]
        if preset.get("model"):
            self.DEFAULT_MODEL = preset["model"]

        super().__init__(config)

    def _endpoint(self, default_url: str, path: str) -> str:
        """兼容厂商的地址解析

        不同厂商的路径前缀不一致（DeepSeek 是 `/v1`，智谱是 `/api/paas/v4`），
        所以约定：**后台填的地址就是请求地址**，支持三种写法：
            · 完整地址（含 /chat/completions）→ 原样使用
            · 填到 /v1                        → 补 /chat/completions
            · 只填主机                        → 补 /v1/chat/completions
            · 什么都没填                      → 用预设里的官方地址
        运维只要从厂商文档复制"请求地址"粘进来即可，无需理解拼接规则。
        """
        url = (self.base_url or default_url or "").rstrip("/")
        if not url:
            return ""

        # 注意 rsplit("/", 1) 只切一次，得到 ['/v1/chat', 'completions']，
        # 取 [-1] 会丢掉 "chat/"；这里要的是最后两段 chat/completions
        tail = "/".join(path.rsplit("/", 2)[-2:])   # chat/completions

        if url.endswith(tail):
            return url                              # 已含完整路径
        if url.endswith("/v1"):
            return f"{url}/{tail}"                  # 只缺末段
        return f"{url}{path}"                       # 只填了主机

    @property
    def provider_name(self) -> str:
        # 保留真实厂商名，便于入库统计与排障（如 provider_used=deepseek）
        return self.PRESET_KEY or "custom"


class DeepSeekProvider(OpenAICompatibleProvider):
    """DeepSeek —— OpenAI 兼容协议，国内直连"""

    PRESET_KEY = "deepseek"


class CustomProvider(OpenAICompatibleProvider):
    """自定义 / 代理 —— 由后台填写 base_url 与 model

    早期实现是抛 NotImplementedError 的空壳，导致后台选了「Custom / Proxy」
    也完全不可用；现在走 OpenAI 兼容协议真实可用，
    因此通义千问、智谱、自建代理都能直接接入，无需改代码。
    """

    PRESET_KEY = "custom"

    async def identify_disease(
        self, image_bytes: bytes, crop_info: Optional[dict] = None,
        language: str = "zh", version: str = "vegetable",
    ) -> List:
        # 自定义通道必须有明确的地址，否则无法知道往哪发
        if not self.base_url:
            raise RuntimeError(
                "自定义通道需要在「AI 配置中心」填写接口地址（base_url）"
            )
        return await super().identify_disease(image_bytes, crop_info, language, version)
