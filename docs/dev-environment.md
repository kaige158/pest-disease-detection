# 开发环境与工具链确认

> 文档日期: 2026-08-08 | 环境检测通过 ✅

---

## 1. 当前环境检测结果

| 工具 | 版本 | 状态 |
|------|------|------|
| **Flutter** | 3.44.8 (stable) | ✅ 可用 |
| **Dart** | 3.12.2 | ✅ 可用 |
| **Python** | 3.13.13 | ✅ 可用 |
| **Git** | 2.49.0 | ✅ 可用 |
| **Docker** | 29.5.3 | ✅ 可用 |
| **操作系统** | Windows 10 | ✅ |

---

## 2. 开发工具链清单

### 2.1 移动端 (Flutter)

```
Flutter SDK:     3.44.8 (已安装)
编辑器:          VS Code / Android Studio
Flutter插件:     - flutter_lints (代码规范)
                 - flutter_localizations (i18n支持)
                 - provider / riverpod (状态管理)
                 - dio / http (网络请求)
                 - image_picker (相机/相册)
                 - cached_network_image (图片缓存)
```

### 2.2 后端 (FastAPI)

```
Python版本:      3.13.13 (已安装)
核心框架:        FastAPI + Uvicorn
ORM:             SQLAlchemy 2.0 + Alembic (迁移)
数据库:          PostgreSQL 16
缓存:            Redis 7 (可选)
依赖管理:        Poetry 或 pip + requirements.txt
虚拟环境:        venv
```

### 2.3 基础设施

```
容器化:          Docker + Docker Compose
数据库客户端:    DBeaver / pgAdmin
API测试:         Postman / VS Code Thunder Client
版本控制:        Git (需初始化仓库)
```

---

## 3. 本地开发环境搭建计划（第二阶段执行）

### 3.1 目录结构

```
F:\赚钱\老挝智能农果APP\
├── flutter-app/              # Flutter移动端项目
├── backend/                  # FastAPI后端项目
├── docs/                     # 文档 (已完成3份)
├── database/                 # 数据库迁移脚本
├── docker/                   # Docker配置
├── scripts/                  # 运维脚本
└── CLAUDE.md                 # 项目主计划
```

### 3.2 环境搭建顺序

1. **创建 Flutter 项目**（含 vegetable/fruit flavor 配置）
2. **创建 FastAPI 项目**（虚拟环境 + 依赖）
3. **创建 Docker Compose**（PostgreSQL + Redis + FastAPI）
4. **初始化 Git 仓库**（.gitignore + 首次提交）
5. **创建 .env 模板**（不含真实密钥）

### 3.3 依赖清单（待第二阶段安装）

**Flutter pubspec.yaml 核心依赖：**
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  dio: ^5.4.0          # HTTP客户端
  provider: ^6.1.0     # 状态管理
  image_picker: ^1.0.0 # 相机/相册
  cached_network_image: ^3.3.0
  flutter_dotenv: ^5.1.0 # 环境变量
  intl: ^0.19.0        # 国际化

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

**Python requirements.txt 核心依赖：**
```
fastapi==0.115.0
uvicorn[standard]==0.30.0
sqlalchemy==2.0.35
alembic==1.13.0
asyncpg==0.29.0  # PostgreSQL异步驱动
pydantic==2.9.0
pydantic-settings==2.5.0
python-multipart==0.0.12
httpx==0.27.0    # AI Provider调用
redis==5.1.0     # 缓存(可选)
Pillow==10.4.0   # 图片处理
```

---

## 4. CI/CD 规划（后期）

```
开发流程:
  本地开发 → Git Push → (可选)GitHub Actions
  → 自动测试 → Docker镜像构建 → 部署到云服务器

移动端构建:
  Android: gradle build → APK/AAB
  iOS: 需macOS + Xcode → IPA (可借用学校Mac设备)
```

---

## 5. 待确认事项

| # | 事项 | 影响 | 确认方 |
|---|------|------|--------|
| 1 | iOS构建需要macOS设备，是否有可用资源？ | iOS打包发布 | 老师/学校 |
| 2 | 云服务器选型（阿里云/腾讯云/华为云）？ | 部署成本 | 老师 |
| 3 | Apple Developer账号（$99/年）是否需要？ | App Store上架 | 老师 |
| 4 | Android应用商店（Google Play/华为/本地APK分发）？ | 分发方式 | 老师 |
| 5 | 是否使用Firebase/国内推送服务？ | 消息推送 | 后期决定 |

---

> ✅ 第一阶段完成，等待确认后进入第二阶段：项目脚手架搭建。
