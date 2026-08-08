# 数据资产设计文档

> 版本: v2.0 | 日期: 2026-08-08 | 阶段: 1.5 产品深化设计
> 核心思想: 这个项目的真正价值不只是APP，而是农业病虫害数据资产

---

## 1. 数据资产全景

```
┌─────────────────────────────────────────────────────────┐
│                  农业病虫害数据资产                        │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  基础数据     │  │  采集数据     │  │  衍生数据     │   │
│  │ (老师提供)   │  │ (APP采集)    │  │ (AI+分析)    │   │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤   │
│  │ • 作物分类   │  │ • 用户上传    │  │ • 识别统计   │   │
│  │ • 病虫害库   │  │   图片        │  │ • 分布热力图 │   │
│  │ • 防控方案   │  │ • GPS坐标     │  │ • 趋势分析   │   │
│  │ • 知识库内容 │  │ • 天气数据    │  │ • 训练数据集 │   │
│  │ • 中老双语   │  │ • 设备信息    │  │ • 模型评估   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
│                                                          │
│  未来价值:                                                │
│  → 训练专属老挝病虫害识别模型                              │
│  → 发表科研论文 (基于真实数据)                             │
│  → 申请软件著作权 + 数据集著作权                          │
│  → 为老挝农业部提供数据报告                               │
└─────────────────────────────────────────────────────────┘
```

---

## 2. 核心数据表设计（修订版）

### 2.1 disease_image（病虫害图片表）⭐ 科研核心表

> 这是数据资产的核心！每张用户上传的图片都是一条科研数据。

```sql
CREATE TABLE disease_image (
    id              BIGSERIAL PRIMARY KEY,
    
    -- === 图片基本信息 ===
    image_url       VARCHAR(500) NOT NULL,          -- 图片存储URL
    thumbnail_url   VARCHAR(500),                   -- 缩略图URL
    image_hash      VARCHAR(64),                    -- 图片SHA256哈希 (去重)
    file_size_bytes INT,                            -- 文件大小
    
    -- === 关联信息 ===
    crop_id         INT REFERENCES crop(id),        -- 作物ID
    disease_id      INT REFERENCES disease(id),     -- 病虫害ID (AI识别结果)
    recognition_record_id INT REFERENCES recognition_record(id), -- 关联识别记录
    
    -- === 图片类型 ===
    image_type      VARCHAR(30) DEFAULT 'symptom',  -- symptom/leaf/fruit/stem/root/whole
    image_source    VARCHAR(30) DEFAULT 'user',     -- user(用户上传)/expert(专家标注)/web(网络采集)
    
    -- === 拍摄信息 (科研价值) ===
    gps_latitude    DECIMAL(10,7),                  -- GPS纬度
    gps_longitude   DECIMAL(10,7),                  -- GPS经度
    location_name   VARCHAR(300),                   -- 位置描述 (省份/地区)
    taken_at        TIMESTAMP,                      -- 拍摄时间
    
    -- === 农作物生长信息 (科研价值) ===
    growth_stage    VARCHAR(50),                    -- 生长阶段: seedling/vegetative/flowering/fruiting/harvest
    plant_part      VARCHAR(50),                    -- 拍摄部位: leaf/stem/fruit/flower/root
    
    -- === 环境信息 (科研价值) ===
    weather_condition VARCHAR(50),                  -- 天气: sunny/cloudy/rainy
    temperature      DECIMAL(5,2),                  -- 温度(°C) (通过GPS+时间查天气API)
    humidity         DECIMAL(5,2),                  -- 湿度(%) 
    
    -- === 采集信息 ===
    collector_id    INT,                            -- 采集者ID (如果是技术员采集)
    collector_type  VARCHAR(30) DEFAULT 'user',     -- user/technician/researcher
    device_model    VARCHAR(100),                   -- 设备型号
    
    -- === 标注信息 (数据质量) ===
    ai_label        VARCHAR(300),                   -- AI标注结果
    ai_confidence   DECIMAL(5,4),                   -- AI置信度
    human_label     VARCHAR(300),                   -- 人工标注结果 (修正后)
    human_label_by  INT,                            -- 标注人ID
    label_status    VARCHAR(30) DEFAULT 'ai_only',  -- ai_only/verified/corrected/disputed
    label_notes     TEXT,                           -- 标注备注
    
    -- === 质量评估 ===
    image_quality_score DECIMAL(3,2),               -- 图片质量评分 (0-1)
    is_usable       BOOLEAN DEFAULT TRUE,           -- 是否可用于训练
    reject_reason   VARCHAR(300),                   -- 不可用原因
    
    -- === 权限与版本 ===
    version         VARCHAR(20) NOT NULL,           -- 'vegetable' | 'fruit'
    language        VARCHAR(10) DEFAULT 'zh',       -- 用户语言
    is_public       BOOLEAN DEFAULT FALSE,          -- 是否公开 (隐私)
    
    -- === 元数据 ===
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- 索引设计
CREATE INDEX idx_di_crop ON disease_image(crop_id);
CREATE INDEX idx_di_disease ON disease_image(disease_id);
CREATE INDEX idx_di_version ON disease_image(version);
CREATE INDEX idx_di_label_status ON disease_image(label_status);
CREATE INDEX idx_di_location ON disease_image(gps_latitude, gps_longitude);
CREATE INDEX idx_di_created ON disease_image(created_at DESC);
CREATE INDEX idx_di_image_hash ON disease_image(image_hash); -- 去重查询
CREATE INDEX idx_di_growth_stage ON disease_image(growth_stage);
CREATE INDEX idx_di_weather ON disease_image(weather_condition);
```

