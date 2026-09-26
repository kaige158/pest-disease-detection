"""Gemini Vision Provider — Google Gemini 2.5 Flash/Pro 视觉识别"""
import asyncio
import base64
import io
import httpx
from typing import List, Optional
from app.core.config import settings
from app.services.ai_providers.base import AIProvider, ChatMessage
from app.services.ai_providers.parser import AIResponseParser


class GeminiProvider(AIProvider):
    """Google Gemini Vision Provider — 支持图片识别和文本对话

    API文档: https://ai.google.dev/gemini-api/docs/vision
    使用 Gemini 原生 REST API (generateContent)
    """

    BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
    DEFAULT_MODEL = "gemini-3.6-flash"
    MAX_RETRIES = 3
    RETRY_DELAY = 2  # 秒

    @property
    def provider_name(self) -> str:
        return "gemini"

    async def _call_api(self, url: str, body: dict) -> dict:
        """调用Gemini API，带自动重试"""
        last_error = None
        for attempt in range(self.MAX_RETRIES):
            try:
                async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
                    response = await client.post(url, json=body)
                    if response.is_success:
                        return response.json()
                    # HTTP错误（非429时直接抛出）
                    if response.status_code != 429:
                        error_detail = response.text
                        try:
                            err = response.json()
                            error_detail = err.get("error", {}).get("message", error_detail)
                        except Exception:
                            pass
                        raise RuntimeError(
                            f"Gemini API错误 (HTTP {response.status_code}): {error_detail}"
                        )
                    # 429: 频率限制，重试
                    last_error = f"HTTP 429 (频率限制)"
            except (httpx.RemoteProtocolError, httpx.ConnectError, httpx.ReadError) as e:
                last_error = str(e)
            except RuntimeError:
                raise  # 非429的HTTP错误不重试

            if attempt < self.MAX_RETRIES - 1:
                wait = self.RETRY_DELAY * (attempt + 1)
                await asyncio.sleep(wait)

        raise RuntimeError(f"Gemini API调用失败(重试{self.MAX_RETRIES}次): {last_error}")

    async def identify_disease(
        self, image_bytes: bytes, crop_info: Optional[dict] = None,
        language: str = "zh", version: str = "vegetable",
    ) -> List:
        compressed, mime_type = self._compress_image(image_bytes, max_size_kb=2000)
        base64_image = base64.b64encode(compressed).decode()
        crop_name = crop_info.get("crop_name", "") if crop_info else ""
        crop_hint = f"作物类型可能是: {crop_name}" if crop_name else ""

        model = self.model or "gemini-2.5-flash"
        url = f"{self.BASE_URL}/models/{model}:generateContent?key={self.api_key}"

        user_text = f"请识别这张图片中的植物病虫害。{crop_hint}"

        body = {
            "systemInstruction": {
                "parts": [{"text": self._system_prompt(version, language)}]
            },
            "contents": [{
                "parts": [
                    {
                        "inlineData": {
                            "mimeType": mime_type,
                            "data": base64_image
                        }
                    },
                    {"text": user_text}
                ]
            }],
            "generationConfig": {
                "maxOutputTokens": settings.ai_max_tokens,
                "temperature": settings.ai_temperature,
            },
            "safetySettings": [
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
            ],
        }

        data = await self._call_api(url, body)

        raw_text = ""
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            raw_text = "".join(p.get("text", "") for p in parts)

        if not raw_text and candidates:
            finish_reason = candidates[0].get("finishReason", "")
            if finish_reason and finish_reason != "STOP":
                raise RuntimeError(
                    f"Gemini响应被拦截: finishReason={finish_reason}"
                )

        if not raw_text:
            raise RuntimeError(
                f"Gemini返回空响应，原始数据: {str(data)[:500]}"
            )

        return AIResponseParser.parse(raw_text, self.provider_name, language)

    async def chat(
        self, message: str, history: List[ChatMessage],
        language: str = "zh", version: str = "vegetable",
    ) -> str:
        model = self.model or "gemini-2.5-flash"
        url = f"{self.BASE_URL}/models/{model}:generateContent?key={self.api_key}"

        contents = []
        for h in history[-10:]:
            role = "user" if h.role == "user" else "model"
            contents.append({
                "role": role,
                "parts": [{"text": h.content}]
            })
        contents.append({
            "role": "user",
            "parts": [{"text": message}]
        })

        crop_type = "蔬菜" if version == "vegetable" else "果树"
        if language == "zh":
            lang_instr = "用中文回复"
        else:
            lang_instr = "用老挝语回复(ຕອບເປັນພາສາລາວ)"

        system_text = (
            f"你是{crop_type}农业专家助手，帮助农民解决种植问题。"
            f"{lang_instr}，回答简洁实用。"
        )

        body = {
            "systemInstruction": {
                "parts": [{"text": system_text}]
            },
            "contents": contents,
            "generationConfig": {
                "maxOutputTokens": settings.ai_max_tokens,
                "temperature": 0.3,
            },
        }

        data = await self._call_api(url, body)

        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            return "".join(p.get("text", "") for p in parts)
        return ""

    async def generate_prevention_plan(
        self, disease_info: dict, language: str = "zh",
    ) -> dict:
        model = self.model or "gemini-2.5-flash"
        url = f"{self.BASE_URL}/models/{model}:generateContent?key={self.api_key}"

        disease_name = disease_info.get(
            "disease_name_zh",
            disease_info.get("name_zh", "未知病害")
        )
        if language == "zh":
            lang_instr = "用中文回复"
        else:
            lang_instr = "用老挝语回复"

        prompt_parts = [
            lang_instr,
            "。请为[", disease_name, "]提供详细防控方案，",
            "包括化学防治(农药名称、用法用量)、生物防治、物理防治和栽培管理建议。"
        ]
        user_text = "".join(prompt_parts)

        body = {
            "systemInstruction": {
                "parts": [{"text": "你是农业病虫害防控专家，提供详细的防治方案。"}]
            },
            "contents": [{
                "parts": [{"text": user_text}]
            }],
            "generationConfig": {
                "maxOutputTokens": 1500,
                "temperature": 0.3,
            },
        }

        data = await self._call_api(url, body)

        raw_text = ""
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            raw_text = "".join(p.get("text", "") for p in parts)

        return {"raw_plan": raw_text, "disease": disease_name}

    def _system_prompt(self, version: str, language: str) -> str:
        crop_type = "蔬菜" if version == "vegetable" else "果树"
        if language == "zh":
            lang_instr = "用中文回复"
        else:
            lang_instr = "用老挝语回复(ຕອບເປັນພາສາລາວ)"

        return (
            f"你是{crop_type}病虫害诊断专家。{lang_instr}。\n\n"
            "请严格按以下JSON格式输出(不要任何附加文字，不要markdown代码块标记):\n"
            '{"results":[{"disease_name_zh":"病虫害中文名","disease_name_lo":"老挝语名",'
            '"confidence":0.92,"type":"disease或pest","symptoms_zh":"症状描述",'
            '"conditions_zh":"发病条件","severity":"mild/moderate/severe",'
            '"prevention_plan":{"chemical":[{"name":"农药名","usage":"用法用量"}],'
            '"biological":[{"method":"方法","detail":"说明"}],"cultivation":["栽培管理建议"]}}]}\n\n'
            "如无法识别或不是病虫害图片，confidence设为<0.5并说明原因。只输出JSON，不要markdown。"
        )

    def _compress_image(self, image_bytes: bytes, max_size_kb: int = 2000) -> tuple:
        mime_type = self._detect_mime_type(image_bytes)

        if len(image_bytes) <= max_size_kb * 1024:
            return image_bytes, mime_type

        try:
            from PIL import Image
            img = Image.open(io.BytesIO(image_bytes))

            if img.width > 1200:
                ratio = 1200 / img.width
                img = img.resize(
                    (1200, int(img.height * ratio)), Image.LANCZOS
                )

            if img.mode in ("RGBA", "P", "LA"):
                img = img.convert("RGB")

            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=75)
            compressed = buf.getvalue()
            mime_type = "image/jpeg"

            if len(compressed) > max_size_kb * 1024:
                buf = io.BytesIO()
                img.save(buf, format="JPEG", quality=40)
                compressed = buf.getvalue()

            return compressed, mime_type
        except Exception:
            return image_bytes, mime_type

    @staticmethod
    def _detect_mime_type(image_bytes: bytes) -> str:
        if image_bytes[:2] == b'\xff\xd8':
            return "image/jpeg"
        elif image_bytes[:4] == b'\x89PNG':
            return "image/png"
        elif image_bytes[:4] == b'RIFF' and image_bytes[8:12] == b'WEBP':
            return "image/webp"
        elif image_bytes[:4] == b'GIF8':
            return "image/gif"
        return "image/jpeg"
