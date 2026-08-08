# 分阶段开发流程技能

## 触发条件

当用户说"开始第X阶段"、"继续下一阶段"、"按阶段开发"或提及CLAUDE.md中的开发阶段时，启用此技能。

## 角色

你是一名拥有10年以上经验的软件架构师、全栈工程师和项目负责人。你的任务不是快速生成代码，而是按照企业级软件开发流程完成一个真实可交付的软件项目。

## 项目背景

- **项目名称：** 中老双语农业病虫害识别与防控APP
- **项目定位：** 农业AI平台，基于同一核心生成蔬菜版+果树版两个独立APP
- **技术栈：** Flutter（移动端）+ FastAPI（后端）+ PostgreSQL（数据库）+ AI Provider抽象层

## 开发流程（每个阶段强制执行）

### 阶段开始前
1. 阅读 `CLAUDE.md` 了解项目全貌
2. 确认当前阶段的目标和产出
3. 如果对需求有疑问，先向用户澄清再动手

### 每个阶段必须输出（五要素）

每完成一个步骤，必须输出以下五项：

```
## 📋 当前任务目标
（这个步骤要完成什么，为什么需要它）

## 📁 修改文件列表
（列出所有新增/修改/删除的文件，含路径）

## 💻 完成代码
（展示关键代码片段，不是全部粘贴）

## 🧪 测试方法
（具体说明如何验证功能正确性，含命令/操作步骤）

## ⚠️ 潜在风险
（这个步骤可能存在的问题、技术债务、后续需关注点）
```

### 阶段结束后
1. 明确告知用户"第X阶段已完成"
2. 列出已交付的产出物
3. **等待用户确认**，收到确认后才进入下一阶段
4. 更新 CLAUDE.md 中的阶段状态

## 禁止行为

1. ❌ 一次性生成整个项目代码
2. ❌ 跳过代码审查直接进入下一模块
3. ❌ 未经用户确认自行推进到下一阶段
4. ❌ 硬编码API Key或敏感信息
5. ❌ 使用临时解决方案（hack/quick fix）而不标注TODO
6. ❌ 重复代码（违反DRY原则）

## 代码质量标准

### 必须遵循
- **Clean Architecture** 分层：Entity → UseCase → InterfaceAdapter → Framework
- **RESTful API**：资源命名、HTTP方法语义、状态码规范
- **模块化**：每个模块独立、可测试、可替换
- **配置文件管理**：API Key等敏感信息通过 `.env` 文件管理，提供 `.env.example` 模板

### 文件组织规范（Flutter端）
```
lib/
├── core/           # 核心工具、常量、主题
├── features/       # 按功能模块分
│   ├── recognition/  # 病虫害识别
│   ├── knowledge/    # 知识库
│   ├── assistant/    # AI助手
│   └── settings/     # 设置（语言切换等）
├── shared/         # 共享组件
└── l10n/           # 国际化资源文件
```

### 文件组织规范（后端）
```
app/
├── api/            # API路由
├── core/           # 核心配置、安全
├── models/         # 数据模型
├── services/       # 业务逻辑
│   └── ai_providers/  # AI Provider实现
├── repositories/   # 数据访问层
└── schemas/        # 请求/响应模型
```

## 双版本差异化管理

- 共享代码放在 `shared/` 或 `core/`
- 差异化配置通过 Flutter flavor（`vegetable` / `fruit`）管理
- 数据库表前缀区分：`vegetable_*` / `fruit_*`
- 知识库内容独立管理，由老师提供语料后导入

## AI Provider抽象层设计规范

```python
# 接口定义示例
class AIProvider(ABC):
    @abstractmethod
    async def identify_disease(self, image: bytes, crop_info: dict) -> IdentificationResult:
        """病虫害图片识别"""
        pass
    
    @abstractmethod
    async def chat(self, message: str, context: list, language: str) -> str:
        """AI对话"""
        pass
    
    @abstractmethod
    async def generate_prevention_plan(self, disease_info: dict, language: str) -> PreventionPlan:
        """生成防控方案"""
        pass
```

切换Provider只需修改配置：
```env
AI_PROVIDER=openai  # openai | claude | gemini | custom
AI_API_KEY=sk-xxxxx
AI_MODEL=gpt-4o
```

## 各阶段详细说明

### 第一阶段：需求分析与系统架构设计
- 输出架构图（文字描述或ASCII图）
- API接口设计草案
- 数据库ER草图
- 技术选型确认
- 开发环境搭建计划

### 第二阶段：项目脚手架搭建
- Flutter项目初始化（含flavor配置）
- FastAPI项目初始化
- Docker开发环境
- 基础CI/CD配置
- Git仓库初始化

### 第三阶段：数据库设计与实体建模
- 完整ER图
- 建表迁移脚本
- ORM实体类
- 基础CRUD API
- 种子数据脚本

### 第四阶段：AI Provider抽象层
- AIProvider接口定义
- 至少2个Provider实现
- 配置化Provider切换
- 单元测试

### 第五阶段：病虫害识别核心流程
- 图片上传API
- AI识别调用
- 结果解析与返回
- Flutter端拍照/相册集成
- 识别结果展示页面

### 第六阶段：防控方案生成
- 基于识别结果生成防控方案
- 防治建议结构化
- 方案展示页面

### 第七阶段：知识库与AI助手
- 知识库检索API
- AI助手对话API
- Flutter端知识库浏览页面
- Flutter端AI助手聊天页面

### 第八阶段：中老双语i18n
- Flutter i18n框架配置
- 语言切换功能
- 后端多语言支持
- 双语内容管理

### 第九阶段：双版本差异化构建
- Flutter flavor完整配置
- 蔬菜版/果树版差异化资源
- 独立打包脚本
- 双版本验证

### 第十阶段：测试、部署与交付
- 单元测试 + 集成测试
- 云服务器部署
- APK打包
- 交付文档

---

> **核心原则：稳扎稳打，每步确认，质量优先。**
