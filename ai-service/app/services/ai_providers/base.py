"""AI Provider 抽象接口 + 真实Provider占位"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import List, Optional

from app.core.config import settings


@dataclass
class ChatMessage:
    """对话消息"""
    role: str  # 'user' | 'assistant' | 'system'
    content: str


@dataclass
class ProviderConfig:
    """运行时 Provider 配置 —— 由业务后端（管理员在后台配置）随请求下发

    设计说明：
        配置的唯一来源是 core.ai_provider_config 表（管理员可视化维护）。
        业务后端在调用 AI 服务时把当前生效配置放进请求体，
        因此 AI 服务无需直连数据库、无需重启即可切换通道。

        各字段为空时回退到 .env 中的默认值（保证本地开发仍可裸跑）。
    """

    provider: str = ""
    api_key: str = ""
    model: str = ""
    base_url: str = ""
    max_tokens: int = 0
    temperature: float = -1.0
    timeout_seconds: int = 0

    @classmethod
    def from_dict(cls, data: Optional[dict]) -> "ProviderConfig":
        if not data:
            return cls()
        return cls(
            provider=str(data.get("provider") or "").strip().lower(),
            api_key=str(data.get("api_key") or "").strip(),
            model=str(data.get("model") or "").strip(),
            base_url=str(data.get("base_url") or "").strip(),
            max_tokens=int(data.get("max_tokens") or 0),
            temperature=float(data.get("temperature") if data.get("temperature") is not None else -1),
            timeout_seconds=int(data.get("timeout_seconds") or 0),
        )


class AIProvider(ABC):
    """AI服务抽象基类 — 所有Provider必须实现此接口"""

    #: 该 Provider 在未注入 model 时使用的默认模型名
    DEFAULT_MODEL = ""

    def __init__(self, config: Optional[ProviderConfig] = None):
        """
        :param config: 运行时配置（来自后台 AI 配置中心）；为空则完全使用 .env
        """
        self.config = config or ProviderConfig()
        # 关键：把配置固化为实例属性，Provider 内部一律读 self.xxx，
        # 避免运行时去改全局 settings（那会带来并发与状态污染问题）
        self.api_key = self.config.api_key or settings.ai_api_key
        self.model = self.config.model or self.DEFAULT_MODEL or settings.ai_model
        self.base_url = (self.config.base_url or settings.ai_base_url or "").rstrip("/")
        self.max_tokens = self.config.max_tokens or settings.ai_max_tokens
        self.temperature = (
            self.config.temperature if self.config.temperature >= 0 else settings.ai_temperature
        )
        self.timeout_seconds = self.config.timeout_seconds or 60

    @property
    @abstractmethod
    def provider_name(self) -> str:
        pass

    def _endpoint(self, default_url: str, path: str) -> str:
        """解析接口地址 —— 支持后台配置自定义/代理地址

        base_url 允许两种写法：
          * 只写主机（如 https://api.moonshot.cn）→ 自动补 path
          * 写完整地址（如 https://proxy.example.com/v1/chat/completions）→ 原样使用
        未配置时用 Provider 内置的官方地址。
        """
        if not self.base_url:
            return default_url
        if self.base_url.endswith(path):
            return self.base_url
        if "/v1/" in self.base_url or self.base_url.endswith("/v1"):
            return f"{self.base_url}{path}"
        return f"{self.base_url}{path}"

    #: 发给模型前把图压到这个长边 / 大小以内
    IMAGE_MAX_SIDE = 1200
    IMAGE_MAX_KB = 2000

    def _compress_image(
        self,
        image_bytes: bytes,
        max_size_kb: int = None,
        max_side: int = None,
    ) -> tuple:
        """把上传原图压成"模型友好"的尺寸，返回 (bytes, mime_type)

        为什么放在基类：所有 Provider 都要处理同一件事 ——
        手机/语料原图常见 4000×3000、2~4MB，直接 base64 会变成 3~5MB 的请求体，
        有的厂商直接 413 拒绝，有的即使收下也要多花好几倍 token。
        压缩到长边 1200px 对病虫害识别精度几乎没有影响（病斑细节仍清晰），
        但体积通常降到 200~400KB。

        注意顺序：**质量检测用原图**（要看真实分辨率与清晰度），
        压缩只发生在"准备发给模型"这一步。
        """
        max_size_kb = max_size_kb or self.IMAGE_MAX_KB
        max_side = max_side or self.IMAGE_MAX_SIDE
        mime_type = self._detect_mime_type(image_bytes)

        if len(image_bytes) <= max_size_kb * 1024 and not self._needs_resize(image_bytes, max_side):
            return image_bytes, mime_type

        try:
            import io
            from PIL import Image, ImageOps

            img = Image.open(io.BytesIO(image_bytes))
            img.load()
            img = ImageOps.exif_transpose(img)

            if max(img.size) > max_side:
                ratio = max_side / max(img.size)
                img = img.resize(
                    (max(1, int(img.width * ratio)), max(1, int(img.height * ratio))),
                    Image.LANCZOS,
                )

            if img.mode in ("RGBA", "P", "LA", "CMYK"):
                img = img.convert("RGB")

            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=75)
            compressed = buf.getvalue()

            if len(compressed) > max_size_kb * 1024:
                buf = io.BytesIO()
                img.save(buf, format="JPEG", quality=40)
                compressed = buf.getvalue()

            return compressed, "image/jpeg"
        except Exception:
            # 压缩失败就退回原图：宁可多花 token，也不能让识别直接失败
            return image_bytes, mime_type

    def _needs_resize(self, image_bytes: bytes, max_side: int) -> bool:
        """只看文件头判断尺寸，不解码整张图（大图解码本身就很贵）"""
        try:
            import io
            from PIL import Image

            with Image.open(io.BytesIO(image_bytes)) as img:
                return max(img.size) > max_side
        except Exception:
            return False

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
