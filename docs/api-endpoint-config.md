# 后端地址配置与构建说明

> 更新日期：2026-09-26
> 关联改动：统一 API 地址配置层，移除全部硬编码地址

---

## 1. 为什么需要这份文档

改动前，后端地址被**硬编码在 4 个地方**，且互相不一致：

| 位置 | 原地址 | 问题 |
|------|--------|------|
| `core/network/api_client.dart` | `http://10.0.2.2:8000/api/v1` | 端口错（8000 是 AI 服务，不是业务后端） |
| `features/recognition/pages/recognition_page.dart` | `http://10.0.2.2:8080/api/v1` | 真机/Web 全部连不上 |
| `features/recognition/pages/result_page.dart` | `http://10.0.2.2:8080/api/v1` | 同上 |
| `features/assistant/pages/chat_page.dart` | `http://10.0.2.2:8000/api/v1` | 同上 |

`10.0.2.2` 只在 **Android 模拟器**里有意义（模拟器访问宿主机的固定映射），
真机、Web、生产环境一律连不上。现在地址统一由
`lib/core/config/environment.dart` 解析，代码里不再出现硬编码。

---

## 2. 两个后端的默认端口

| 后端 | 默认地址 | 负责的接口 |
|------|----------|-----------|
| Spring Boot 业务后端 | `:8080/api/v1` | 识别 `/recognition/identify`、反馈 `/recognition/{id}/feedback`、知识库、同步 |
| FastAPI AI 服务 | `:8000/api/v1` | 诊断 Agent `/diagnosis/diagnose` |

> 客户端**不直连** AI 服务做识别：识别走 Spring Boot，由它转发给 AI 服务。
> 只有诊断 Agent 是客户端直连 AI 服务。

---

## 3. 各场景构建命令

### 3.1 Android 模拟器（开发默认，无需任何参数）

```powershell
cd F:\lao-cn-APP\flutter_app
flutter run -d emulator-5554 -t lib/main_vegetable.dart
```
解析结果：`spring=http://10.0.2.2:8080/api/v1 | ai=http://10.0.2.2:8000/api/v1`

### 3.2 真机（手机与电脑同一 WiFi）

先查电脑局域网 IP：`ipconfig`，然后在手机浏览器访问 `http://<电脑IP>:8080/actuator/health`
确认能通，再构建：

```powershell
flutter run -t lib/main_vegetable.dart --dart-define=API_BASE_URL=http://192.168.1.23:8080
```
解析结果：`spring=http://192.168.1.23:8080/api/v1 | ai=http://192.168.1.23:8000/api/v1`

> 只填 `主机:端口` 即可，`/api/v1` 会自动补上（填完整地址也可以）。
> AI 服务地址会自动跟随同一主机，不用重复指定。

### 3.3 Web 调试

```powershell
flutter run -d chrome -t lib/main_vegetable.dart
```
解析结果：`spring=http://localhost:8080/api/v1 | ai=http://localhost:8000/api/v1`

### 3.4 生产（云服务器）

```powershell
flutter build apk --release -t lib/main_vegetable.dart `
  --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

生产环境注意：
- **公网域名不会自动推导 8000 端口**（生产通常由网关统一反代，不对外暴露 8000）
- 若 AI 服务确实独立部署，显式指定：
  `--dart-define=AI_API_BASE_URL=https://ai.example.com/api/v1`

### 3.5 演示 APK（无服务器，走内置演示结果）

```powershell
flutter build apk --release -t lib/main_vegetable.dart --dart-define=DEMO_MODE=true
```

---

## 4. 支持的编译期变量

| 变量 | 作用 | 示例 |
|------|------|------|
| `API_BASE_URL` | 业务后端完整地址（含 `/api/v1`，可省略自动补） | `http://192.168.1.23:8080` |
| `AI_API_BASE_URL` | AI 服务地址，仅在与业务后端不同源时需要 | `https://ai.example.com/api/v1` |
| `API_HOST` | 只指定主机，两个服务端口按默认推导 | `192.168.1.50` |
| `DEMO_MODE` | `true` 时不请求后端，返回内置演示结果 | `true` |

优先级：`AI_API_BASE_URL` > `API_BASE_URL` 推导 > 平台默认值。

---

## 5. 排障

**APP 启动时会在控制台打印实际生效的地址**：

```
[LaosAgri] spring=http://10.0.2.2:8080/api/v1 | ai=http://10.0.2.2:8000/api/v1
```

识别页面连不上时，错误提示里也会带上当前地址，便于现场判断是网络问题还是配置问题。

| 现象 | 原因 | 处理 |
|------|------|------|
| 真机点击识别提示"无法连接服务器" | 仍用模拟器默认地址 | 用 `--dart-define=API_BASE_URL` 指到电脑局域网 IP |
| 电脑能开后台，手机打不开 | Windows 防火墙拦了 8080 | 放行 8080/8000 入站 |
| 识别返回"仅支持 jpg/png/webp 格式" | 客户端上传格式不对 | 已修复：识别改为 multipart 文件上传 |

---

## 6. 相关测试

| 测试文件 | 覆盖内容 |
|----------|----------|
| `test/env_resolution_test.dart` | 6 种部署场景的地址解析（默认/真机/生产/仅HOST/AI独立端口/AI独立域名） |
| `test/api_contract_test.dart` | 真实 HTTP 请求打到模拟后端，核对请求格式与后端契约（需先起 `mock_backend`） |
| `test/widget_test.dart` | 双版本主界面可构建 + 地址不再硬编码 |

契约测试运行方式：

```powershell
# 1. 启动模拟后端（回显收到的请求）
node .dsh-home/mock_backend.js
# 2. 跑契约测试
cd flutter_app
flutter test --dart-define=API_BASE_URL=http://127.0.0.1:18080/api/v1
```
