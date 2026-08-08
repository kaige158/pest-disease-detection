"""Mock AI Provider — 开发/测试阶段使用，不需要API Key，零成本"""

import random
import time
from typing import List, Optional

from app.services.ai_providers.base import AIProvider, ChatMessage
from app.services.ai_providers.diagnosis_result import (
    DiagnosisResult, ConfidenceLevel, Symptom, PreventionPlan, PreventionItem
)


# ===== Mock数据: 模拟真实病虫害识别 =====
MOCK_DISEASES = {
    "vegetable": [
        {
            "disease_name_zh": "番茄晚疫病",
            "disease_name_lo": "ພະຍາດໃບໄໝ້ໝາກເລັ່ນ",
            "scientific_name": "Phytophthora infestans",
            "type": "disease",
            "symptoms_zh": "叶片出现水渍状暗绿色斑点，湿度大时叶背有白色霉层，严重时全株枯死。",
            "symptoms_lo": "ໃບມີຈຸດສີຂຽວເຂັ້ມ, ເມື່ອມີຄວາມຊຸ່ມສູງຈະມີເຊື້ອສີຂາວຢູ່ໃຕ້ໃບ.",
            "conditions_zh": "温度18-22°C，相对湿度>95%时易发病，多雨季节高发。",
            "severity": "severe",
            "chemical": [
                PreventionItem(method_zh="58%甲霜灵锰锌可湿性粉剂500倍液", method_lo="ຢາ Metalaxyl 58%", details_zh="每7天喷1次，连喷2-3次", details_lo="ສີດທຸກໆ 7 ມື້"),
                PreventionItem(method_zh="72%霜脲·锰锌可湿性粉剂600倍液", method_lo="", details_zh="发病初期使用", details_lo=""),
            ],
            "biological": [
                PreventionItem(method_zh="选用抗病品种", method_lo="", details_zh="选择抗晚疫病的番茄品种", details_lo=""),
                PreventionItem(method_zh="轮作倒茬", method_lo="", details_zh="与非茄科作物轮作2-3年", details_lo=""),
            ],
            "cultivation": [
                PreventionItem(method_zh="合理密植，加强通风", method_lo="", details_zh="降低田间湿度", details_lo=""),
                PreventionItem(method_zh="清除病残体", method_lo="", details_zh="发现中心病株立即拔除深埋", details_lo=""),
            ],
        },
        {
            "disease_name_zh": "白菜黑斑病",
            "disease_name_lo": "ພະຍາດຈຸດດຳຜັກກາດ",
            "scientific_name": "Alternaria brassicae",
            "type": "disease",
            "symptoms_zh": "叶片出现圆形或不规则形黑褐色斑点，严重时斑点连片导致叶片枯死。",
            "symptoms_lo": "ໃບມີຈຸດສີນ້ຳຕານດຳ, ເມື່ອເປັນຫຼາຍໃບຈະຕາຍ.",
            "conditions_zh": "温度25-30°C，多雨潮湿时发病重。",
            "severity": "moderate",
            "chemical": [
                PreventionItem(method_zh="50%多菌灵可湿性粉剂500倍液", method_lo="", details_zh="每7-10天喷1次", details_lo=""),
            ],
            "biological": [
                PreventionItem(method_zh="轮作倒茬", method_lo="", details_zh="与非十字花科作物轮作", details_lo=""),
            ],
            "cultivation": [
                PreventionItem(method_zh="清除田间病残体", method_lo="", details_zh="收获后清除残株落叶", details_lo=""),
            ],
        },
        {
            "disease_name_zh": "辣椒炭疽病",
            "disease_name_lo": "ພະຍາດແອນແທຣກໂນສໝາກເຜັດ",
            "scientific_name": "Colletotrichum capsici",
            "type": "disease",
            "symptoms_zh": "果实出现水渍状斑点，后扩大成圆形凹陷病斑，边缘褐色，中央灰白色。",
            "symptoms_lo": "ໝາກມີຈຸດສີນ້ຳ, ຂະຫຍາຍເປັນວົງ, ຂອບສີນ້ຳຕານ.",
            "conditions_zh": "温度25-28°C，相对湿度>90%时易发病。",
            "severity": "moderate",
            "chemical": [
                PreventionItem(method_zh="70%甲基托布津可湿性粉剂800倍液", method_lo="", details_zh="每7天喷1次", details_lo=""),
            ],
            "biological": [
                PreventionItem(method_zh="及时摘除病果", method_lo="", details_zh="减少田间菌源", details_lo=""),
            ],
            "cultivation": [],
        },
        {
            "disease_name_zh": "黄瓜霜霉病",
            "disease_name_lo": "ພະຍາດຂີ້ຝຸ່ນໝາກແຕງ",
            "scientific_name": "Pseudoperonospora cubensis",
            "type": "disease",
            "symptoms_zh": "叶片出现多角形黄色斑点，叶背有紫灰色霉层，严重时叶片枯焦。",
            "symptoms_lo": "ໃບມີຈຸດສີເຫຼືອງ, ໃຕ້ໃບມີເຊື້ອສີມ່ວງ.",
            "conditions_zh": "温度16-22°C，湿度>90%时严重。",
            "severity": "moderate",
            "chemical": [],
            "biological": [],
            "cultivation": [],
        },
    ],
    "fruit": [
        {
            "disease_name_zh": "芒果炭疽病",
            "disease_name_lo": "ພະຍາດແອນແທຣກໂນສໝາກມ່ວງ",
            "scientific_name": "Colletotrichum gloeosporioides",
            "type": "disease",
            "symptoms_zh": "叶片出现不规则形褐色斑点，果实出现黑色凹陷病斑，严重时果实腐烂。",
            "symptoms_lo": "ໃບມີຈຸດສີນ້ຳຕານ, ໝາກມີຈຸດດຳ, ເມື່ອເປັນຫຼາຍໝາກຈະເນົ່າ.",
            "conditions_zh": "温度25-30°C，多雨高湿时严重。",
            "severity": "severe",
            "chemical": [
                PreventionItem(method_zh="25%咪鲜胺乳油1000倍液", method_lo="", details_zh="开花期和幼果期各喷1次", details_lo=""),
                PreventionItem(method_zh="50%多菌灵可湿性粉剂500倍液", method_lo="", details_zh="采收前14天停用", details_lo=""),
            ],
            "biological": [
                PreventionItem(method_zh="修剪病枝", method_lo="", details_zh="冬季清园，剪除病枝病叶", details_lo=""),
            ],
            "cultivation": [
                PreventionItem(method_zh="合理修剪，保持通风透光", method_lo="", details_zh="", details_lo=""),
            ],
        },
        {
            "disease_name_zh": "香蕉叶斑病",
            "disease_name_lo": "ພະຍາດຈຸດໃບກ້ວຍ",
            "scientific_name": "Mycosphaerella fijiensis",
            "type": "disease",
            "symptoms_zh": "叶片出现褐色条斑，逐渐扩展融合，严重时叶片大面积枯死。",
            "symptoms_lo": "ໃບມີຈຸດສີນ້ຳຕານ, ຂະຫຍາຍໄປເລື້ອຍໆ.",
            "conditions_zh": "高温高湿，25-32°C，雨季高发。",
            "severity": "severe",
            "chemical": [
                PreventionItem(method_zh="25%丙环唑乳油1500倍液", method_lo="", details_zh="每10-14天喷1次", details_lo=""),
            ],
            "biological": [],
            "cultivation": [
                PreventionItem(method_zh="及时摘除病叶", method_lo="", details_zh="减少菌源传播", details_lo=""),
            ],
        },
    ],
}

