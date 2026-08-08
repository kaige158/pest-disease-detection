"""应用配置管理 — 所有配置从 .env 文件读取，绝不硬编码密钥"""
from typing import List
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """应用配置"""
    # 应用
    app_name: str = "中老双语农业病虫害防控API"
    debug: bool = False
    cors_origins: List[str] = ["*"]  # 生产环境应限制具体域名

    # 数据库 (PostgreSQL)
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/laos_agri"

    # Redis (可选)
    redis_url: str = "redis://localhost:6379/0"

    # AI Provider 配置
    ai_provider: str = "openai"  # openai | claude | gemini | custom
    ai_api_key: str = ""         # API Key — 必须通过环境变量注入
    ai_model: str = "gpt-4o"     # 模型名称
    ai_base_url: str = ""        # 自定义API地址（国内模型代理）
    ai_max_tokens: int = 2000
    ai_temperature: float = 0.3   # 低温度确保准确性

    # 文件上传
    upload_max_size_mb: int = 10
    upload_allowed_types: List[str] = ["image/jpeg", "image/png", "image/webp"]
    upload_dir: str = "./uploads"

    # 安全
    secret_key: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 1440  # 24小时

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
    }


settings = Settings()
