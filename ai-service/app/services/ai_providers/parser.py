"""AI Response Parser — 将Vision API的原始响应标准化为DiagnosisResult"""

# 延迟解析注解：本模块使用了 PEP 604 写法（如 `dict | None`），
# 该写法在 Python 3.10+ 才可用于运行时求值。
# 加上 future import 后，Python 3.8/3.9 也能正常导入本模块，
# 便于在低版本环境下做单元验证（正式运行仍建议 3.11+）。
from __future__ import annotations

import json
import re
import time
from typing import List

from app.services.ai_providers.diagnosis_result import (
    DiagnosisResult, ConfidenceLevel, PreventionPlan, PreventionItem
)


class AIResponseParser:
    """
    通用AI响应解析器

    处理不同模型返回的不同格式:
    - OpenAI: 通常JSON
    - Claude: 可能自然语言+JSON混合
    - Gemini: JSON
    """

    @staticmethod
    def parse(raw_response: str, provider_name: str = "", language: str = "zh") -> List[DiagnosisResult]:
        """解析AI原始响应 → 标准化DiagnosisResult列表"""

        start_time = time.time() * 1000

        # 策略1: 直接JSON
        json_data = AIResponseParser._extract_json(raw_response)
        if json_data:
            results = AIResponseParser._parse_json_result(json_data, provider_name)
            if results:
                return results

        # 策略2: 提取置信度百分比
        results = AIResponseParser._fallback_parse(raw_response, provider_name)

        elapsed = int(time.time() * 1000 - start_time)
        for r in results:
            r.parse_method = "fallback" if not json_data else "json"
            r.processing_time_ms = elapsed

        return results

    @staticmethod
    def _extract_json(text: str) -> dict | None:
        """从文本中提取JSON对象"""
        # 尝试直接解析
        try:
            data = json.loads(text)
            if isinstance(data, dict):
                return data
        except json.JSONDecodeError:
            pass

        # 提取 ```json ... ``` 代码块
        match = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(1))
            except json.JSONDecodeError:
                pass

        # 提取最外层 { ... }
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError:
                pass

        return None

    @staticmethod
    def _parse_json_result(data: dict, provider_name: str) -> List[DiagnosisResult]:
        """解析JSON格式的AI响应"""
        results = []

        # 格式1: {"results": [...]}
        items = data.get("results", [])
        if not isinstance(items, list):
            items = [data]  # 格式2: 单个对象

        for item in items:
            if not isinstance(item, dict):
                continue

            confidence = float(item.get("confidence", 0.5))

            # 防控方案（兼容 dict 和 string 两种格式）
            def _to_item(m):
                """将dict或str转为PreventionItem"""
                if isinstance(m, dict):
                    return PreventionItem(
                        method_zh=m.get("name_zh", m.get("method_zh", m.get("name", ""))),
                        details_zh=m.get("usage_zh", m.get("details_zh", m.get("usage", ""))),
                    )
                elif isinstance(m, str):
                    return PreventionItem(method_zh=m, details_zh="")
                return PreventionItem(method_zh=str(m), details_zh="")

            prevention = item.get("prevention_plan") or item.get("prevention") or {}
            plan = PreventionPlan(
                chemical=[_to_item(m) for m in prevention.get("chemical", prevention.get("chemical_zh", []))],
                biological=[_to_item(m) for m in prevention.get("biological", prevention.get("biological_zh", []))],
                physical=[_to_item(m) for m in prevention.get("physical", prevention.get("physical_zh", []))],
                cultivation=[_to_item(m) for m in prevention.get("cultivation", prevention.get("cultivation_zh", []))],
            )

            result = DiagnosisResult(
                disease_name_zh=item.get("disease_name_zh", item.get("disease_name", item.get("name_zh", ""))),
                disease_name_lo=item.get("disease_name_lo", item.get("name_lo", "")),
                scientific_name=item.get("scientific_name", ""),
                disease_type=item.get("type", "disease"),
                confidence=confidence,
                confidence_level=AIResponseParser._classify(confidence),
                symptoms_text_zh=item.get("symptoms_zh", item.get("symptoms", "")),
                symptoms_text_lo=item.get("symptoms_lo", ""),
                conditions_zh=item.get("conditions_zh", item.get("conditions", "")),
                severity=item.get("severity", "moderate"),
                prevention_plan=plan,
                need_expert_review=False,  # 由 confidence_manager 统一决策(recognition.py enrich)，此处不设
                provider_name=provider_name,
                parse_method="json",
                raw_response=json.dumps(data, ensure_ascii=False),
            )
            results.append(result)

        return results

    @staticmethod
    def _fallback_parse(text: str, provider_name: str) -> List[DiagnosisResult]:
        """兜底解析: JSON提取失败时，从自然语言中提取关键信息"""

        # 提取置信度
        conf_match = re.search(r'(\d{1,3})\s*%', text)
        confidence = float(conf_match.group(1)) / 100 if conf_match else 0.5

        # 取前200字符作为名称
        name = text[:200].replace('\n', ' ').strip()

        return [DiagnosisResult(
            disease_name_zh=name,
            confidence=confidence,
            confidence_level=AIResponseParser._classify(confidence),
            need_expert_review=True,
            provider_name=provider_name,
            parse_method="fallback",
            raw_response=text,
        )]

    @staticmethod
    def _classify(confidence: float) -> ConfidenceLevel:
        if confidence >= 0.90:
            return ConfidenceLevel.HIGH
        elif confidence >= 0.70:
            return ConfidenceLevel.MEDIUM
        return ConfidenceLevel.LOW