MOCK_CHAT_REPLIES = {
    "zh": {
        "白菜": "白菜（学名: Brassica rapa pekinensis）是十字花科芸薹属蔬菜。老挝常见病虫害包括：黑斑病、软腐病、蚜虫等。建议轮作倒茬，避免连作。",
        "番茄": "番茄（学名: Solanum lycopersicum）是茄科番茄属蔬菜。老挝常见病害：晚疫病、早疫病、叶霉病。虫害：白粉虱、棉铃虫。高温高湿季节注意防治。",
        "辣椒": "辣椒常见病害有炭疽病、疫病、青枯病。老挝种植辣椒要注意排水防涝，避免连作。",
    },
    "lo": {
        "ຜັກກາດ": "ຜັກກາດແມ່ນພືດຜັກທີ່ສຳຄັນ. ພະຍາດທີ່ພົບເລື້ອຍ: ພະຍາດຈຸດດຳ, ພະຍາດເນົ່າ. ຄວນປູກພືດໝູນວຽນ.",
        "ໝາກເລັ່ນ": "ໝາກເລັ່ນເປັນພືດຜັກທີ່ນິຍົມ. ພະຍາດສຳຄັນ: ພະຍາດໃບໄໝ້. ຄວນຫຼີກລ່ຽງການປູກໃນລະດູຝົນ.",
    },
}


