"""Custom Vision Provider — 对接国内视觉模型API (预留: 通义千问/文心一言/智谱等)"""
from typing import List, Optional
from app.services.ai_providers.base import AIProvider, ChatMessage


class CustomProvider(AIProvider):
    @property
    def provider_name(self) -> str:
        return "custom"

    async def identify_disease(self, *args, **kwargs) -> List:
        raise NotImplementedError("Custom Provider — 待实现(需API endpoint配置)")

    async def chat(self, *args, **kwargs) -> str:
        raise NotImplementedError("Custom Provider — 待实现")

    async def generate_prevention_plan(self, *args, **kwargs) -> dict:
        return {}
