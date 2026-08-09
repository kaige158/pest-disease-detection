# 🧠 农业AI模型升级路线图

> **定位:** 从"调用外部API"到"拥有自主农业AI能力"
> **设计:** Sprint 11 — 农业AI产品技术负责人
> **日期:** 2026年8月9日

---

## 核心理念

```
不要永久依赖 Gemini 作为识别引擎。

Gemini 的角色: 教师模型 (Teacher Model)
自有模型的角色: 学生模型 (Student Model)

教师教学生 → 学生独立工作 → 教师只在疑难时介入
```

---

## 四阶段路线

### 阶段1: 教师为主（当前 → 未来3个月）

```
架构:
  用户图片 → Gemini API → 诊断结果

Gemini角色: 100%识别任务
目标: 快速上线，积累数据
```

| 指标 | 目标 |
|------|------|
| 日识别量 | 10-100次 |
| 积累图片 | 0 → 1000-3000张 |
| 成本/次 | ~$0.002 (Gemini Flash) |
| 数据质量 | API自动采集，精准入库 |

**当前状态:** ✅ Gemini已接入，全字段入库，数据飞轮运转中

---

### 阶段2: 数据积累期（3-6个月）

```
架构:
  用户图片 → Gemini API → 诊断结果
                ↓
         diagnosis_record (全字段)
                ↓
         用户反馈 + 专家审核
                ↓
         training_dataset (training_ready=true)  ← Sprint 11新建
                ↓
         专家标注数据积累: 3000 → 5000+ 张
```

| 指标 | 目标 |
|------|------|
| 训练就绪图片 | 5000张（含中老双语标签） |
| 覆盖作物 | 8种蔬菜 + 4种果树 |
| 覆盖病害 | 24种（与实际数据对齐） |
| 专家参与 | 每张图片至少1位专家确认 |

**关键活动:**
- 老师提供老挝实地病害照片
- 农业专家日常审核标注
- Sprint 11 的 `training_dataset` 表持续填充
- 每月检查数据积累速度

**当前状态:** ✅ 基础设施就绪，等待真实照片填充

---

### 阶段3: 自有模型训练（6-9个月）

```
训练流程:
  training_dataset (training_ready=true)
         ↓
  数据预处理 (resize/augment/normalize)
         ↓
  数据集分割: train 70% / val 15% / test 15%
         ↓
  模型训练
         ↓
  验证评估 (对比Gemini基准)
         ↓
  模型导出 (ONNX/TFLite)
         ↓
  部署到 CustomProvider
```

#### 模型选型

| 模型 | 用途 | 输入 | 输出 | 大小 | 推理速度 |
|------|------|------|------|:--:|:--:|
| **YOLOv11n** | 病害检测（叶面病斑定位） | 640×640 | bbox + class | ~6MB | <50ms(CPU) |
| **MobileNetV3-Large** | 病害分类（是什么病） | 224×224 | 24类 | ~21MB | <30ms(CPU) |
| **EfficientNet-B0** | 高精度分类（备选） | 224×224 | 24类 | ~20MB | <80ms(CPU) |

#### 训练配置

```python
# YOLOv11 — 病斑检测
model = YOLO("yolo11n.pt")
model.train(
    data="dataset/agri_pests.yaml",
    epochs=100,
    imgsz=640,
    batch=16,
    device="cuda"  # 或 Google Colab免费GPU
)

# MobileNetV3 — 病害分类
model = timm.create_model("mobilenetv3_large_100", pretrained=True, num_classes=24)
# 训练: CrossEntropyLoss + AdamW + CosineAnnealingLR
```

#### 训练环境

| 选项 | 成本 | 说明 |
|------|:--:|------|
| Google Colab Pro | ~$10/月 | 免费GPU(T4)，适合初期 |
| 本地RTX 3060+ | 已有 | 适合频繁迭代 |
| 云GPU(AutoDL) | ~$0.5/小时 | RTX 3090/4090 |

---

### 阶段4: 混合推理（9-12个月）

