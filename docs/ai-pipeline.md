# AI处理管线设计文档

> 版本: v2.0 | 日期: 2026-08-08 | 阶段: 1.5 产品深化设计

---

## 1. 总体AI管线架构

```
┌─────────────────────────────────────────────────────────┐
│                     AI 处理管线                           │
│                                                          │
│  用户拍照                                                │
│     │                                                    │
│     ▼                                                    │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 阶段1: 图片预处理 (Flutter端)                      │   │
│  │ - 压缩 (原图→800px, ≤300KB)                       │   │
│  │ - 裁剪/旋转校正                                    │   │
│  │ - 质量检测 (模糊检测提示重拍)                       │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │ HTTPS multipart                 │
│                         ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 阶段2: 后端接收与校验 (Spring Boot / FastAPI)     │   │
│  │ - 文件类型校验 (jpg/png/webp)                     │   │
│  │ - 大小限制 (≤10MB)                                │   │
│  │ - 病毒扫描 (可选)                                  │   │
│  │ - 文件暂存 → 返回file_id                          │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │                                │
│                         ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 阶段3: 构建AI请求上下文                            │   │
│  │ - 加载作物信息 (如果用户指定了作物)                 │   │
│  │ - 加载该作物的常见病虫害列表 (缩小范围)             │   │
│  │ - 构建语言提示词 (zh/lo)                           │   │
│  │ - 组装System Prompt + User Prompt                  │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │                                │
│                         ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 阶段4: 调用AI Provider (抽象层)                    │   │
│  │ AIProvider.identify_disease(image, context)       │   │
│  │ → OpenAI / Claude / Gemini / Custom               │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │ 原始响应 (JSON/文本)            │
│                         ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 阶段5: AI结果解析层 ⭐ 新增核心层                 │   │
│  │ AIResponseParser.parse(raw_response)              │   │
│  │ → 标准化为 RecognitionResult                      │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │                                │
│                         ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 阶段6: 本地病虫害库匹配                            │   │
│  │ - 用标准化的病虫害名称查询本地数据库                │   │
│  │ - 匹配到 → 返回详细防控方案                        │   │
│  │ - 未匹配 → 用AI生成防控方案 + 标记待人工审核       │   │
│  └──────────────────────┬───────────────────────────┘   │
│                         │                                │
│                         ▼                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │ 阶段7: 组装响应 → 返回APP                          │   │
│  │ {                                                 │   │
│  │   disease_name, confidence, images,               │   │
│  │   symptoms, prevention_plan,                      │   │
│  │   similar_cases, data_collected: true             │   │
│  │ }                                                 │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 2. 阶段3: AI请求上下文构建（关键设计）

### 2.1 System Prompt 模板

```python
SYSTEM_PROMPT_VEGETABLE = """
你是一位拥有20年经验的蔬菜病虫害诊断专家，专门服务老挝农业场景。

你的任务：
1. 根据上传的植物图片，识别病虫害类型
2. 给出置信度评分(0-1)
3. 描述典型症状
4. 给出防控建议

输出格式（严格遵守，只返回JSON）：
{
  "results": [
    {
      "rank": 1,
      "disease_name_zh": "病害中文名",
      "disease_name_lo": "ຊື່ພະຍາດເປັນພາສາລາວ",
      "scientific_name": "病原菌学名",
      "type": "disease",
      "confidence": 0.92,
      "symptoms_zh": "症状描述...",
      "symptoms_lo": "ອາການ...",
      "severity": "severe",
      "prevention_plan": {
        "chemical_zh": ["农药名+浓度+用法"],
        "chemical_lo": ["ຢາ..."],
        "biological_zh": ["生物防治措施"],
        "biological_lo": ["..."],
        "cultivation_zh": ["栽培管理建议"],
        "cultivation_lo": ["..."]
      }
    }
  ]
}

注意事项：
- 如果图片不清晰或无法识别，请指明"图片质量不足，建议重新拍摄"
- 如果识别的是健康植株，请直接说明
- 老挝语翻译请使用标准老挝语术语
- 置信度低于60%时，请在notes中注明"建议人工确认"
"""

