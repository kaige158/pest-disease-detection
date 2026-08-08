"""标准化农业诊断结果 — 全系统核心数据对象"""

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional


class ConfidenceLevel(str, Enum):
    HIGH = "high"       # >= 90%
    MEDIUM = "medium"   # 70-89%
    LOW = "low"         # < 70%


@dataclass
class Symptom:
    """症状描述"""
    name_zh: str
    name_lo: str = ""


@dataclass
class PreventionItem:
    """防控措施条目"""
    method_zh: str
    method_lo: str = ""
    details_zh: str = ""
    details_lo: str = ""


@dataclass
class PreventionPlan:
    """防控方案"""
    chemical: List[PreventionItem] = field(default_factory=list)      # 化学防治
    biological: List[PreventionItem] = field(default_factory=list)    # 生物防治
    physical: List[PreventionItem] = field(default_factory=list)      # 物理防治
    cultivation: List[PreventionItem] = field(default_factory=list)   # 栽培管理


@dataclass
class DiagnosisResult:
    """
    标准化农业诊断结果 — 所有AI Provider输出统一转为此对象

    不论底层用的是 OpenAI / Claude / Gemini / Mock，
    最终都产出 DiagnosisResult，业务系统只看这个。
    """

    # === 病虫害信息 ===
    disease_name_zh: str            # 病虫害中文名
    disease_name_lo: str = ""       # 病虫害老挝语名
    scientific_name: str = ""       # 病原/虫害学名
    disease_type: str = "disease"   # disease / pest / physiological

    # === 置信度 ===
    confidence: float = 0.0         # 0.0 - 1.0
    confidence_level: ConfidenceLevel = ConfidenceLevel.LOW

    # === 症状 ===
    symptoms: List[Symptom] = field(default_factory=list)
    symptoms_text_zh: str = ""      # 症状总述(中文)
    symptoms_text_lo: str = ""      # 症状总述(老挝语)

    # === 发病条件 ===
    conditions_zh: str = ""
    conditions_lo: str = ""

    # === 严重程度 ===
    severity: str = "moderate"      # mild / moderate / severe

    # === 防控方案 ===
    prevention_plan: Optional[PreventionPlan] = None

    # === AI原始响应(调试用) ===
    raw_response: str = ""

    # === 是否需要专家审核 ===
    need_expert_review: bool = False

    # === 备选结果(置信度较低时的其他可能) ===
    alternative_results: List["DiagnosisResult"] = field(default_factory=list)

    # === 元数据 ===
    provider_name: str = ""         # 使用的AI Provider
    parse_method: str = ""          # 使用的解析方法
    processing_time_ms: int = 0     # 处理耗时(毫秒)

    def to_dict(self) -> dict:
        """转为API响应用的字典"""
        result = {
            "disease_name_zh": self.disease_name_zh,
            "disease_name_lo": self.disease_name_lo,
            "scientific_name": self.scientific_name,
            "type": self.disease_type,
            "confidence": self.confidence,
            "confidence_level": self.confidence_level.value,
            "severity": self.severity,
            "symptoms_zh": self.symptoms_text_zh,
            "symptoms_lo": self.symptoms_text_lo,
            "conditions_zh": self.conditions_zh,
            "conditions_lo": self.conditions_lo,
            "need_expert_review": self.need_expert_review,
            "provider": self.provider_name,
            "processing_time_ms": self.processing_time_ms,
        }

        # 防控方案
        if self.prevention_plan:
            plan = self.prevention_plan
            result["prevention"] = {
                "chemical": [{"method_zh": p.method_zh, "method_lo": p.method_lo, "details_zh": p.details_zh, "details_lo": p.details_lo} for p in plan.chemical],
                "biological": [{"method_zh": p.method_zh, "method_lo": p.method_lo, "details_zh": p.details_zh, "details_lo": p.details_lo} for p in plan.biological],
                "physical": [{"method_zh": p.method_zh, "method_lo": p.method_lo, "details_zh": p.details_zh, "details_lo": p.details_lo} for p in plan.physical],
                "cultivation": [{"method_zh": p.method_zh, "method_lo": p.method_lo, "details_zh": p.details_zh, "details_lo": p.details_lo} for p in plan.cultivation],
            }

        # 备选结果
        if self.alternative_results:
            result["alternatives"] = [r.to_dict() for r in self.alternative_results[:3]]

        return result
