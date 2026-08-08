"""农业诊断Agent — 引导式问答流程

不是聊天框！而是逐步引导用户提供信息，最终给出诊断建议。

流程:
1. 选择/输入作物
2. 选择症状类型(叶片/果实/茎秆/根部)
3. 回答追问(颜色/形状/范围)
4. 综合判断 → 给出诊断结果
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional


class QuestionType(str, Enum):
    CROP_SELECT = "crop_select"         # 选择作物
    SYMPTOM_AREA = "symptom_area"       # 异常部位
    SYMPTOM_TYPE = "symptom_type"       # 症状类型
    COLOR = "color"                     # 颜色
    SPREAD = "spread"                   # 范围
    TIMING = "timing"                   # 发病时间
    ENVIRONMENT = "environment"         # 环境条件
    DIAGNOSIS = "diagnosis"             # 最终诊断


@dataclass
class Question:
    """诊断Agent提出的问题"""
    question_type: QuestionType
    text_zh: str
    text_lo: str
    options: List[dict] = field(default_factory=list)  # [{value, label_zh, label_lo}]
    multi_select: bool = False
    allow_free_text: bool = False
    image_help: bool = False  # 是否建议用户拍照


@dataclass
class DiagnosisSession:
    """诊断会话"""
    session_id: str
    step: int = 0
    answers: dict = field(default_factory=dict)
    completed: bool = False

    def add_answer(self, key: str, value: str):
        self.answers[key] = value
        self.step += 1


class DiagnosisAgent:
    """
    农业诊断Agent — 逐步引导用户完成病虫害诊断

    设计原则:
    - 每步一个问题，不给用户信息过载
    - 选项化，降低老挝农户输入门槛
    - 支持随时拍照
    - 最终给出综合诊断 + 防控建议
    """

    def __init__(self, version: str = "vegetable", language: str = "zh"):
        self.version = version
        self.language = language

    def get_next_question(self, session: DiagnosisSession) -> Optional[Question]:
        """根据当前会话状态，返回下一个问题"""
        step = session.step
        answers = session.answers

        if step == 0:
            return self._ask_crop()

        if step == 1:
            self._enrich_crop_info(answers)
            return self._ask_symptom_area()

        if step == 2:
            return self._ask_symptom_type(answers)

        if step == 3:
            symptom_type = answers.get("symptom_type", "")
            if symptom_type == "spots":
                return self._ask_color(answers)
            elif symptom_type == "holes":
                return self._ask_spread(answers)
            elif symptom_type == "wilt":
                return self._ask_timing(answers)
            else:
                return self._ask_environment()

        if step == 4:
            prev_q = self.get_next_question_for_step(session)  # 根据上一步动态决定
            if prev_q:
                return prev_q

        if step == 5:
            return self._ask_environment()

        if step >= 6:
            return self._render_diagnosis(session)

        return None

    def get_next_question_for_step(self, session: DiagnosisSession) -> Optional[Question]:
        step = session.step
        answers = session.answers

        if step == 4:
            symptom_type = answers.get("symptom_type", "")
            symptom_area = answers.get("symptom_area", "")

            if symptom_type == "spots" and "leaf" in symptom_area:
                return self._ask_spread(answers)
            elif symptom_type in ("holes", "rot", "mold"):
                return self._ask_environment()
            elif symptom_type in ("wilt", "yellow"):
                return self._ask_timing(answers)
            else:
                return self._ask_environment()

        return None

    def _ask_crop(self) -> Question:
        crops = {
            "vegetable": [
                {"value": "tomato", "label_zh": "番茄", "label_lo": "ໝາກເລັ່ນ"},
                {"value": "cabbage", "label_zh": "白菜", "label_lo": "ຜັກກາດຂາວ"},
                {"value": "pepper", "label_zh": "辣椒", "label_lo": "ໝາກເຜັດ"},
                {"value": "cucumber", "label_zh": "黄瓜", "label_lo": "ໝາກແຕງ"},
                {"value": "eggplant", "label_zh": "茄子", "label_lo": "ໝາກເຂືອ"},
                {"value": "lettuce", "label_zh": "生菜", "label_lo": "ຜັກສະຫຼັດ"},
            ],
            "fruit": [
                {"value": "mango", "label_zh": "芒果", "label_lo": "ໝາກມ່ວງ"},
                {"value": "banana", "label_zh": "香蕉", "label_lo": "ກ້ວຍ"},
                {"value": "lychee", "label_zh": "荔枝", "label_lo": "ໝາກລິ້ນຈີ່"},
                {"value": "citrus", "label_zh": "柑橘", "label_lo": "ໝາກກ້ຽງ"},
            ],
        }
        return Question(
            question_type=QuestionType.CROP_SELECT,
            text_zh="请问是什么作物？",
            text_lo="ມັນແມ່ນພືດຫຍັງ?",
            options=crops.get(self.version, crops["vegetable"]),
            multi_select=False,
        )

    def _enrich_crop_info(self, answers: dict):
        """补充作物信息到答案"""
        crop = answers.get("crop", "")
        crop_names = {
            "tomato": ("番茄", "ໝາກເລັ່ນ"),
            "cabbage": ("白菜", "ຜັກກາດຂາວ"),
            "pepper": ("辣椒", "ໝາກເຜັດ"),
            "cucumber": ("黄瓜", "ໝາກແຕງ"),
            "mango": ("芒果", "ໝາກມ່ວງ"),
            "banana": ("香蕉", "ກ້ວຍ"),
        }
        info = crop_names.get(crop, (crop, crop))
        answers["crop_name_zh"] = info[0]
        answers["crop_name_lo"] = info[1]

    def _ask_symptom_area(self) -> Question:
        return Question(
            question_type=QuestionType.SYMPTOM_AREA,
            text_zh="哪个部位出现了异常？",
            text_lo="ສ່ວນໃດມີບັນຫາ?",
            options=[
                {"value": "leaf", "label_zh": "叶片", "label_lo": "ໃບ"},
                {"value": "fruit", "label_zh": "果实", "label_lo": "ໝາກ"},
                {"value": "stem", "label_zh": "茎秆", "label_lo": "ລຳຕົ້ນ"},
                {"value": "root", "label_zh": "根部", "label_lo": "ຮາກ"},
                {"value": "whole", "label_zh": "整株", "label_lo": "ທັງຕົ້ນ"},
            ],
            image_help=True,
        )

    def _ask_symptom_type(self, answers: dict) -> Question:
        area = answers.get("symptom_area", "")
        if area == "leaf":
            return Question(
                question_type=QuestionType.SYMPTOM_TYPE,
                text_zh="叶片上出现了什么问题？",
                text_lo="ໃບມີບັນຫາຫຍັງ?",
                options=[
                    {"value": "spots", "label_zh": "有斑点/斑块", "label_lo": "ມີຈຸດ"},
                    {"value": "yellow", "label_zh": "发黄", "label_lo": "ສີເຫຼືອງ"},
                    {"value": "holes", "label_zh": "有虫洞", "label_lo": "ມີຮູ"},
                    {"value": "mold", "label_zh": "有霉层/粉末", "label_lo": "ມີເຊື້ອ"},
                    {"value": "wilt", "label_zh": "枯萎/卷曲", "label_lo": "ຫ່ຽວ"},
                ],
            )
        elif area == "fruit":
            return Question(
                question_type=QuestionType.SYMPTOM_TYPE,
                text_zh="果实上出现了什么问题？",
                text_lo="ໝາກມີບັນຫາຫຍັງ?",
                options=[
                    {"value": "spots", "label_zh": "有斑点/病斑", "label_lo": "ມີຈຸດ"},
                    {"value": "rot", "label_zh": "腐烂", "label_lo": "ເນົ່າ"},
                    {"value": "deform", "label_zh": "畸形", "label_lo": "ຜິດປົກກະຕິ"},
                    {"value": "fall", "label_zh": "落果", "label_lo": "ໝາກຫຼົ່ນ"},
                ],
            )
        else:
            return Question(
                question_type=QuestionType.SYMPTOM_TYPE,
                text_zh="出现了什么问题？",
                text_lo="ມີບັນຫາຫຍັງ?",
                options=[
                    {"value": "spots", "label_zh": "变色/斑点", "label_lo": "ມີຈຸດ"},
                    {"value": "rot", "label_zh": "腐烂", "label_lo": "ເນົ່າ"},
                    {"value": "wilt", "label_zh": "萎蔫", "label_lo": "ຫ່ຽວ"},
                    {"value": "growth", "label_zh": "生长异常", "label_lo": "ການເຕີບໂຕຜິດປົກກະຕິ"},
                ],
            )

    def _ask_color(self, answers: dict) -> Question:
        return Question(
            question_type=QuestionType.COLOR,
            text_zh="斑点是什么颜色？",
            text_lo="ຈຸດມີສີຫຍັງ?",
            options=[
                {"value": "brown", "label_zh": "褐色", "label_lo": "ສີນ້ຳຕານ"},
                {"value": "black", "label_zh": "黑色", "label_lo": "ສີດຳ"},
                {"value": "yellow", "label_zh": "黄色", "label_lo": "ສີເຫຼືອງ"},
                {"value": "white", "label_zh": "白色", "label_lo": "ສີຂາວ"},
                {"value": "red", "label_zh": "红色", "label_lo": "ສີແດງ"},
            ],
        )

    def _ask_spread(self, answers: dict) -> Question:
        return Question(
            question_type=QuestionType.SPREAD,
            text_zh="发病范围有多大？",
            text_lo="ມັນແຜ່ຂະຫຍາຍຫຼາຍປານໃດ?",
            options=[
                {"value": "single", "label_zh": "单株/单叶", "label_lo": "ຕົ້ນດຽວ"},
                {"value": "few", "label_zh": "少数几株", "label_lo": "ຈຳນວນໜ້ອຍ"},
                {"value": "patch", "label_zh": "成片发生", "label_lo": "ເປັນກຸ່ມ"},
                {"value": "wide", "label_zh": "大面积", "label_lo": "ກວ້າງຂວາງ"},
            ],
        )

    def _ask_timing(self, answers: dict) -> Question:
        return Question(
            question_type=QuestionType.TIMING,
            text_zh="什么时候开始出现的？",
            text_lo="ເລີ່ມເປັນຕອນໃດ?",
            options=[
                {"value": "recent", "label_zh": "最近2-3天", "label_lo": "2-3 ມື້ຜ່ານມາ"},
                {"value": "week", "label_zh": "一周左右", "label_lo": "ປະມານ 1 ອາທິດ"},
                {"value": "long", "label_zh": "已经很久了", "label_lo": "ດົນແລ້ວ"},
            ],
        )

    def _ask_environment(self) -> Question:
        return Question(
            question_type=QuestionType.ENVIRONMENT,
            text_zh="最近的天气和环境怎么样？",
            text_lo="ສະພາບອາກາດບໍ່ດົນມານີ້ເປັນແນວໃດ?",
            options=[
                {"value": "rainy", "label_zh": "多雨潮湿", "label_lo": "ຝົນຕົກຫຼາຍ"},
                {"value": "hot_dry", "label_zh": "高温干燥", "label_lo": "ຮ້ອນແລະແຫ້ງ"},
                {"value": "normal", "label_zh": "正常", "label_lo": "ປົກກະຕິ"},
            ],
        )

    def _render_diagnosis(self, session: DiagnosisSession) -> Question:
        """根据所有答案生成诊断建议"""
        answers = session.answers
        session.completed = True

        # 基于规则匹配可能的病虫害
        possible_diseases = self._match_diseases(answers)

        diagnosis_text_zh = self._format_diagnosis_zh(answers, possible_diseases)
        diagnosis_text_lo = self._format_diagnosis_lo(answers, possible_diseases)

        return Question(
            question_type=QuestionType.DIAGNOSIS,
            text_zh=diagnosis_text_zh,
            text_lo=diagnosis_text_lo,
            options=[{"value": d["name"], "label_zh": d["name_zh"], "label_lo": d["name_lo"],
                       "confidence": d["confidence"]} for d in possible_diseases],
        )

    def _match_diseases(self, answers: dict) -> list:
        """基于规则的简单匹配 — 根据用户回答推断可能病虫害"""
        crop = answers.get("crop", "")
        symptom_type = answers.get("symptom_type", "")
        symptom_area = answers.get("symptom_area", "")
        color = answers.get("color", "")
        spread = answers.get("spread", "")
        environment = answers.get("environment", "")

        # 规则匹配表
        rules = {
            ("tomato", "leaf", "spots", "brown"): [
                {"name": "late_blight", "name_zh": "番茄晚疫病", "name_lo": "ພະຍາດໃບໄໝ້", "confidence": 0.92},
                {"name": "early_blight", "name_zh": "番茄早疫病", "name_lo": "ພະຍາດໃບຈຸດ", "confidence": 0.75},
            ],
            ("tomato", "leaf", "spots", "black"): [
                {"name": "early_blight", "name_zh": "番茄早疫病", "name_lo": "ພະຍາດໃບຈຸດ", "confidence": 0.88},
            ],
            ("tomato", "leaf", "yellow", ""): [
                {"name": "leaf_mold", "name_zh": "番茄叶霉病", "name_lo": "ພະຍາດໃບເຫຼືອງ", "confidence": 0.82},
            ],
            ("tomato", "fruit", "spots", "brown"): [
                {"name": "late_blight", "name_zh": "番茄晚疫病(果实)", "name_lo": "ພະຍາດໃບໄໝ້ໝາກ", "confidence": 0.90},
            ],
            ("tomato", "fruit", "rot", ""): [
                {"name": "fruit_rot", "name_zh": "番茄果腐病", "name_lo": "ພະຍາດໝາກເນົ່າ", "confidence": 0.85},
            ],
            ("cabbage", "leaf", "spots", "black"): [
                {"name": "black_spot", "name_zh": "白菜黑斑病", "name_lo": "ພະຍາດຈຸດດຳ", "confidence": 0.90},
            ],
            ("cabbage", "leaf", "holes", ""): [
                {"name": "aphid", "name_zh": "蚜虫危害", "name_lo": "ເພີ້ຍ", "confidence": 0.92},
                {"name": "cabbage_worm", "name_zh": "菜青虫", "name_lo": "ແມງກະເບື້ອ", "confidence": 0.85},
            ],
            ("cabbage", "leaf", "yellow", ""): [
                {"name": "downy_mildew", "name_zh": "白菜霜霉病", "name_lo": "ພະຍາດຂີ້ຝຸ່ນ", "confidence": 0.78},
            ],
            ("pepper", "leaf", "spots", "brown"): [
                {"name": "anthracnose", "name_zh": "辣椒炭疽病", "name_lo": "ພະຍາດແອນແທຣກໂນສ", "confidence": 0.88},
            ],
            ("pepper", "fruit", "rot", ""): [
                {"name": "anthracnose_fruit", "name_zh": "辣椒炭疽病(果实)", "name_lo": "ພະຍາດແອນແທຣກໂນສໝາກ", "confidence": 0.90},
            ],
            ("cucumber", "leaf", "spots", "yellow"): [
                {"name": "downy_mildew", "name_zh": "黄瓜霜霉病", "name_lo": "ພະຍາດຂີ້ຝຸ່ນ", "confidence": 0.92},
            ],
            ("mango", "leaf", "spots", "brown"): [
                {"name": "anthracnose", "name_zh": "芒果炭疽病", "name_lo": "ພະຍາດແອນແທຣກໂນສ", "confidence": 0.90},
            ],
            ("mango", "fruit", "spots", "black"): [
                {"name": "anthracnose_fruit", "name_zh": "芒果炭疽病(果实)", "name_lo": "ພະຍາດແອນແທຣກໂນສໝາກ", "confidence": 0.92},
            ],
            ("banana", "leaf", "spots", "brown"): [
                {"name": "leaf_spot", "name_zh": "香蕉叶斑病", "name_lo": "ພະຍາດຈຸດໃບກ້ວຍ", "confidence": 0.88},
            ],
        }

        # 精确匹配
        key = (crop, symptom_area, symptom_type, color)
        if key in rules:
            return rules[key]

        # 模糊匹配 (忽略颜色)
        key2 = (crop, symptom_area, symptom_type, "")
        if key2 in rules:
            return rules[key2]

        # 最简匹配 (只看作物+症状类型)
        for k, v in rules.items():
            if k[0] == crop and k[2] == symptom_type:
                return v

        # 默认 — 建议拍照识别
        return [{
            "name": "unknown",
            "name_zh": "无法确定，建议拍照识别",
            "name_lo": "ບໍ່ສາມາດລະບຸໄດ້, ກະລຸນາຖ່າຍຮູບ",
            "confidence": 0.3,
        }]

    def _format_diagnosis_zh(self, answers: dict, possible_diseases: list) -> str:
        crop_name = answers.get("crop_name_zh", "未知作物")
        top = possible_diseases[0]
        lines = [f"📋 诊断结果: {crop_name}"]
        lines.append("")
        if top["confidence"] > 0.8:
            lines.append(f"✅ 最可能: {top['name_zh']} (匹配度 {top['confidence']*100:.0f}%)")
        elif top["confidence"] > 0.5:
            lines.append(f"⚠️ 可能是: {top['name_zh']} (匹配度 {top['confidence']*100:.0f}%)")
        else:
            lines.append(f"❓ {top['name_zh']}")

        if len(possible_diseases) > 1:
            lines.append(f"其他可能: {', '.join(d['name_zh'] for d in possible_diseases[1:3])}")

        lines.append("")
        lines.append("💡 建议: 拍照识别以获取更准确的结果")
        return "\n".join(lines)

    def _format_diagnosis_lo(self, answers: dict, possible_diseases: list) -> str:
        crop_name = answers.get("crop_name_lo", "")
        top = possible_diseases[0]
        return f"📋 ຜົນການວິນິດໄສ: {crop_name}\n\nອາດຈະເປັນ: {top['name_lo']} ({top['confidence']*100:.0f}%)\n\n💡 ແນະນຳ: ຖ່າຍຮູບເພື່ອກວດສອບທີ່ຖືກຕ້ອງ"
