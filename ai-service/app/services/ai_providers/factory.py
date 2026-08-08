"""AI Provider 工厂 — 根据配置创建对应的Provider实例"""
from app.core.config import settings
from app.services.ai_providers.base import AIProvider


class ProviderNotFoundError(Exception):
    """未找到指定的AI Provider"""
    pass


def get_ai_provider() -> AIProvider:
    """
    工厂函数：根据配置返回AI Provider实例。
    切换模型只需修改 .env 中的 AI_PROVIDER 和 AI_API_KEY。
    具体实现在第四阶段完成。
    """
    provider_name = settings.ai_provider.lower()

    # 第四阶段实现具体的Provider后，取消对应注释
    if provider_name == "openai":
        # from app.services.ai_providers.openai import OpenAIProvider
        # return OpenAIProvider()
        raise ProviderNotFoundError("OpenAI Provider 尚未实现 (第四阶段)")
    elif provider_name == "claude":
        # from app.services.ai_providers.claude import ClaudeProvider
        # return ClaudeProvider()
        raise ProviderNotFoundError("Claude Provider 尚未实现 (第四阶段)")
    elif provider_name == "gemini":
        # from app.services.ai_providers.gemini import GeminiProvider
        # return GeminiProvider()
        raise ProviderNotFoundError("Gemini Provider 尚未实现 (第四阶段)")
    elif provider_name == "custom":
        # from app.services.ai_providers.custom import CustomProvider
        # return CustomProvider()
        raise ProviderNotFoundError("Custom Provider 尚未实现 (第四阶段)")
    else:
        raise ProviderNotFoundError(f"未知的AI Provider: {provider_name}")