```
架构:
              用户图片
                 ↓
         ┌── ImageQualityChecker ──┐
         ↓                          ↓
    质量合格                      质量不合格
         ↓                          ↓
    AI Router                   提示重新拍摄
         ↓
  ┌──────┴──────┐
  ↓              ↓
本地模型       Gemini API
(YOLO+         (疑难病例)
 MobileNet)
  ↓              ↓
  ├── 置信度>0.9 → 直接返回
  ├── 0.7-0.9  → 返回+提示复核
  └── <0.7     → 升级到Gemini
```

#### AI Router 规则

```python
class AIRouter:
    def route(self, image_bytes, local_result):
        if local_result.confidence >= 0.90:
            return Route.LOCAL_DIRECT   # 本地模型，毫秒级
        elif local_result.confidence >= 0.70:
            return Route.LOCAL_WARN     # 本地+提示复核
        else:
            return Route.UPGRADE_GEMINI # 调用Gemini
```

#### 预期效果

| 场景 | 占比 | 模型 | 延迟 | 成本 |
|------|:--:|------|:--:|:--:|
| 常见病害 | 70% | 本地模型 | <100ms | $0 |
| 可疑病例 | 20% | 本地+复核 | <100ms | $0 |
| 疑难病例 | 10% | Gemini | 4-10s | ~$0.002 |

**月成本:** 从 $30(Gemini全量) → $3(Gemini仅10%)

---

## CustomProvider 集成（预设计）

当自有模型训练完成，只需新增一个Provider：

```python
# ai-service/app/services/ai_providers/local_model_provider.py
class LocalModelProvider(AIProvider):
    """本地农业视觉模型 — YOLO + MobileNet 混合"""
    
    def __init__(self):
        self.detector = YOLO("models/yolo11_agri_pests.onnx")
        self.classifier = load_mobilenet("models/mobilenetv3_agri_24class.onnx")
        self.router = AIRouter()
    
    async def identify_disease(self, image_bytes, crop_info=None, ...):
        # 1. YOLO检测病斑
        boxes = self.detector(image_bytes)
        # 2. MobileNet分类
        result = self.classifier(image_bytes, crop_info)
        # 3. AI Router决策
        route = self.router.route(image_bytes, result)
        if route == Route.UPGRADE_GEMINI:
            return await self.gemini_fallback.identify_disease(image_bytes, ...)
        return result
```

切换方式: `.env` 中 `AI_PROVIDER=local` 即可，无需改APP或后端代码。

---

## 数据量预估

| 时间 | 阶段 | 累计图片 | 训练就绪 | 可用模型 |
|------|:--:|:--:|:--:|------|
| 0月 | 阶段1 | 0 | 0 | Gemini API |
| 3月 | 阶段1→2 | 1000-3000 | 500-1500 | Gemini API |
| 6月 | 阶段2→3 | 3000-8000 | 2000-5000 | YOLO检测实验 |
| 9月 | 阶段3→4 | 8000-15000 | 5000-10000 | 自有分类模型 |
| 12月 | 阶段4 | 15000+ | 10000+ | 混合推理上线 |

---

## 不做什么

| 不做 | 原因 |
|------|------|
| ❌ 从头训练大模型 | 数据量级不够，成本过高 |
| ❌ 训练NLP/对话模型 | 对话继续用Gemini，成本可控 |
| ❌ 自建GPU集群 | 初期用Colab/云GPU足够 |
| ❌ 复杂的多模态模型 | 先做好视觉分类，再考虑扩展 |
| ❌ 训练数据自动化标注 | 农业领域必须专家参与 |

---

## 需要的资源

| 资源 | 当前状态 | 需要的 |
|------|:--:|------|
| 训练图片 | 0张 | 5000张（需老师提供） |
| 专家标注 | 0次 | 每图1次专家确认 |
| GPU算力 | 0 | Google Colab / 云GPU |
| 模型部署 | Provider抽象层就绪 | ONNX/TFLite模型文件 |
| 数据管线 | ✅ Sprint 11建成 | 数据填充 |

---

> **关键认知:** 这个路线图的核心不是技术，而是**数据积累速度**。
> 技术架构已经就绪（Provider抽象→CustomProvider→混合路由→数据闭环）。
> 瓶颈在农业数据采集，不在代码。

---

*文档完成 | Sprint 11 | 2026-08-09*
