# 系统架构设计文档

> 版本: v1.0 | 日期: 2026-08-08 | 阶段: 第一阶段

---

## 1. 系统全景架构

```
┌─────────────────────────────────────────────────────────────┐
│                        用户层                                │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Android  │  │   iOS    │  │  Android  │  │   iOS    │   │
│  │ 蔬菜版APP │  │ 蔬菜版APP │  │ 果树版APP │  │ 果树版APP │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       └──────────────┴─────────────┴──────────────┘         │
│                          │ HTTPS                             │
└──────────────────────────┼──────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────┐
│                    网关层 (Nginx)                             │
│                  反向代理 / SSL终结 / 限流                     │
└──────────────────────────┼──────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────┐
│                    应用层 (FastAPI)                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                   API Router                         │   │
│  │  /api/v1/recognition  /api/v1/knowledge              │   │
│  │  /api/v1/assistant    /api/v1/prevention             │   │
│  └──────────┬───────────────────────────────────────────┘   │
│             │                                                │
│  ┌──────────┴──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │   Service Layer      │  │  AI      │  │   i18n       │   │
│  │  ┌────────────────┐  │  │ Provider │  │  Engine      │   │
│  │  │ RecognitionSvc │  │  │ Layer    │  │  (zh/lo)     │   │
│  │  │ KnowledgeSvc   │  │  │ ┌──────┐ │  └──────────────┘   │
│  │  │ PreventionSvc  │  │  │ │OpenAI│ │                     │
│  │  │ AssistantSvc   │  │  │ ├──────┤ │                     │
│  │  │ UserSvc        │  │  │ │Claude│ │                     │
│  │  └────────────────┘  │  │ ├──────┤ │                     │
│  └──────────┬──────────┘  │  │Gemini│ │                     │
│             │              │  │ └──────┘ │                     │
│             │              │  └──────────┘                     │
│  ┌──────────┴──────────────────────────────────────────┐    │
│  │              Repository Layer (数据访问)              │    │
│  │  DiseaseRepo / CropRepo / KnowledgeRepo / UserRepo  │    │
│  └──────────┬──────────────────────────────────────────┘    │
└─────────────┼───────────────────────────────────────────────┘
              │
┌─────────────┼───────────────────────────────────────────────┐
│         数据层                                                │
│  ┌──────────┴──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │    PostgreSQL        │  │  Redis    │  │  File Store  │   │
│  │  (主数据库)           │  │  (缓存)   │  │  (图片/文件)  │   │
│  │  - 病虫害库           │  │  - Session│  │  - 用户上传   │   │
│  │  - 知识库             │  │  - AI结果 │  │  - 知识库图片 │   │
│  │  - 用户/配置           │  │  - 热点   │  │              │   │
│  └─────────────────────┘  └──────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Clean Architecture 分层（后端）

```
fastapi-backend/
│
├── api/                    # 【接口适配层】HTTP请求/响应处理
│   ├── v1/
│   │   ├── recognition.py  # 病虫害识别接口
│   │   ├── knowledge.py    # 知识库接口
│   │   ├── assistant.py    # AI助手接口
│   │   ├── prevention.py   # 防控方案接口
│   │   └── admin.py        # 管理后台接口
│   └── deps.py             # 依赖注入（DB会话、认证等）
│
├── core/                   # 【核心配置层】
│   ├── config.py           # 配置管理（从.env读取）
│   ├── security.py         # 安全相关（CORS、JWT等）
│   ├── database.py         # 数据库连接管理
│   └── exceptions.py       # 全局异常定义
│
├── services/               # 【业务逻辑层】用例/业务规则
│   ├── recognition.py      # 识别业务逻辑
│   ├── knowledge.py        # 知识库业务逻辑
│   ├── assistant.py        # AI助手业务逻辑
│   ├── prevention.py       # 防控方案业务逻辑
│   └── ai_providers/       # AI Provider抽象
│       ├── base.py         # 抽象基类
│       ├── openai.py       # OpenAI实现
│       ├── claude.py       # Claude实现
│       ├── gemini.py       # Gemini实现
│       └── factory.py      # Provider工厂
│
├── repositories/           # 【数据访问层】
│   ├── disease.py          # 病虫害数据访问
│   ├── crop.py             # 作物数据访问
│   ├── knowledge.py        # 知识库数据访问
│   └── user.py             # 用户数据访问
│
├── models/                 # 【实体层】ORM模型
│   ├── disease.py          # 病虫害实体
│   ├── crop.py             # 作物实体
│   ├── knowledge.py        # 知识条目实体
│   └── user.py             # 用户实体
│
├── schemas/                # 【DTO层】请求/响应模型
│   ├── recognition.py
│   ├── knowledge.py
│   └── common.py
│
├── migrations/             # 数据库迁移脚本
├── tests/                  # 测试
├── .env.example            # 环境变量模板
└── main.py                 # 应用入口
```

---

## 3. Flutter 移动端分层

```
flutter-app/
│
├── lib/
│   ├── main_vegetable.dart      # 蔬菜版入口
│   ├── main_fruit.dart          # 果树版入口
│   │
│   ├── core/                    # 【核心层】
│   │   ├── config/
│   │   │   ├── app_config.dart  # App配置（flavor区分）
│   │   │   └── api_config.dart  # API地址配置
│   │   ├── theme/
│   │   │   ├── app_theme.dart   # 主题定义
│   │   │   └── colors.dart      # 颜色常量
│   │   ├── network/
│   │   │   ├── api_client.dart  # HTTP客户端封装
│   │   │   └── api_exception.dart
│   │   └── utils/
│   │       ├── image_picker.dart
│   │       └── language_helper.dart
│   │
│   ├── features/                # 【功能模块层】
│   │   ├── recognition/         # 病虫害识别
│   │   │   ├── pages/
│   │   │   │   ├── recognition_page.dart
│   │   │   │   └── result_page.dart
│   │   │   ├── widgets/
│   │   │   │   ├── camera_button.dart
│   │   │   │   └── result_card.dart
│   │   │   └── providers/
│   │   │       └── recognition_provider.dart
│   │   │
│   │   ├── knowledge/           # 知识库
│   │   │   ├── pages/
│   │   │   │   ├── knowledge_list_page.dart
│   │   │   │   └── knowledge_detail_page.dart
│   │   │   ├── widgets/
│   │   │   │   └── search_bar.dart
│   │   │   └── providers/
│   │   │       └── knowledge_provider.dart
│   │   │
│   │   ├── assistant/           # AI助手
│   │   │   ├── pages/
│   │   │   │   └── chat_page.dart
│   │   │   ├── widgets/
│   │   │   │   ├── chat_bubble.dart
│   │   │   │   └── chat_input.dart
│   │   │   └── providers/
│   │   │       └── chat_provider.dart
│   │   │
│   │   └── settings/            # 设置
│   │       ├── pages/
│   │       │   └── settings_page.dart
│   │       └── providers/
│   │           └── language_provider.dart
│   │
│   ├── shared/                  # 【共享组件层】
│   │   ├── widgets/
│   │   │   ├── app_scaffold.dart
│   │   │   ├── loading_indicator.dart
│   │   │   └── error_widget.dart
│   │   └── models/
│   │       ├── disease.dart
│   │       ├── crop.dart
│   │       └── knowledge.dart
│   │
│   └── l10n/                    # 【国际化资源】
│       ├── app_zh.arb           # 中文
│       └── app_lo.arb           # 老挝语
│
├── assets/
│   ├── images/
│   │   ├── vegetable/           # 蔬菜版图片资源
│   │   └── fruit/               # 果树版图片资源
│   └── data/
│       ├── vegetable_knowledge/ # 蔬菜知识库数据(老师提供)
│       └── fruit_knowledge/     # 果树知识库数据(老师提供)
│
├── android/                     # Android原生配置
├── ios/                         # iOS原生配置
└── pubspec.yaml
```

---

## 4. Flutter Flavor 配置策略

```
# 通过 --flavor 参数区分版本
flutter run --flavor vegetable   # 蔬菜版
flutter run --flavor fruit       # 果树版

