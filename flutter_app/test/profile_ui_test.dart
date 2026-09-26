// 已登录／未登录两种状态的界面渲染测试
//
// 为什么用 widget 测试而不是浏览器里模拟登录：
//   Flutter Web 把文本渲染到 canvas，语义树只暴露部分节点，
//   自动化点击 + 文本断言不稳定。widget 测试能确定性地验证界面逻辑。
//
// 运行：flutter test test/profile_ui_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laos_agri_app/core/auth/user_session.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/features/auth/pages/login_page.dart';
import 'package:laos_agri_app/features/auth/pages/profile_page.dart';
import 'package:laos_agri_app/shared/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 构造一个"已登录用户"，字段与后端 UserPublicView 对齐
UserProfile fakeProfile() => const UserProfile(
      id: 42,
      uuid: 'test-uuid-0042',
      phone: '0209****657',
      nickname: 'ທ້າວ ຄຳ',
      avatarUrl: '',
      role: 'FARMER',
      language: 'lo',
      regionProvince: '万象',
      regionDistrict: '赛色塔',
      cropPreferences: '[]',
      isActive: true,
      loginCount: 3,
      lastLoginAt: '2026-09-26T12:00:00',
      createdAt: '2026-09-26T11:00:00',
    );

Future<void> seedLogin() async {
  SharedPreferences.setMockInitialValues({});
  await UserSession.instance.save(token: 'fake.jwt.token', profile: fakeProfile());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await UserSession.instance.clear();
  });

  group('未登录状态', () {
    testWidgets('个人中心显示登录引导，不显示退出入口', (tester) async {
      await UserSession.instance.clear();
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('还没有登录'), findsOneWidget);
      expect(find.text('登录 / 注册'), findsWidgets);
      expect(find.text('退出登录'), findsNothing);
      // 语言切换对未登录用户也可用
      expect(find.text('语言 / ພາສາ'), findsOneWidget);
    });
  });

  group('已登录状态', () {
    testWidgets('个人中心显示用户资料、角色与退出入口', (tester) async {
      await seedLogin();
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // 昵称（老挝语）与脱敏手机号必须展示
      expect(find.text('ທ້າວ ຄຳ'), findsWidgets);
      expect(find.text('0209****657'), findsOneWidget);
      // 角色标签走双语文案
      expect(find.text('农户'), findsOneWidget);
      // 所在地
      expect(find.text('万象 · 赛色塔'), findsOneWidget);
      // 已登录专属入口
      expect(find.text('编辑资料'), findsOneWidget);
      expect(find.text('修改密码'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
      // 不应再出现登录引导
      expect(find.text('还没有登录'), findsNothing);
    });

    testWidgets('老挝语界面下角色与按钮文案切换为老挝语', (tester) async {
      await seedLogin();
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(config: AppConfig.vegetable, language: 'lo'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ຊາວກະສິກອນ'), findsOneWidget); // 农户
      expect(find.text('ອອກຈາກລະບົບ'), findsOneWidget); // 退出登录
      expect(find.text('ແກ້ໄຂຂໍ້ມູນ'), findsOneWidget); // 编辑资料
    });

    testWidgets('退出登录后回到未登录状态', (tester) async {
      await seedLogin();
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(UserSession.instance.isLoggedIn, isTrue);

      // 直接调用会话清理（界面上的弹窗确认流程在 e2e 测试里覆盖）
      await UserSession.instance.clear();
      await tester.pump(const Duration(milliseconds: 200));
      // ProfilePage 不是 ListenableBuilder 的直接订阅者，重建后应显示未登录
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('还没有登录'), findsOneWidget);
    });
  });

  group('登录页', () {
    testWidgets('渲染手机号/密码输入与游客跳过入口', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('手机号'), findsOneWidget);
      expect(find.text('密码'), findsOneWidget);
      expect(find.text('登录'), findsWidgets);
      // 游客入口是"不登录也能用"的关键设计，必须存在
      expect(find.textContaining('先逛逛'), findsOneWidget);
      // 首次使用提示
      expect(find.textContaining('第一次使用'), findsOneWidget);
    });

    testWidgets('手机号与密码的格式校验会拦截非法输入', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // 直接点登录（字段为空）→ 出现校验提示
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('请输入手机号'), findsOneWidget);
      expect(find.text('请输入密码'), findsOneWidget);

      // 填过短号码 → 仍被拦截（国际号码口径：本地号码至少 6 位）
      await tester.enterText(find.byType(TextFormField).first, '0205');
      await tester.tap(find.widgetWithText(ElevatedButton, '登录'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('号码位数不足'), findsOneWidget);
    });

    testWidgets('登录页显示国家区号选择器（支持多国号码）', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // 平台主战场是老挝，默认展示 +856
      expect(find.text('+856'), findsOneWidget);
      expect(find.textContaining('支持多国号码'), findsOneWidget);

      // 点开国家选择器，应能看到其它国家
      await tester.tap(find.text('+856'));
      await tester.pumpAndSettle();
      expect(find.text('选择国家 / 地区'), findsOneWidget);
      expect(find.text('中国'), findsWidgets);
      expect(find.text('+86'), findsWidgets);
    });

    testWidgets('切换到注册模式后出现"称呼"输入框', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(config: AppConfig.vegetable, language: 'zh'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('称呼（可选）'), findsNothing);
      await tester.tap(find.textContaining('第一次使用'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('称呼（可选）'), findsOneWidget);
      expect(find.text('注册并登录'), findsOneWidget);
    });

    testWidgets('老挝语界面下登录页文案为老挝语', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(config: AppConfig.vegetable, language: 'lo'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ເບີໂທ'), findsOneWidget); // 手机号
      expect(find.text('ລະຫັດຜ່ານ'), findsOneWidget); // 密码
      expect(find.textContaining('ເບິ່ງກ່ອນ'), findsOneWidget); // 先逛逛
    });
  });
}
