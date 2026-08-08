"""Kimi Vision Provider — 月之暗面 Moonshot AI"""
import base64
import httpx
from typing import List, Optional
from app.core.config import settings
from app.services.ai_providers.base import AIProvider, ChatMessage
from app.services.ai_providers.parser import AIResponseParser


class KimiProvider(AIProvider):
    """Kimi Vision Provider (Moonshot-v1-vision)"""

    @property
    def provider_name(self) -> str:
        return "kimi"

    async def identify_disease(
        self, image_bytes: bytes, crop_info: Optional[dict] = None,
        language: str = "zh", version: str = "vegetable",
    ) -> List:
        base64_image = base64.b64encode(image_bytes).decode()
        crop_hint = f"作物类型可能是: {crop_info['crop_name']}" if crop_info else ""

        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                "https://api.moonshot.cn/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.ai_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "moonshot-v1-8k-vision-preview",
                    "messages": [
                        {"role": "system", "content": self._system_prompt(version, language)},
                        {"role": "user", "content": [
                            {"type": "image_url", "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }},
                            {"type": "text", "text": f"请识别这张图片中的植物病虫害。{crop_hint}"},
                        ]},
                    ],
                    "temperature": settings.ai_temperature,
                },
            )
            response.raise_for_status()
            data = response.json()
            raw_text = data["choices"][0]["message"]["content"]

        return AIResponseParser.parse(raw_text, self.provider_name, language)

    async def chat(self, message: str, history: List[ChatMessage],
                   language: str = "zh", version: str = "vegetable") -> str:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                "https://api.moonshot.cn/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.ai_api_key}"},
                json={
                    "model": "moonshot-v1-8k",
                    "messages": [{"role": "user", "content": message}],
                    "temperature": 0.3,
                },
            )
            data = response.json()
            return data["choices"][0]["message"]["content"]

    async def generate_prevention_plan(self, disease_info: dict, language: str = "zh") -> dict:
        return {}

    def _system_prompt(self, version: str, language: str) -> str:
        crop_type = "蔬菜" if version == "vegetable" else "果树"
        lang_instr = "用中文回复" if language == "zh" else "用老挝语回复"
        return f"""你是{crop_type}病虫害诊断专家。{lang_instr}。

请严格按以下JSON格式输出（不要其他文字）：
{{"results":[{{"disease_name_zh":"病虫害名","disease_name_lo":"老挝语名","confidence":0.92,"type":"disease或pest","symptoms_zh":"症状描述","conditions_zh":"发病条件","severity":"mild/moderate/severe","prevention_plan":{{"chemical":[{{"name":"农药名","usage":"用法"}}],"biological":[{{"method":"方法","detail":"说明"}}],"cultivation":["建议"]}}}}]}}

如果图片不清晰或无法识别，confidence设为<0.5并说明原因。"""