# 配置差异：
┌──────────────┬───────────────────┬──────────────────┐
│    配置项     │   vegetable       │   fruit           │
├──────────────┼───────────────────┼──────────────────┤
│ app_name     │ 老挝蔬菜病虫害防控  │ 老挝果树病虫害防控  │
│ app_id       │ com.laos.veggie   │ com.laos.fruit     │
│ 首页分类      │ 蔬菜分类           │ 果树分类           │
│ 数据库表前缀   │ vegetable_        │ fruit_            │
│ 知识库路径     │ vegetable_knowledge│ fruit_knowledge   │
│ 主题色        │ 绿色(#4CAF50)      │ 橙色(#FF9800)     │
│ 图标          │ 蔬菜icon           │ 果树icon          │
└──────────────┴───────────────────┴──────────────────┘
```

---

## 5. 核心数据流

### 5.1 病虫害识别流程

```
用户拍照 → 图片压缩(Flutter) → 上传图片(HTTP multipart)
    → 后端接收 → 文件暂存 → 调用AI Provider识别
    → AI返回结果 → 后端解析 → 查询本地病虫害库匹配
    → 返回识别结果 + 防控方案 → Flutter展示结果页
```

### 5.2 AI助手对话流程

```
用户输入文字(中文/老挝语) → Flutter发送 → 后端接收
    → 构建prompt(含农业上下文 + 语言指令) → 调用AI Provider
    → AI返回 → 解析格式化 → 返回Flutter → 聊天页展示
```

### 5.3 知识库查询流程

```
用户搜索关键词 → Flutter发送 → 后端查询PostgreSQL
    → 全文检索(中老双语) → 返回匹配结果列表
    → Flutter展示 → 用户点击查看详情
```

---

## 6. 安全设计要点

| 层面 | 措施 |
|------|------|
| **传输** | 全站HTTPS，API使用TLS 1.3 |
| **认证** | JWT Token（简单用户系统），可选 |
| **API Key** | 仅存服务端 `.env`，绝不暴露给客户端 |
| **图片上传** | 限制大小(10MB)、类型校验(jpg/png/webp)、病毒扫描 |
| **限流** | Nginx + FastAPI 双层限流，防止API滥用 |
| **CORS** | 仅允许App来源域名 |
| **SQL注入** | ORM参数化查询 |
| **日志** | 不记录API Key、用户敏感信息 |

---

## 7. 部署架构

```
┌─────────────────────────────────────────┐
│             云服务器 (初期)              │
│  ┌─────────────────────────────────┐    │
│  │         Docker Compose          │    │
│  │  ┌────────┐ ┌────────┐ ┌─────┐ │    │
│  │  │ Nginx  │ │FastAPI │ │Redis│ │    │
│  │  │  :443  │ │ :8000  │ │:6379│ │    │
│  │  └────────┘ └────────┘ └─────┘ │    │
│  │  ┌────────┐ ┌────────────────┐  │    │
│  │  │PostgreSQL│ │  File Volume  │  │    │
│  │  │ :5432   │ │  (图片存储)    │  │    │
│  │  └────────┘ └────────────────┘  │    │
│  └─────────────────────────────────┘    │
│  后期可迁移至学校服务器                     │
└─────────────────────────────────────────┘
```

---

> 下一步：API接口设计草案 → 数据库ER设计
