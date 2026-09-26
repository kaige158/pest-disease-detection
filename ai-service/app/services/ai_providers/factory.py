"""AI Provider 工厂 — 根据配置创建 Provider 实例

配置来源优先级：
    1. 业务后端随请求下发的运行时配置（core.ai_provider_config 表，管理员后台维护）
    2. .env 中的默认配置（本地开发可裸跑）

支持:
- mock: 开发测试，零成本，无需密钥
- gemini: Google Gemini Vision（推荐，有免费额度）
- kimi: 月之暗面 Kimi（国内可直连）
- openai: OpenAI GPT-4o Vision
- claude: Anthropic Claude Vision
- deepseek: DeepSeek（OpenAI 兼容协议，国内直连）
- custom: 其它兼容 OpenAI 协议的厂商 / 自建代理（通义千问、智谱等）
"""

from typing import Optional

from app.core.config import settings
from app.services.ai_providers.base import AIProvider, ProviderConfig

#: 支持的通道类型（与后台下拉选项、Java 侧校验保持一致）
SUPPORTED_PROVIDERS = ("mock", "gemini", "kimi", "openai", "claude", "deepseek", "custom")


def build_provider(config: Optional[ProviderConfig] = None) -> AIProvider:
    """按运行时配置构建 Provider（推荐入口）

    :param config: 来自后台 AI 配置中心；为空则回退 .env
    """
    cfg = config or ProviderConfig()
    provider_name = (cfg.provider or settings.ai_provider or "mock").lower()

    if provider_name == "mock":
        from app.services.ai_providers.mock_provider import MockAIProvider
        return MockAIProvider(cfg)

    if provider_name == "gemini":
        from app.services.ai_providers.gemini_provider import GeminiProvider
        return GeminiProvider(cfg)

    if provider_name == "kimi":
        from app.services.ai_providers.kimi_provider import KimiProvider
        return KimiProvider(cfg)

    if provider_name == "openai":
        from app.services.ai_providers.openai_provider import OpenAIProvider
        return OpenAIProvider(cfg)

    if provider_name == "claude":
        from app.services.ai_providers.claude_provider import ClaudeProvider
        return ClaudeProvider(cfg)

    if provider_name == "deepseek":
        from app.services.ai_providers.compatible_provider import DeepSeekProvider
        return DeepSeekProvider(cfg)

    if provider_name == "custom":
        from app.services.ai_providers.compatible_provider import CustomProvider
        return CustomProvider(cfg)

    print(f"[WARN] 未知的AI Provider: {provider_name}, 回退到Mock")
    from app.services.ai_providers.mock_provider import MockAIProvider
    return MockAIProvider(cfg)


def get_ai_provider(config: Optional[ProviderConfig] = None) -> AIProvider:
    """兼容旧调用点：不传配置时等价于「使用 .env 默认配置」"""
    return build_provider(config)
