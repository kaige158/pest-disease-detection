# API接口设计草案

> 版本: v1.0 | 基础路径: `/api/v1` | 协议: HTTPS

---

## 1. 接口总览

| 模块 | 方法 | 路径 | 说明 |
|------|------|------|------|
| **识别** | POST | `/recognition/identify` | 上传图片进行病虫害识别 |
| **识别** | GET | `/recognition/result/{task_id}` | 查询识别结果 |
| **识别** | GET | `/recognition/history` | 历史识别记录 |
| **知识库** | GET | `/knowledge/crops` | 作物分类列表 |
| **知识库** | GET | `/knowledge/crops/{id}/diseases` | 某作物下的病虫害列表 |
| **知识库** | GET | `/knowledge/diseases/{id}` | 病虫害详情 |
| **知识库** | GET | `/knowledge/search` | 知识库搜索 |
| **AI助手** | POST | `/assistant/chat` | 发送消息，获取AI回复 |
| **AI助手** | GET | `/assistant/history` | 对话历史 |
| **防控方案** | GET | `/prevention/{disease_id}` | 获取指定病虫害防控方案 |
| **系统** | GET | `/system/health` | 健康检查 |
| **系统** | GET | `/system/config` | 客户端配置（语言列表等） |

---

## 2. 接口详细设计

### 2.1 病虫害识别

```
POST /api/v1/recognition/identify
```

**请求：**
```
Content-Type: multipart/form-data

参数:
  image       : File (必填) — 图片文件(jpg/png/webp, ≤10MB)
  crop_id     : int  (可选) — 已知作物ID，缩小识别范围
  language    : str  (必填) — "zh" | "lo"
  version     : str  (必填) — "vegetable" | "fruit"
```

**响应 (200):**
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "task_id": "rec_20260808_001",
    "status": "completed",
    "results": [
      {
        "rank": 1,
        "disease_name_zh": "番茄晚疫病",
        "disease_name_lo": "ພະຍາດໃບໄໝ້ໝາກເລັ່ນ",
        "confidence": 0.92,
        "type": "disease",
        "severity": "severe",
        "description_zh": "由致病疫霉菌引起的真菌性病害...",
        "description_lo": "ເກີດຈາກເຊື້ອລາ Phytophthora infestans...",
        "prevention_plan": {
          "chemical_zh": ["58%甲霜灵锰锌可湿性粉剂500倍液", "..."],
          "chemical_lo": ["..."],
          "biological_zh": ["轮作倒茬", "选用抗病品种"],
          "biological_lo": ["..."],
          "tips_zh": "发现中心病株应立即拔除，深埋或烧毁",
          "tips_lo": "..."
        }
      },
      {
        "rank": 2,
        "disease_name_zh": "番茄早疫病",
        "disease_name_lo": "...",
        "confidence": 0.67,
        ...
      }
    ],
    "image_url": "https://api.xxx.com/uploads/rec_20260808_001.jpg",
    "created_at": "2026-08-08T10:30:00Z"
  }
}
```

**错误响应 (400/413/500):**
```json
{
  "code": 400,
  "message": "图片格式不支持，仅支持 jpg/png/webp",
  "data": null
}
```

---

### 2.2 知识库 — 作物列表

```
GET /api/v1/knowledge/crops?version=vegetable&language=zh&page=1&page_size=20
```

**响应 (200):**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": 1,
        "name_zh": "番茄",
        "name_lo": "ໝາກເລັ່ນ",
        "category": "茄果类",
        "icon_url": "https://api.xxx.com/icons/tomato.png",
        "disease_count": 12
      },
      {
        "id": 2,
        "name_zh": "白菜",
        "name_lo": "ຜັກກາດຂາວ",
        "category": "叶菜类",
        "icon_url": "https://api.xxx.com/icons/cabbage.png",
        "disease_count": 8
      }
    ],
    "total": 35,
    "page": 1,
    "page_size": 20
  }
}
```

---

### 2.3 知识库 — 病虫害详情

```
GET /api/v1/knowledge/diseases/{id}?language=zh
```

**响应 (200):**
```json
{
  "code": 200,
  "data": {
    "id": 101,
    "name_zh": "番茄晚疫病",
    "name_lo": "ພະຍາດໃບໄໝ້ໝາກເລັ່ນ",
    "scientific_name": "Phytophthora infestans",
    "type": "disease",
    "crop_id": 1,
    "crop_name_zh": "番茄",
    "crop_name_lo": "ໝາກເລັ່ນ",
    "symptoms_zh": "叶片出现水渍状斑点，湿度大时叶背有白色霉层...",
    "symptoms_lo": "...",
    "conditions_zh": "温度18-22℃，相对湿度>95%时易发病",
    "conditions_lo": "...",
    "images": [
      "https://api.xxx.com/diseases/tomato_late_blight_1.jpg",
      "https://api.xxx.com/diseases/tomato_late_blight_2.jpg"
    ],
    "prevention_plan": {
      "chemical": [...],
      "biological": [...],
      "physical": [...],
      "tips": "..."
    }
  }
}
```

