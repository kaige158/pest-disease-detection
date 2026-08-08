"""AI Provider 抽象接口 — 支持多模型可替换"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class IdentificationResult:
    """病虫害识别结果"""
    rank: int
    disease_name_zh: str
    disease_name_lo: str
    confidence: float
    type: str  # 'disease' | 'pest'
    severity: str = "moderate"
    description_zh: str = ""
    description_lo: str = ""
    prevention_plan: dict = field(default_factory=dict)


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
        """Provider名称标识"""
        pass

    @abstractmethod
    async def identify_disease(
        self,
        image_bytes: bytes,
        crop_info: Optional[dict] = None,
        language: str = "zh",
        version: str = "vegetable",
    ) -> List[IdentificationResult]:
        """
        病虫害图片识别

        Args:
            image_bytes: 图片二进制数据
            crop_info: 作物信息(可选)，用于缩小识别范围
            language: 用户语言 'zh' | 'lo'
            version: 'vegetable' | 'fruit'

        Returns:
            识别结果列表，按置信度降序排列
        """
        pass

    @abstractmethod
    async def chat(
        self,
        message: str,
        history: List[ChatMessage],
        language: str = "zh",
        version: str = "vegetable",
    ) -> str:
        """
        AI农业助手对话

        Args:
            message: 用户消息
            history: 对话历史
            language: 用户语言
            version: 版本标识

        Returns:
            AI回复文本
        """
        pass

    @abstractmethod
    async def generate_prevention_plan(
        self,
        disease_info: dict,
        language: str = "zh",
    ) -> dict:
        """
        生成防控方案

        Args:
            disease_info: 病虫害信息
            language: 输出语言

        Returns:
            防控方案字典，包含 chemical/biological/physical/cultivation
        """
        pass
