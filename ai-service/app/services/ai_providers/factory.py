"""AI Provider 工厂 — 根据配置创建Provider实例

支持:
- mock: 开发测试，零成本
- openai: OpenAI GPT-4o Vision
- claude: Claude Vision
- gemini: Google Gemini Vision
- custom: 国内模型
"""

from app.core.config import settings
from app.services.ai_providers.base import AIProvider


def get_ai_provider() -> AIProvider:
    """工厂函数: 根据 .env 中的 AI_PROVIDER 返回对应实例"""
    provider_name = settings.ai_provider.lower()

    if provider_name == "mock":
        from app.services.ai_providers.mock_provider import MockAIProvider
        return MockAIProvider()

    elif provider_name == "openai":
        from app.services.ai_providers.openai_provider import OpenAIProvider
        return OpenAIProvider()

    elif provider_name == "claude":
        from app.services.ai_providers.claude_provider import ClaudeProvider
        return ClaudeProvider()

    elif provider_name == "gemini":
        from app.services.ai_providers.gemini_provider import GeminiProvider
        return GeminiProvider()

    elif provider_name == "custom":
        from app.services.ai_providers.custom_provider import CustomProvider
        return CustomProvider()

    else:
        # 默认使用Mock，不阻塞开发
        print(f"[WARN] 未知的AI Provider: {provider_name}, 回退到Mock")
        from app.services.ai_providers.mock_provider import MockAIProvider
        return MockAIProvider()