# 果树版用不同的System Prompt
SYSTEM_PROMPT_FRUIT = SYSTEM_PROMPT_VEGETABLE.replace(
    "蔬菜病虫害诊断专家",
    "果树病虫害诊断专家"
)
```

### 2.2 User Prompt 构建

```python
def build_user_prompt(
    crop_name: str | None = None,
    crop_category: str | None = None,
    language: str = "zh",
    common_diseases: list[str] | None = None,
) -> str:
    """构建用户提示词"""
    parts = []
    
    if language == "zh":
        parts.append("请用中文回复。")
    else:
        parts.append("请用老挝语回复。(ກະລຸນາຕອບເປັນພາສາລາວ)")
    
    if crop_name:
        parts.append(f"这种作物是：{crop_name}")
    
    if common_diseases:
        parts.append(f"该作物常见病虫害包括：{', '.join(common_diseases)}。请优先考虑这些可能性。")
    
    parts.append("请识别图片中的病虫害。")
    
    return "\n".join(parts)
```

---

## 3. 阶段5: AI结果解析层 ⭐ 核心新增

### 3.1 设计原理

```
不同AI模型返回格式差异巨大：
  OpenAI:    结构化JSON (通常)
  Claude:    可能JSON，可能自然语言+JSON混合
  Gemini:    JSON
  国内模型:   格式不统一

→ AIResponseParser 解决此问题
```

### 3.2 解析器架构

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import List, Optional
import json
import re


@dataclass
class StandardizedResult:
    """标准化识别结果 — 所有Provider解析后统一为此格式"""
    rank: int
    disease_name_zh: str
    disease_name_lo: str
    scientific_name: str = ""
    type: str = "disease"  # disease | pest | healthy
    confidence: float = 0.0
    symptoms_zh: str = ""
    symptoms_lo: str = ""
    severity: str = "moderate"  # mild | moderate | severe
    prevention_plan: dict | None = None
    raw_response: str = ""  # 保留原始响应用于调试
    parse_method: str = ""  # 记录使用了哪种解析方法
    needs_review: bool = False  # 是否需要人工审核


class AIResponseParser(ABC):
    """AI响应解析器 — 每个Provider对应一个Parser"""
    
    @abstractmethod
    async def parse(self, raw_response: str, language: str = "zh") -> List[StandardizedResult]:
        """
        将AI原始响应解析为标准化结果列表。
        
        Args:
            raw_response: AI返回的原始文本
            language: 目标语言
            
        Returns:
            标准化的识别结果列表
        """
        pass
    
    def extract_json(self, text: str) -> dict | None:
        """从文本中提取JSON (通用方法)"""
        # 尝试1: 直接解析
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            pass
        
        # 尝试2: 提取 ```json ... ``` 代码块
        match = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(1))
            except json.JSONDecodeError:
                pass
        
        # 尝试3: 提取 { ... } 最外层JSON
        match = re.search(r'\{.*\}', text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError:
                pass
        
        return None
    
    def fallback_parse(self, text: str) -> List[StandardizedResult]:
        """
        兜底解析: 当JSON提取失败时，从自然语言中提取信息。
        这是最后的手段 — 标记 needs_review=True
        """
        results = []
        
        # 简单关键词匹配
        disease_keywords = ["病", "虫", "害", "disease", "pest", "blight", "spot"]
        confidence_pattern = r'(\d{1,3})%'
        
        # 尝试提取病虫害名称和置信度
        conf_match = re.search(confidence_pattern, text)
        confidence = float(conf_match.group(1)) / 100 if conf_match else 0.5
        
        results.append(StandardizedResult(
            rank=1,
            disease_name_zh=text[:100],  # 截取前100字符作为名称
            disease_name_lo="",
            confidence=confidence,
            type="disease",
            raw_response=text,
            parse_method="fallback",
            needs_review=True,  # 兜底解析需要人工审核
        ))
        
        return results


class OpenAIResponseParser(AIResponseParser):
    """OpenAI响应解析器 — JSON优先"""
    
    async def parse(self, raw_response: str, language: str = "zh") -> List[StandardizedResult]:
        results = []
        parse_method = "json_direct"
        
        data = self.extract_json(raw_response)
        
        if data and "results" in data:
            for item in data["results"]:
                results.append(StandardizedResult(
                    rank=item.get("rank", len(results) + 1),
                    disease_name_zh=item.get("disease_name_zh", ""),
                    disease_name_lo=item.get("disease_name_lo", ""),
                    scientific_name=item.get("scientific_name", ""),
                    type=item.get("type", "disease"),
                    confidence=item.get("confidence", 0.0),
                    symptoms_zh=item.get("symptoms_zh", ""),
                    symptoms_lo=item.get("symptoms_lo", ""),
                    severity=item.get("severity", "moderate"),
                    prevention_plan=item.get("prevention_plan"),
                    raw_response=raw_response,
                    parse_method=parse_method,
                ))
        else:
            # JSON解析失败，使用兜底
            results = self.fallback_parse(raw_response)
        
        return results


class ClaudeResponseParser(AIResponseParser):
    """Claude响应解析器 — 处理可能的自然语言+JSON混合"""
    
    async def parse(self, raw_response: str, language: str = "zh") -> List[StandardizedResult]:
        # Claude可能返回自然语言包裹的JSON
        # 先用OpenAI的方法尝试JSON提取
        data = self.extract_json(raw_response)
        
        if data and "results" in data:
            parser = OpenAIResponseParser()
            return await parser.parse(raw_response, language)
        
        # Claude特有的解析逻辑...
        return self.fallback_parse(raw_response)


# 解析器工厂
PARSER_MAP = {
    "openai": OpenAIResponseParser,
    "claude": ClaudeResponseParser,
    "gemini": OpenAIResponseParser,  # Gemini格式类似OpenAI
    "custom": OpenAIResponseParser,  # 国内模型尽量要求JSON输出
}


def get_parser(provider_name: str) -> AIResponseParser:
    parser_class = PARSER_MAP.get(provider_name.lower(), OpenAIResponseParser)
    return parser_class()
```

