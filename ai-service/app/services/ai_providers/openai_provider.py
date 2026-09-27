"""OpenAI Vision Provider — 对接GPT-4o Vision API"""
import base64
import httpx
from typing import List, Optional
from app.core.config import settings
from app.services.ai_providers.base import AIProvider, ChatMessage
from app.services.ai_providers.parser import AIResponseParser


class OpenAIProvider(AIProvider):
    """OpenAI GPT-4o Vision Provider"""

    DEFAULT_URL = "https://api.openai.com/v1/chat/completions"
    DEFAULT_MODEL = "gpt-4o"

    @property
    def provider_name(self) -> str:
        return "openai"

    async def identify_disease(
        self, image_bytes: bytes, crop_info: Optional[dict] = None,
        language: str = "zh", version: str = "vegetable",
    ) -> List:
        # 缺 Key 时给出人话错误（否则 httpx 会抛 Illegal header value b'Bearer '）
        self._require_api_key()
        # 先压缩再 base64：原图 2~4MB → base64 后 3~5MB，很多厂商会直接 413，
        # 而且白烧 token。压缩逻辑统一在基类（Gemini/OpenAI 兼容通道共用）。
        image_bytes, mime_type = self._compress_image(image_bytes)
        base64_image = base64.b64encode(image_bytes).decode()

        system_prompt = self._build_system_prompt(version, language)
        user_prompt = "请识别这张图片中的植物病虫害。" + (f"作物类型: {crop_info['crop_name']}" if crop_info else "")

        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(
                self._endpoint(self.DEFAULT_URL, "/v1/chat/completions"),
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": self.model or self.DEFAULT_MODEL,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": [
                            {"type": "text", "text": user_prompt},
                            {"type": "image_url", "image_url": {"url": f"data:{mime_type};base64,{base64_image}"}},
                        ]},
                    ],
                    "max_tokens": self.max_tokens,
                    "temperature": self.temperature,
                },
            )
            response.raise_for_status()
            data = response.json()
            raw_text = data["choices"][0]["message"]["content"]

        return AIResponseParser.parse(raw_text, self.provider_name, language)

    async def chat(self, message: str, history: List[ChatMessage], language: str = "zh", version: str = "vegetable") -> str:
        self._require_api_key()
        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(
                self._endpoint(self.DEFAULT_URL, "/v1/chat/completions"),
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={"model": self.model or self.DEFAULT_MODEL,
                      "messages": [{"role": "user", "content": message}], "max_tokens": 500},
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
