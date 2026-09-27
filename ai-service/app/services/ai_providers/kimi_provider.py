"""Kimi Vision Provider — 月之暗面 Moonshot AI (Kimi K2.6)"""
import base64
import io
import httpx
from typing import List, Optional
from app.core.config import settings
from app.services.ai_providers.base import AIProvider, ChatMessage
from app.services.ai_providers.parser import AIResponseParser


class KimiProvider(AIProvider):
    """Kimi K2.6 Vision Provider — 原生多模态推理模型"""

    DEFAULT_URL = "https://api.moonshot.cn/v1/chat/completions"
    DEFAULT_MODEL = "kimi-k2.6"

    @property
    def provider_name(self) -> str:
        return "kimi"

    async def identify_disease(
        self, image_bytes: bytes, crop_info: Optional[dict] = None,
        language: str = "zh", version: str = "vegetable",
    ) -> List:
        # 图片压缩（Kimi API对大图可能400）—— 统一走基类实现，避免各 Provider 各写一份
        compressed, mime_type = self._compress_image(image_bytes, max_size_kb=500)
        base64_image = base64.b64encode(compressed).decode()
        crop_hint = f"作物类型可能是: {crop_info['crop_name']}" if crop_info else ""

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(
                self._endpoint(self.DEFAULT_URL, "/v1/chat/completions"),
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model or self.DEFAULT_MODEL,
                    "messages": [
                        {"role": "system", "content": self._system_prompt(version, language)},
                        {"role": "user", "content": [
                            {"type": "image_url", "image_url": {
                                "url": f"data:{mime_type};base64,{base64_image}"
                            }},
                            {"type": "text", "text": f"请识别这张图片中的植物病虫害。{crop_hint}"},
                        ]},
                    ],
                    "max_tokens": self.max_tokens,
                    "temperature": self.temperature,
                },
            )
            response.raise_for_status()
            data = response.json()
            msg = data["choices"][0]["message"]

            # K2.6是推理模型: content可能为空，此时用reasoning_content
            raw_text = (msg.get("content") or "").strip()
            if not raw_text:
                raw_text = (msg.get("reasoning_content") or "").strip()

        return AIResponseParser.parse(raw_text, self.provider_name, language)

    async def chat(self, message: str, history: List[ChatMessage],
                   language: str = "zh", version: str = "vegetable") -> str:
        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(
                self._endpoint(self.DEFAULT_URL, "/v1/chat/completions"),
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": self.model or self.DEFAULT_MODEL,
                    "messages": [{"role": "user", "content": message}],
                    "max_tokens": 500,
                    "temperature": self.temperature,
                },
            )
            response.raise_for_status()
            data = response.json()
            msg = data["choices"][0]["message"]
            return (msg.get("content") or msg.get("reasoning_content") or "").strip()

    async def generate_prevention_plan(self, disease_info: dict, language: str = "zh") -> dict:
        return {}

    def _system_prompt(self, version: str, language: str) -> str:
        crop_type = "蔬菜" if version == "vegetable" else "果树"
        lang_instr = "用中文回复" if language == "zh" else "用老挝语回复(ຕອບເປັນພາສາລາວ)"
        return f"""你是{crop_type}病虫害诊断专家。{lang_instr}。

请严格按以下JSON格式输出（不要任何附加文字）：
{{"results":[{{"disease_name_zh":"病虫害中文名","disease_name_lo":"老挝语名","confidence":0.92,"type":"disease或pest","symptoms_zh":"症状描述","conditions_zh":"发病条件","severity":"mild/moderate/severe","prevention_plan":{{"chemical":[{{"name":"农药名","usage":"用法"}}],"biological":[{{"method":"方法","detail":"说明"}}],"cultivation":["建议"]}}}}]}}

如无法识别，confidence设为<0.5并说明原因。"""