class MockAIProvider(AIProvider):
    """
    Mock AI Provider — 开发测试用，不消耗API费用

    随机返回预设的病虫害数据，用于验证业务链路。
    """

    @property
    def provider_name(self) -> str:
        return "mock"

    async def identify_disease(
        self,
        image_bytes: bytes,
        crop_info: Optional[dict] = None,
        language: str = "zh",
        version: str = "vegetable",
    ) -> List:
        """模拟识别: 随机返回一个病虫害"""
        time.sleep(0.5)  # 模拟网络延迟

        diseases = MOCK_DISEASES.get(version, MOCK_DISEASES["vegetable"])
        disease = random.choice(diseases)
        confidence = random.uniform(0.82, 0.97)

        plan = PreventionPlan(
            chemical=disease.get("chemical", []),
            biological=disease.get("biological", []),
            physical=disease.get("physical", []),
            cultivation=disease.get("cultivation", []),
        )

        result = DiagnosisResult(
            disease_name_zh=disease["disease_name_zh"],
            disease_name_lo=disease.get("disease_name_lo", ""),
            scientific_name=disease.get("scientific_name", ""),
            disease_type=disease.get("type", "disease"),
            confidence=confidence,
            confidence_level=self._classify_confidence(confidence),
            symptoms_text_zh=disease.get("symptoms_zh", ""),
            symptoms_text_lo=disease.get("symptoms_lo", ""),
            conditions_zh=disease.get("conditions_zh", ""),
            severity=disease.get("severity", "moderate"),
            prevention_plan=plan,
            need_expert_review=confidence < 0.90,
            provider_name="mock",
            parse_method="mock_preset",
            processing_time_ms=int(500 + random.uniform(0, 300)),
        )

        # 有时提供备选结果
        if confidence < 0.88 and len(diseases) > 1:
            alt_disease = random.choice([d for d in diseases if d != disease])
            alt_result = DiagnosisResult(
                disease_name_zh=alt_disease["disease_name_zh"],
                disease_name_lo=alt_disease.get("disease_name_lo", ""),
                disease_type=alt_disease.get("type", "disease"),
                confidence=random.uniform(0.5, 0.7),
                confidence_level=ConfidenceLevel.LOW,
                provider_name="mock",
                parse_method="mock_preset",
            )
            result.alternative_results = [alt_result]

        return [result]

    async def chat(
        self,
        message: str,
        history: List[ChatMessage],
        language: str = "zh",
        version: str = "vegetable",
    ) -> str:
        """模拟AI对话: 关键词匹配"""
        time.sleep(0.3)

        replies = MOCK_CHAT_REPLIES.get(language, MOCK_CHAT_REPLIES["zh"])

        for keyword, reply in replies.items():
            if keyword in message:
                return reply

        if language == "lo":
            return "ຂໍອະໄພ, ຂ້ອຍຍັງບໍ່ມີຂໍ້ມູນພຽງພໍ. ກະລຸນາຖ່າຍຮູບໃບພືດເພື່ອກວດສອບ."
        return "请提供更多信息（作物名称、症状描述），或直接拍照识别病虫害。"

    async def generate_prevention_plan(
        self,
        disease_info: dict,
        language: str = "zh",
    ) -> dict:
        """模拟防控方案"""
        return {
            "chemical": [{"name": "50%多菌灵可湿性粉剂", "usage": "500倍液，每7天喷1次"}],
            "biological": [{"name": "轮作倒茬", "usage": "与非同类作物轮作2-3年"}],
            "physical": [{"name": "清除病残体", "usage": "及时清除并深埋"}],
            "cultivation": [{"name": "合理密植", "usage": "保持通风透光"}],
        }

    @staticmethod
    def _classify_confidence(confidence: float) -> ConfidenceLevel:
        if confidence >= 0.90:
            return ConfidenceLevel.HIGH
        elif confidence >= 0.70:
            return ConfidenceLevel.MEDIUM
        return ConfidenceLevel.LOW
