import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// 运行环境配置 — 后端地址的唯一来源
///
/// 为什么单独一个文件（不放进 AppConfig）：
///   `AppConfig` 描述的是"业务差异"（蔬菜版/果树版、配色、AppID），是编译期常量；
///   后端地址描述的是"部署环境差异"（模拟器/真机/Web/生产），两者变更原因不同，
///   混在一起会导致改地址就要动业务配置。所以这里独立成环境层。
///
/// 地址通过编译期变量注入，**不在代码里写死**：
///
///   Android 模拟器（默认，无需任何参数）
///     flutter run -d emulator-5554 -t lib/main_vegetable.dart
///
///   真机（手机与电脑同一 WiFi，换成电脑的局域网 IP）
///     flutter run -t lib/main_vegetable.dart --dart-define=API_BASE_URL=http://192.168.1.23:8080/api/v1
///
///   Web 调试（默认已是 localhost，通常无需参数）
///     flutter run -d chrome -t lib/main_vegetable.dart
///
///   生产（换成云服务器地址）
///     flutter build apk -t lib/main_vegetable.dart --dart-define=API_BASE_URL=https://api.example.com/api/v1
///
/// 注意：Dart 里 `String.fromEnvironment` 必须处于 const 上下文才生效，
/// 因此下面全部用 `const String.fromEnvironment(...)`。
class AppEnvironment {
  AppEnvironment._();

  /// 后端接口版本前缀
  static const String apiPrefix = '/api/v1';

  /// 业务后端（Spring Boot）默认端口
  static const int springPort = 8080;

  /// AI 服务（FastAPI）默认端口
  static const int aiPort = 8000;

  /// 编译期注入的完整地址（含 /api/v1），为空表示未注入
  static const String _injectedBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// 编译期注入的 AI 服务地址（含 /api/v1），为空表示未注入
  static const String _injectedAiBaseUrl =
      String.fromEnvironment('AI_API_BASE_URL', defaultValue: '');

  /// 编译期注入的宿主机地址（仅主机部分，不含端口与路径）
  static const String _injectedHost =
      String.fromEnvironment('API_HOST', defaultValue: '');

  /// 默认宿主机地址
  ///
  /// Android 模拟器里 `127.0.0.1` 指向模拟器自身，宿主机固定映射为 `10.0.2.2`；
  /// iOS 模拟器、桌面与 Web 则共享宿主机的 `localhost`。
  static String get defaultHost {
    if (_injectedHost.isNotEmpty) return _injectedHost;
    // Web：Flutter 的 Web 实现里访问 Platform 会抛异常，必须先看 kIsWeb
    if (kIsWeb) return 'localhost';
    return Platform.isAndroid ? '10.0.2.2' : 'localhost';
  }

  /// 业务后端基础地址（含 `/api/v1`）—— 识别、反馈、知识库、同步
  static String get springApiBaseUrl => _normalize(
      _injectedBaseUrl.isNotEmpty
          ? _injectedBaseUrl
          : 'http://$defaultHost:$springPort$apiPrefix');

  /// AI 服务基础地址（含 `/api/v1`）—— 诊断 Agent 对话
  ///
  /// 推导规则：
  ///   1. 显式注入 `AI_API_BASE_URL` → 完全以它为准
  ///   2. 注入了业务后端地址，且指向**本机/内网**（开发期）→ 同主机 + 8000 端口
  ///   3. 注入了业务后端地址，且指向**公网域名**（生产）→ 默认与业务后端同源，
  ///      因为生产环境通常由网关统一反代，不会对外暴露 8000 端口；
  ///      若 AI 服务确实独立部署，请显式注入 `AI_API_BASE_URL`
  static String get aiApiBaseUrl {
    if (_injectedAiBaseUrl.isNotEmpty) return _normalize(_injectedAiBaseUrl);
    if (_injectedBaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(_normalize(_injectedBaseUrl));
      if (uri != null && uri.host.isNotEmpty) {
        if (_isLocalOrPrivateHost(uri.host)) {
          return '${uri.scheme}://${uri.host}:$aiPort$apiPrefix';
        }
        // 生产：同源，交给网关路由
        return '${uri.scheme}://${uri.host}$apiPrefix';
      }
    }
    return _normalize('http://$defaultHost:$aiPort$apiPrefix');
  }

  /// 是否为本机/内网地址（开发期特征）
  static bool _isLocalOrPrivateHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') return true;
    if (host.endsWith('.local')) return true;
    final parts = host.split('.');
    if (parts.length == 4) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a == null || b == null) return false;
      // 10.x.x.x / 192.168.x.x / 172.16-31.x.x
      if (a == 10) return true;
      if (a == 192 && b == 168) return true;
      if (a == 172 && b >= 16 && b <= 31) return true;
      // Android 模拟器的宿主机映射
      if (a == 10 && b == 0) return true;
    }
    return false;
  }

  /// 去掉末尾斜杠；若只填了 host:port 则自动补 `/api/v1`
  static String _normalize(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    final uri = Uri.tryParse(url);
    if (uri != null && (uri.path.isEmpty || uri.path == '/')) {
      url = '$url$apiPrefix';
    }
    return url;
  }

  /// 当前解析结果摘要 —— 排障打日志用，不含任何密钥
  static String describe() => 'spring=$springApiBaseUrl | ai=$aiApiBaseUrl';
}
