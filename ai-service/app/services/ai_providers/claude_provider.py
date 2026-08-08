"""Claude Vision Provider — 对接Claude Vision API (预留)"""
from typing import List, Optional
from app.services.ai_providers.base import AIProvider, ChatMessage


class ClaudeProvider(AIProvider):
    @property
    def provider_name(self) -> str:
        return "claude"

    async def identify_disease(self, *args, **kwargs) -> List:
        raise NotImplementedError("Claude Provider — 待实现(需API Key后激活)")

    async def chat(self, *args, **kwargs) -> str:
        raise NotImplementedError("Claude Provider — 待实现")

    async def generate_prevention_plan(self, *args, **kwargs) -> dict:
        return {}
