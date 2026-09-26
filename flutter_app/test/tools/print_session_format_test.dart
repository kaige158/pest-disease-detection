// 工具测试：打印登录持久化到 SharedPreferences 的确切内容与格式。
// 用途：在 Flutter Web 环境用脚本注入登录态做 UI 验证时，必须与 Dart 侧格式完全一致，
//       猜格式容易出错，这里直接由代码产出权威值。
//
// 运行：
//   flutter test test/tools/print_session_format_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
import 'package:flutter_test/flutter_test.dart';
import 'package:laos_agri_app/core/auth/auth_service.dart';
import 'package:laos_agri_app/core/auth/user_session.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/demo_sms.dart';

void main() {
  test('导出登录态持久化格式', () async {
    // 没有真实的 SharedPreferences 插件时，用内存实现替代
    SharedPreferences.setMockInitialValues({});

    if (!await backendReachable()) {
      // ignore: avoid_print
      print('SKIP: 后端不可达');
      return;
    }

    // 新号码必须走"发码 → 取码 → 带码"的真实链路，不能直接 login
    final outcome = await loginWithSms(
        AuthService(config: AppConfig.vegetable),
        phone: uniquePhone(),
        nickname: '格式测试');

    final sp = await SharedPreferences.getInstance();
    final keys = sp.getKeys().toList();
    // ignore: avoid_print
    print('=== SHARED_PREFS_KEYS: $keys');
    for (final k in keys) {
      // ignore: avoid_print
      print('=== KEY[$k] => ${sp.get(k)}');
    }
    // ignore: avoid_print
    print('=== USER_ID: ${outcome.profile.id}');
    // ignore: avoid_print
    print('=== TOKEN_LEN: ${UserSession.instance.token?.length}');
  });
}
