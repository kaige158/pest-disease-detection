"""OpenAI Vision Provider — 对接GPT-4o Vision API"""
import base64
import httpx
from typing import List, Optional
from app.core.config import settings
from app.services.ai_providers.base import AIProvider, ChatMessage
from app.services.ai_providers.parser import AIResponseParser


class OpenAIProvider(AIProvider):
    """OpenAI GPT-4o Vision Provider"""

    @property
    def provider_name(self) -> str:
        return "openai"

    async def identify_disease(
        self, image_bytes: bytes, crop_info: Optional[dict] = None,
        language: str = "zh", version: str = "vegetable",
    ) -> List:
        base64_image = base64.b64encode(image_bytes).decode()

        system_prompt = self._build_system_prompt(version, language)
        user_prompt = "请识别这张图片中的植物病虫害。" + (f"作物类型: {crop_info['crop_name']}" if crop_info else "")

        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.ai_api_key}"},
                json={
                    "model": settings.ai_model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": [
                            {"type": "text", "text": user_prompt},
                            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}},
                        ]},
                    ],
                    "max_tokens": settings.ai_max_tokens,
                    "temperature": settings.ai_temperature,
                },
            )
            response.raise_for_status()
            data = response.json()
            raw_text = data["choices"][0]["message"]["content"]

        return AIResponseParser.parse(raw_text, self.provider_name, language)

    async def chat(self, message: str, history: List[ChatMessage], language: str = "zh", version: str = "vegetable") -> str:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.ai_api_key}"},
                json={"model": "gpt-4o", "messages": [{"role": "user", "content": message}], "max_tokens": 500},
            )
            data = response.json()
            return data["choices"][0]["message"]["content"]

    async def generate_prevention_plan(self, disease_info: dict, language: str = "zh") -> dict:
        return {}  # 暂未实现，由本地数据库提供

    def _build_system_prompt(self, version: str, language: str) -> str:
        crop_type = "蔬菜" if version == "vegetable" else "果树"
        lang_instr = "用中文回复" if language == "zh" else "用老挝语回复 (ຕອບເປັນພາສາລາວ)"
        return f"""你是{crop_type}病虫害诊断专家。{lang_instr}。输出JSON格式:
{{"results":[{{"disease_name_zh":"", "disease_name_lo":"", "confidence":0.0, "type":"disease|pest",
"symptoms_zh":"", "conditions_zh":"", "severity":"mild|moderate|severe",
"prevention_plan":{{"chemical":[],"biological":[],"cultivation":[]}}}}]}}"""
