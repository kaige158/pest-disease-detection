// 冒烟测试：确保蔬菜版/果树版都能正常构建出主界面，且后端地址解析符合预期。
//
// 原来这里是 Flutter 模板生成的计数器测试，引用已不存在的 `main.dart` / `MyApp`，
// 早已无法运行；此处替换为对本项目真正有意义的检查。

import 'package:flutter_test/flutter_test.dart';
import 'package:laos_agri_app/app.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/config/environment.dart';
import 'package:laos_agri_app/core/network/api_client.dart';

void main() {
  testWidgets('蔬菜版主界面可构建，底部导航齐全', (WidgetTester tester) async {
    await tester.pumpWidget(const LaosAgriApp(config: AppConfig.vegetable));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('首页'), findsWidgets);
    expect(find.text('知识库'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
  });

  testWidgets('果树版主界面可构建', (WidgetTester tester) async {
    await tester.pumpWidget(const LaosAgriApp(config: AppConfig.fruit));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('首页'), findsWidgets);
    expect(find.text('知识库'), findsWidgets);
  });

  test('后端地址解析：带 /api/v1 前缀，无重复斜杠', () {
    final spring = AppEnvironment.springApiBaseUrl;
    final ai = AppEnvironment.aiApiBaseUrl;

    expect(spring, startsWith('http'));
    expect(spring, endsWith('/api/v1'));
    expect(spring, isNot(endsWith('/')));
    expect(spring.contains('//api'), isFalse);
    // AI 服务始终是独立端口，不能与业务后端混用
    expect(ai, contains(':8000'));
    expect(ai, endsWith('/api/v1'));
  });

  test('ApiClient 使用环境层解析出的地址，不再硬编码', () {
    final client = ApiClient(config: AppConfig.vegetable);
    expect(client.baseUrl, AppEnvironment.springApiBaseUrl);
  });
}