---

## 4. 阶段6: 本地病虫害库匹配流程

```python
async def match_local_disease_db(
    results: List[StandardizedResult],
    version: str,  # 'vegetable' | 'fruit'
    db_session,
) -> List[StandardizedResult]:
    """
    将AI识别结果与本地病虫害数据库匹配，
    补充详细的防控方案和参考图片。
    """
    enriched_results = []
    
    for result in results:
        # 用病虫害名称模糊匹配本地数据库
        local_match = await db_session.execute(
            select(Disease).where(
                Disease.version == version,
                or_(
                    Disease.name_zh.ilike(f"%{result.disease_name_zh}%"),
                    Disease.name_lo.ilike(f"%{result.disease_name_lo}%"),
                )
            ).limit(1)
        )
        disease = local_match.scalar_one_or_none()
        
        if disease:
            # 匹配成功: 使用本地数据库的详细数据
            result.disease_name_zh = disease.name_zh
            result.disease_name_lo = disease.name_lo
            result.symptoms_zh = disease.symptoms_zh or result.symptoms_zh
            result.symptoms_lo = disease.symptoms_lo or result.symptoms_lo
            
            # 加载防控方案
            plans = await load_prevention_plans(disease.id, db_session)
            if plans:
                result.prevention_plan = plans
        else:
            # 未匹配: 标记需要人工审核 + 触发数据入库流程
            result.needs_review = True
        
        enriched_results.append(result)
    
    return enriched_results
```

---

## 5. 防控方案生成流程

```
识别结果 → 判断是否有本地防控方案
    │
    ├──→ 有本地方案: 直接返回 (数据库prevention_plan表)
    │
    └──→ 无本地方案: 调用AI生成
            │
            ├──→ AIProvider.generate_prevention_plan(disease_info)
            │       │
            │       └──→ AIResponseParser 标准化
            │               │
            │               ├──→ 返回给用户
            │               └──→ 标记 needs_review → 人工审核后入库
```

---

## 6. 错误处理与降级策略

```
AI调用失败处理:
  第1次失败 → 重试 (最多3次, 指数退避)
  第2次失败 → 切换备用Provider (如果配置了)
  第3次失败 → 返回离线知识库中匹配度最高的结果
                + 提示"AI服务暂时不可用, 以上为离线匹配结果"

超时处理:
  识别超时(15秒) → 返回"处理中" → 后台继续 → 通知用户
  对话超时(10秒) → 返回"正在思考..." → 流式返回
```

---

> **下一步: data-asset-design.md**
