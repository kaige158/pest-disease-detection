"""AI Provider 抽象接口 + 真实Provider占位"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class ChatMessage:
    """对话消息"""
    role: str  # 'user' | 'assistant' | 'system'
    content: str


class AIProvider(ABC):
    """AI服务抽象基类 — 所有Provider必须实现此接口"""

    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass

    @abstractmethod
    async def identify_disease(
        self,
        image_bytes: bytes,
        crop_info: Optional[dict] = None,
        language: str = "zh",
        version: str = "vegetable",
    ) -> List:
        """病虫害图片识别 → 返回 DiagnosisResult 列表"""
        pass

    @abstractmethod
    async def chat(
        self,
        message: str,
        history: List[ChatMessage],
        language: str = "zh",
        version: str = "vegetable",
    ) -> str:
        """AI农业助手对话"""
        pass

    @abstractmethod
    async def generate_prevention_plan(
        self,
        disease_info: dict,
        language: str = "zh",
    ) -> dict:
        """生成防控方案"""
        pass
