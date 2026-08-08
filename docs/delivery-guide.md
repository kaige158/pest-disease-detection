# 项目交付指南

> 中老双语农业病虫害识别与防控APP — 正式交付文档

---

## 一、交付物清单

| # | 交付物 | 说明 | 状态 |
|---|--------|------|:--:|
| 1 | **蔬菜版APK** | `laos_agri_vegetable_v1.0.0.apk` | 🚧 需开发者模式 |
| 2 | **果树版APK** | `laos_agri_fruit_v1.0.0.apk` | 🚧 需开发者模式 |
| 3 | **专家后台** | Spring Boot Web管理后台 | ✅ 已完成 |
| 4 | **项目源码** | GitHub仓库 | ✅ |
| 5 | **用户操作手册** | 见本文档第三节 | ⏳ |
| 6 | **老师后台操作手册** | 见本文档第四节 | ⏳ |
| 7 | **数据导入模板** | Excel + SQL脚本 | ✅ |
| 8 | **系统部署文档** | Docker一键部署 | ✅ |
| 9 | **AI模型说明** | Provider切换指南 | ✅ |

---

## 二、APK构建方法

### 前提条件
```bash
# Windows: 开启开发者模式
设置 → 更新和安全 → 开发者选项 → 开发者模式(开)

# 验证
flutter doctor
```

### 构建命令
```bash
cd flutter_app

# 蔬菜版
flutter build apk --flavor vegetable -t lib/main_vegetable.dart
# 输出: build/app/outputs/flutter-apk/app-vegetable-release.apk

# 果树版
flutter build apk --flavor fruit -t lib/main_fruit.dart
# 输出: build/app/outputs/flutter-apk/app-fruit-release.apk
```

### iOS构建（需macOS + Xcode）
```bash
flutter build ios --flavor vegetable -t lib/main_vegetable.dart
flutter build ios --flavor fruit -t lib/main_fruit.dart
```

---

## 三、系统部署（Docker一键部署）

### 云服务器要求
| 配置 | 最低 | 推荐 |
|------|------|------|
| CPU | 2核 | 4核 |
| 内存 | 4GB | 8GB |
| 磁盘 | 20GB | 50GB |
| 系统 | Ubuntu 22.04 | Ubuntu 22.04 |

### 部署步骤
```bash
# 1. 安装Docker
curl -fsSL https://get.docker.com | bash

# 2. 拉取项目
git clone <项目仓库地址>
cd laos-agri-platform

# 3. 配置环境变量
cp backend/.env.example backend/.env
# 编辑 .env 填入真实的AI API Key

# 4. 一键启动
docker compose up -d

# 5. 验证
curl http://localhost:8080/health
# → {"status":"ok"}

# 专家后台
浏览器打开: http://服务器IP:8080/admin/dashboard
```

### 初始化数据
```bash
# 导入种子数据(8作物+24病虫害)
docker exec -i laos_agri_db psql -U postgres -d laos_agri < database/seed_data_v1.sql
```

---

## 四、用户操作手册（农户版）

### 快速开始
1. **下载安装** — 从应用商店或APK安装APP
2. **首次打开** — 选择语言（中文/老挝语）
3. **开始使用** — 不需要注册，直接使用

### 拍照识病（最常用）
```
❶ 打开APP → 点底部"拍照识病"
❷ 对准异常叶片拍照（或从相册选）
❸ 点"开始识别"
❹ 等待3-8秒
❺ 查看结果：
   - 病虫害名称
   - 置信度百分比
   - 症状描述
   - 防治建议
```

### 知识库查询
```
❶ 点底部"知识库"
❷ 点击作物名称（白菜/番茄/辣椒...）
❸ 查看该作物的所有病虫害
❹ 点开详情看症状和防治方法
❺ 也可以用顶部搜索框直接搜
```

### AI诊断助手
```
❶ 点底部"AI助手"
❷ "智能诊断"Tab → 点"开始诊断"
❸ 依次选择：什么作物→哪里异常→症状类型→颜色...
❹ 得到诊断建议
❺ "离线搜索"Tab可以不联网搜索病虫害
```

### 切换语言
```
底部"设置" → 语言开关 → 中文/老挝语
```

---

## 五、老师操作手册（专家后台版）

### 访问地址
```
http://服务器IP:8080/admin/dashboard
```

### 日常操作（每周15-30分钟）

#### 1. 查看数据仪表盘
打开后台 → 看到4个统计卡片：
- 累计识别次数
- 待审核数量
- 病虫害条目数
- 可用图片数据量

#### 2. 审核AI识别结果
```
点击"AI审核中心"
→ 查看待审核列表
→ 点击"审核"按钮
→ 查看图片和AI结果
→ 点击"确认"（AI正确）或手动修正
```

#### 3. 管理知识库
```
点击"知识库管理"
→ 搜索病虫害
→ 点击✏️编辑（修改中文名/老挝语/症状/条件）
→ 点击"新增病虫害"填写表单
→ 保存
```

#### 4. 数据导出
```
点击"数据统计"
→ 查看统计图表
→ 导出CSV/JSON数据
→ 用于科研报告/论文
```

---

## 六、数据导入指南

### 方式1: 专家后台逐条录入
适合少量新增，见第五节。

### 方式2: Excel批量导入（推荐大量数据）
```
1. 按模板整理数据（见 /docs/data-import-guide.md）
2. 上传到服务器
3. 运行导入脚本:
   python scripts/import_images.py --image-dir /path/to/images --version vegetable
```

### 方式3: SQL直接导入
```bash
# 适合有SQL基础的开发者
psql -U postgres -d laos_agri -f database/seed_data_v1.sql
```

---

## 七、项目技术架构总览

```
Flutter APP (Android/iOS)
    │ HTTPS REST
    ▼
Spring Boot (:8080) ─── PostgreSQL (数据库)
    │                    ├── core (10张业务表)
    │ HTTP               └── expert/extension (扩展表)
    ▼
Python AI Service (:8000)
    │
    ▼
Vision AI (OpenAI/Claude/Gemini)
```

| 技术 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.44.8 | 移动端UI |
| Spring Boot | 3.2.5 | 业务后端 |
| Python/FastAPI | 3.13 | AI微服务 |
| PostgreSQL | 16 | 主数据库 |
| Redis | 7 | 缓存 |
| Docker | 29.5 | 容器化部署 |

---

## 八、联系方式

- 项目负责人：[老师姓名]
- 技术负责：[开发者姓名]
- 项目仓库：[GitHub地址]