### 2.2 为什么需要这么多字段？

| 字段组 | 科研用途 | 例子 |
|--------|----------|------|
| GPS + 位置 | 病虫害地理分布研究 | "芒果炭疽病在老挝南部发病率更高" |
| 生长阶段 | 发病时期分析 | "番茄晚疫病多发于开花结果期" |
| 天气数据 | 发病条件研究 | "雨季湿度>90%时炭疽病爆发" |
| 图片哈希 | 去重 | 防止同一张图片重复统计 |
| 标注信息 | 训练数据集构建 | AI标注→人工修正→高质量训练集 |
| 质量评分 | 数据清洗 | 模糊图片自动过滤 |
| 设备型号 | 数据质量分析 | 不同手机拍照质量对识别影响 |

---

## 3. 数据采集流程

### 3.1 用户拍照 → 自动采集

```
用户拍照识别
    │
    ├──→ APP自动获取:
    │     ├── GPS坐标 (需用户授权)
    │     ├── 拍摄时间
    │     ├── 设备型号
    │     └── APP版本
    │
    ├──→ 后端自动获取:
    │     ├── 天气数据 (通过GPS+时间查询天气API)
    │     └── 图片哈希 (SHA256去重)
    │
    └──→ 存入 disease_image 表
          └──→ 初始状态: label_status = 'ai_only'
```

### 3.2 专家标注 → 提升数据质量

```
AI自动标注 → 存入 disease_image (label_status=ai_only)
    │
    └──→ 定期导出 → 老师/专家审核
            │
            ├──→ 确认正确: label_status → 'verified'
            │
            ├──→ 修正错误: human_label = 正确标注
            │              label_status → 'corrected'
            │
            └──→ 质量差/无法标注: is_usable = FALSE
                                  label_status → 'rejected'
```

---

## 4. 训练数据集构建路径

### 4.1 数据积累里程碑

```
里程碑1 (1000张): 基础数据积累期
  - 主要来源: 老师提供 + 用户上传
  - 用途: API调用优化、Prompt调优
  - 时间: 第1-3个月

里程碑2 (3000张): 数据初步可用
  - 人工标注达到500+张
  - 用途: 验证集构建、简单分类模型实验
  - 时间: 第4-6个月

里程碑3 (5000张): 训练数据达标
  - 人工标注达到1000+张
  - 用途: 训练专属老挝病虫害识别模型 (YOLO/ResNet)
  - 时间: 第7-12个月

里程碑4 (10000+张): 高质量数据集
  - 覆盖主要病虫害各100+张
  - 用途: 发表论文、申请数据集著作权
```

### 4.2 数据导出格式（为训练准备）

```python
# 导出为YOLO/COCO格式的训练数据
def export_training_dataset(version: str, min_confidence: float = 0.8):
    """
    导出可用于训练的数据集。
    
    筛选条件:
    - label_status IN ('verified', 'corrected')
    - is_usable = TRUE
    - image_quality_score >= 0.7
    """
    pass

# 导出格式:
# dataset/
# ├── images/
# │   ├── img_001.jpg
# │   ├── img_002.jpg
# │   └── ...
# ├── labels/
# │   ├── img_001.txt  (YOLO格式标注)
# │   └── ...
# └── metadata.csv
#     image_id, crop, disease, gps_lat, gps_lng, growth_stage, weather, ...
```

---

## 5. 数据管理后台（管理端功能）

### 5.1 数据看板

