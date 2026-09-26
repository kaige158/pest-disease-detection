// 环境地址解析验证 —— 覆盖四种真实部署场景。
//
// 运行（每种场景单独跑，因为 --dart-define 是编译期注入）：
//   flutter test test/env_resolution_test.dart                                    # 默认(Web/桌面/模拟器)
//   flutter test test/env_resolution_test.dart --dart-define=API_BASE_URL=http://192.168.1.23:8080
//   flutter test test/env_resolution_test.dart --dart-define=API_BASE_URL=https://api.example.com/api/v1
//   flutter test test/env_resolution_test.dart --dart-define=API_HOST=192.168.1.50
//   flutter test test/env_resolution_test.dart --dart-define=API_BASE_URL=http://10.1.2.3:8080 --dart-define=AI_API_BASE_URL=http://10.1.2.3:9000
//
// 断言按注入值分支，任何一种场景跑都不应失败。

import 'package:flutter_test/flutter_test.dart';
import 'package:laos_agri_app/core/config/environment.dart';

void main() {
  final spring = AppEnvironment.springApiBaseUrl;
  final ai = AppEnvironment.aiApiBaseUrl;

  test('解析结果整体合法', () {
    // ignore: avoid_print
    print('场景解析: spring=$spring | ai=$ai');

    expect(spring, startsWith('http'), reason: '必须是完整 URL');
    expect(spring, endsWith('/api/v1'), reason: '必须带接口前缀');
    expect(ai, endsWith('/api/v1'));

    // 注意：不能用 contains('//api') 判断双斜杠 —— https:// 里的 // 会误报，
    // 只检查 path 部分是否出现连续斜杠
    expect(Uri.parse(spring).path.contains('//'), isFalse, reason: '路径不能出现双斜杠');
    expect(Uri.parse(ai).path.contains('//'), isFalse);
    expect(Uri.tryParse(spring)?.host, isNotEmpty, reason: 'host 不能为空');
    expect(Uri.tryParse(ai)?.host, isNotEmpty);
  });

  test('注入 host:port 时自动补 /api/v1', () {
    if (!spring.contains('192.168.1.23')) return;
    expect(spring, 'http://192.168.1.23:8080/api/v1');
    // AI 地址跟随同一主机，避免半指定半默认的错配
    expect(ai, 'http://192.168.1.23:8000/api/v1');
  });

  test('注入完整地址时原样使用（仅去尾斜杠）', () {
    // 仅在"只注入了业务后端域名"这一场景下生效
    if (!spring.contains('api.example.com') || ai.contains('ai.example.com')) return;
    expect(spring, 'https://api.example.com/api/v1');
    // 生产：公网域名不推导 8000 端口，AI 服务默认与业务后端同源（由网关路由）
    expect(ai, 'https://api.example.com/api/v1');
  });

  test('只注入 API_HOST 时两个服务都跟随该主机', () {
    if (!spring.contains('192.168.1.50')) return;
    expect(spring, 'http://192.168.1.50:8080/api/v1');
    expect(ai, 'http://192.168.1.50:8000/api/v1');
  });

  test('单独注入 AI 地址时精确覆盖', () {
    if (!ai.contains('9000') && !ai.contains('ai.example.com')) return;
    if (ai.contains('9000')) {
      expect(ai, 'http://10.1.2.3:9000/api/v1');
      expect(spring, 'http://10.1.2.3:8080/api/v1');
    } else {
      // 生产环境 AI 服务独立域名
      expect(ai, 'https://ai.example.com/api/v1');
      expect(spring, 'https://api.example.com/api/v1');
    }
  });

  test('默认场景：Web/桌面走 localhost，Android 走模拟器映射', () {
    // 注入了任何自定义地址时该场景不适用（含契约/e2e 测试用的本机后端端口）
    if (spring.contains('192.168') ||
        spring.contains('example.com') ||
        spring.contains('10.1.2.3') ||
        spring.contains('127.0.0.1') ||
        spring.contains(':18080')) {
      return;
    }
    expect(spring, matches(RegExp(r'^http://(localhost|10\.0\.2\.2):8080/api/v1$')));
    expect(ai, matches(RegExp(r'^http://(localhost|10\.0\.2\.2):8000/api/v1$')));
  });
}
