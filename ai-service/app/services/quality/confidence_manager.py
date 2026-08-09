"""AI置信度管理器 — 根据置信度决定响应策略

集成到识别管线:
    from app.services.quality.confidence_manager import ConfidenceManager
    manager = ConfidenceManager()
    action = manager.decide(confidence=0.85)
    → ConfidenceAction.MEDIUM: 返回结果+提示复核标记
"""
from dataclasses import dataclass
from enum import Enum
from typing import Optional


class ConfidenceAction(str, Enum):
    """置信度决策动作"""
    HIGH = "high"           # >= 90% — 直接返回，高可信
    MEDIUM = "medium"       # 70-90% — 返回结果，提示用户复核
    LOW = "low"             # 50-70% — 返回结果，进入专家审核队列
    REJECT = "reject"       # < 50%  — 建议重新拍照，不返回确定结果


@dataclass
class ConfidenceDecision:
    """置信度决策结果"""
    confidence: float
    level: str              # high / medium / low
    action: ConfidenceAction
    can_direct_return: bool  # 是否可以直接返回给用户
    need_expert_review: bool  # 是否需要专家审核
    need_alternative: bool    # 是否需要提供备选方案
    user_message_zh: str      # 给用户的中文提示
    user_message_lo: str      # 给用户的老挝语提示
    recommendation: str       # 给系统的建议


class ConfidenceManager:
    """置信度策略管理器

    规则:
        >= 0.90 → HIGH:    直接返回，标记"高可信"
        0.70-0.90 → MEDIUM: 返回结果，提示"建议复核"
        0.50-0.70 → LOW:    返回结果+备选方案，进入专家审核
        < 0.50  → REJECT:   建议重新拍照/描述症状
    """

    HIGH_THRESHOLD = 0.90
    MEDIUM_THRESHOLD = 0.70
    LOW_THRESHOLD = 0.50

    def decide(self, confidence: float, top_result_name: str = "",
               alternatives: list = None, language: str = "zh") -> ConfidenceDecision:
        """根据置信度做出决策

        Args:
            confidence: AI置信度 (0.0-1.0)
            top_result_name: 最佳匹配的病虫害名
            alternatives: 备选结果列表
            language: 用户语言 (zh/lo)
        """
        confidence = max(0.0, min(1.0, confidence))

        if confidence >= self.HIGH_THRESHOLD:
            return ConfidenceDecision(
                confidence=confidence,
                level="high",
                action=ConfidenceAction.HIGH,
                can_direct_return=True,
                need_expert_review=False,
                need_alternative=False,
                user_message_zh=f"AI高度可信({confidence:.0%})，诊断为: {top_result_name}",
                user_message_lo=f"AI ເຊື່ອຖືໄດ້ສູງ ({confidence:.0%}), ກວດພົບ: {top_result_name}",
                recommendation="直接返回结果，无需额外处理",
            )
        elif confidence >= self.MEDIUM_THRESHOLD:
            return ConfidenceDecision(
                confidence=confidence,
                level="medium",
                action=ConfidenceAction.MEDIUM,
                can_direct_return=True,
                need_expert_review=False,
                need_alternative=True,
                user_message_zh=f"AI判断: 可能是'{top_result_name}'(置信度{confidence:.0%})，建议结合田间观察确认",
                user_message_lo=f"AI ຄາດວ່າ: ອາດເປັນ '{top_result_name}' ({confidence:.0%}), ກະລຸນາກວດສອບດ້ວຍຕົນເອງ",
                recommendation="返回结果+备选方案，提示用户自行复核",
            )
        elif confidence >= self.LOW_THRESHOLD:
            return ConfidenceDecision(
                confidence=confidence,
                level="low",
                action=ConfidenceAction.LOW,
                can_direct_return=True,
                need_expert_review=True,
                need_alternative=True,
                user_message_zh=f"AI不确定(置信度{confidence:.0%})，可能为'{top_result_name}'，已提交专家审核，稍后通知您",
                user_message_lo=f"AI ບໍ່ແນ່ໃຈ ({confidence:.0%}), ອາດເປັນ '{top_result_name}', ຈະໃຫ້ຜູ້ຊ່ຽວຊານກວດສອບ",
                recommendation="返回结果+备选方案，标记需专家审核，通知用户等待",
            )
        else:
            return ConfidenceDecision(
                confidence=confidence,
                level="low",
                action=ConfidenceAction.REJECT,
                can_direct_return=False,
                need_expert_review=True,
                need_alternative=False,
                user_message_zh=f"AI无法确定(置信度{confidence:.0%})，建议: 1)在光线充足处重新拍照 2)确保病害部位清晰可见 3)尝试使用诊断Agent逐步描述症状",
                user_message_lo=f"AI ບໍ່ສາມາດລະບຸໄດ້ ({confidence:.0%}), ແນະນຳ: ຖ່າຍຮູບໃໝ່ໃນບ່ອນມີແສງ ຫຼື ໃຊ້ການວິນິດໄສແບບຂັ້ນຕອນ",
                recommendation="拒绝低质量结果，引导用户重新采集或使用Agent",
            )

    def enrich_api_response(self, api_response: dict, decision: ConfidenceDecision) -> dict:
        """将置信度决策信息注入API响应"""
        api_response["confidence_level"] = decision.level
        api_response["confidence_action"] = decision.action.value
        api_response["need_expert_review"] = decision.need_expert_review
        api_response["can_direct_return"] = decision.can_direct_return
        api_response["user_hint_zh"] = decision.user_message_zh
        api_response["user_hint_lo"] = decision.user_message_lo
        return api_response

    def should_cache_result(self, decision: ConfidenceDecision) -> bool:
        """判断是否应该缓存结果（高置信度结果适合缓存）"""
        return decision.action == ConfidenceAction.HIGH

    def get_retry_suggestion(self, decision: ConfidenceDecision) -> Optional[str]:
        """获取重试建议（当结果为REJECT时）"""
        if decision.action == ConfidenceAction.REJECT:
            return (
                "请尝试以下操作:\n"
                "1. 在自然光下拍摄，避免阴影\n"
                "2. 确保病害部位占画面的50%以上\n"
                "3. 对焦清晰后再拍摄\n"
                "4. 可尝试拍摄多个角度\n"
                "5. 或使用「诊断Agent」逐步描述症状"
            )
        return None


# 全局单例
confidence_manager = ConfidenceManager()