```
┌─────────────────────────────────────────────────────────┐
│                   数据资产管理看板                         │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐   │
│  │ 总图片数  │ │ 已标注   │ │ 待审核   │ │ 本月新增  │   │
│  │  1,247   │ │  356     │ │   42     │ │  128     │   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘   │
│                                                          │
│  病虫害分布地图 (热力图)                                   │
│  ┌────────────────────────────────────────────────┐     │
│  │              [老挝地图]                          │     │
│  │   北部: 水稻病害为主                             │     │
│  │   南部: 果树病害为主                             │     │
│  └────────────────────────────────────────────────┘     │
│                                                          │
│  按作物统计:                                              │
│  番茄: 234张 | 白菜: 189张 | 芒果: 156张 | ...            │
│                                                          │
│  按病虫害统计:                                            │
│  晚疫病: 89张 | 炭疽病: 67张 | 叶斑病: 45张 | ...         │
└─────────────────────────────────────────────────────────┘
```

### 5.2 标注审核界面

```
┌─────────────────────────────────────────────────────────┐
│                   图片标注审核                             │
│                                                          │
│  ┌──────────────────────┐  ┌────────────────────────┐   │
│  │                      │  │ AI识别结果:              │   │
│  │                      │  │ 番茄晚疫病 (92%)        │   │
│  │     [病虫害图片]      │  │                        │   │
│  │                      │  │ 人工标注:               │   │
│  │                      │  │ [选择病虫害 ▼]          │   │
│  │                      │  │                        │   │
│  │                      │  │ 严重程度:               │   │
│  │                      │  │ ○轻微 ○中等 ●严重      │   │
│  │                      │  │                        │   │
│  │                      │  │ 生长阶段:               │   │
│  │                      │  │ [结果期 ▼]              │   │
│  │                      │  │                        │   │
│  └──────────────────────┘  │ [确认] [跳过] [标记废弃] │   │
│                            └────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 6. 数据隐私与合规

| 层面 | 措施 |
|------|------|
| 用户照片 | 默认不公开，仅用于识别 |
| GPS数据 | 需用户授权，可关闭 |
| 数据使用 | 告知用户"数据用于改善识别准确度" |
| 数据导出 | 脱敏处理，去除用户标识 |
| 科研数据 | 仅导出标注完成、脱敏的数据集 |

---

## 7. 种子数据导入格式（给老师的模板）

### 老师需要提供的数据格式

```
数据文件1: 作物列表.xlsx
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│ 作物中文名 │ 老挝语名  │ 分类     │ 学名     │ 简介     │
├──────────┼──────────┼──────────┼──────────┼──────────┤
│ 番茄     │ ໝາກເລັ່ນ │ 茄果类   │ Solanum..│ ...      │
│ 白菜     │ ຜັກກາດ.. │ 叶菜类   │ Brassica.│ ...      │
└──────────┴──────────┴──────────┴──────────┴──────────┘

数据文件2: 病虫害列表.xlsx
┌──────┬────────┬──────────┬────────┬──────────┬──────────┬──────────┐
│作物名│病虫害名│老挝语名   │类型    │症状(中文)│症状(老挝)│发病条件   │
├──────┼────────┼──────────┼────────┼──────────┼──────────┼──────────┤
│番茄  │晚疫病  │ພະຍາດ...│disease │叶片出现..│...       │温度18-...│
│白菜  │黑斑病  │...       │disease │...       │...       │...       │
└──────┴────────┴──────────┴────────┴──────────┴──────────┴──────────┘

数据文件3: 防控方案.xlsx
┌────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│病虫害名│防治类型   │措施(中文)│措施(老挝)│用法说明   │注意事项   │
├────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
│番茄晚疫│chemical  │58%甲霜灵 │...       │每7天1次  │采收前停用 │
│番茄晚疫│biological│轮作倒茬  │...       │...       │...       │
└────────┴──────────┴──────────┴──────────┴──────────┴──────────┘

数据文件4: 病虫害图片/
├── 番茄/
│   ├── 晚疫病/
│   │   ├── tomato_late_blight_01.jpg
│   │   ├── tomato_late_blight_02.jpg
│   │   └── tomato_late_blight_03.jpg
│   └── 早疫病/
│       └── ...
├── 白菜/
│   └── ...
└── 芒果/ (果树版)
    └── ...
```

---

## 8. 数据库表修订总结

相比第一阶段的设计，新增/修改的表：

| 表 | 变更 | 原因 |
|----|------|------|
| `disease_image` | **大量扩展** | 从简单图片URL表→科研数据采集表 |
| `user` | **新增** | 用户体系 |
| `user_location` | **新增** | 用户地区偏好 |
| `data_export_log` | **新增** | 数据导出记录 |
| `label_review_log` | **新增** | 标注审核日志 |

---

> **下一步: 回顾所有1.5阶段产出 → 确认后进入第三阶段**