---

### 2.4 知识库 — 搜索

```
GET /api/v1/knowledge/search?q=晚疫&version=vegetable&language=zh&page=1&page_size=20
```

**说明：** 全文检索，同时搜索病虫害名称、症状描述、作物名等字段。

**响应：** 同列表格式，返回匹配的病虫害条目。

---

### 2.5 AI助手 — 对话

```
POST /api/v1/assistant/chat
```

**请求：**
```json
{
  "message": "白菜上有黑色的斑点是什么病？",
  "language": "zh",
  "version": "vegetable",
  "session_id": "sess_abc123",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ]
}
```

**响应 (200):**
```json
{
  "code": 200,
  "data": {
    "reply": "白菜上出现黑色斑点，很可能是黑斑病（Alternaria brassicae）。主要症状：叶片上出现圆形或不规则形黑褐色斑点，严重时斑点连片导致叶片枯死。建议：1. 轮作倒茬 2. 发病初期喷洒50%多菌灵可湿性粉剂500倍液 3. 清除田间病残体",
    "session_id": "sess_abc123",
    "related_diseases": [
      {"id": 201, "name_zh": "白菜黑斑病", "confidence": 0.85}
    ]
  }
}
```

**错误响应 (429 — 限流):**
```json
{
  "code": 429,
  "message": "请求过于频繁，请稍后再试",
  "retry_after": 30
}
```

---

### 2.6 防控方案 — 独立查询

```
GET /api/v1/prevention/{disease_id}?language=zh
```

**响应 (200):**
```json
{
  "code": 200,
  "data": {
    "disease_id": 101,
    "disease_name_zh": "番茄晚疫病",
    "disease_name_lo": "...",
    "plans": {
      "chemical": {
        "title_zh": "化学防治",
        "title_lo": "...",
        "items": [
          {"name_zh": "58%甲霜灵锰锌可湿性粉剂500倍液", "name_lo": "...", "usage_zh": "每7天喷1次，连喷2-3次", "usage_lo": "..."}
        ]
      },
      "biological": {
        "title_zh": "生物防治",
        "title_lo": "...",
        "items": [...]
      },
      "physical": {
        "title_zh": "物理防治",
        "title_lo": "...",
        "items": [...]
      },
      "cultivation": {
        "title_zh": "栽培管理",
        "title_lo": "...",
        "items": [...]
      }
    }
  }
}
```

---

## 3. 通用规范

### 3.1 响应格式

所有API统一使用以下响应格式：

```json
{
  "code": 200,
  "message": "success",
  "data": { ... }  // 或 [...] 或 null
}
```

### 3.2 HTTP状态码

| 状态码 | 说明 |
|--------|------|
| 200 | 成功 |
| 400 | 请求参数错误 |
| 401 | 未认证（如启用用户系统） |
| 404 | 资源不存在 |
| 413 | 上传文件过大 |
| 429 | 请求频率超限 |
| 500 | 服务器内部错误 |
| 502 | AI Provider调用失败 |

### 3.3 认证

- 初期：无认证（App为公开使用）
- 后期可选：JWT Token，用于用户收藏/历史记录
- 管理后台（数据导入）：Basic Auth + IP白名单

### 3.4 分页

```
page      : int  (默认1)
page_size : int  (默认20, 最大100)

响应中返回:
{
  "items": [...],
  "total": 150,
  "page": 1,
  "page_size": 20
}
```

### 3.5 多语言参数

所有返回文本内容的接口都接受 `language` 参数：
- `zh` — 中文
- `lo` — 老挝语

响应中的文本字段按 `_zh` / `_lo` 后缀区分，客户端根据当前语言选择展示。

---

## 4. 接口优先级

| 优先级 | 接口 | 原因 |
|--------|------|------|
| P0 | 识别接口 | 核心MVP功能 |
| P0 | 知识库列表/详情 | 核心内容展示 |
| P1 | AI助手对话 | 核心AI功能 |
| P1 | 知识库搜索 | 用户体验关键 |
| P2 | 防控方案独立查询 | 可先内嵌在识别结果中 |
| P3 | 历史记录/收藏 | 增值功能 |
