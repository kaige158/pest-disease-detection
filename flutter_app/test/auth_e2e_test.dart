// 用户系统端到端测试 —— 真实调用运行中的后端（不 mock）
//
// 运行前提：后端已启动在 API_BASE_URL 指向的地址（默认取 AppEnvironment 解析值）。
//   cd flutter_app
//   flutter test test/auth_e2e_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
//
// 覆盖：注册 → 登录 → 取资料 → 改资料 → 改密码（旧令牌失效）→ 退出
// 后端不可达时整个文件自动跳过，不影响常规 `flutter test`。

import 'package:flutter_test/flutter_test.dart';
import 'package:laos_agri_app/core/auth/auth_service.dart';
import 'package:laos_agri_app/core/auth/user_session.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/config/environment.dart';
import 'package:laos_agri_app/core/network/api_client.dart';

import 'support/demo_sms.dart';

void main() {
  final config = AppConfig.vegetable;
  final auth = AuthService(config: config);
  late bool online;

  setUpAll(() async {
    online = await backendReachable();
    if (!online) {
      // ignore: avoid_print
      print('跳过：后端不可达（${AppEnvironment.springApiBaseUrl}）');
    }
  });

  tearDown(() => UserSession.instance.clear());

  test('新手机号首次登录 = 自动注册并下发令牌', () async {
    if (!online) return;
    final phone = uniquePhone();
    final outcome = await loginWithSms(auth, phone: phone, nickname: '测试农户');

    expect(outcome.registered, isTrue, reason: '首次登录应自动注册');
    expect(outcome.profile.role, 'FARMER');
    expect(outcome.profile.nickname, '测试农户');
    expect(outcome.profile.id, greaterThan(0));
    // 令牌必须已写入会话，后续请求才带得上
    expect(UserSession.instance.isLoggedIn, isTrue);
    expect(UserSession.instance.token, isNotEmpty);
    // 手机号必须脱敏返回，不能下发明文
    expect(outcome.profile.phone, contains('****'));
    expect(outcome.profile.phone, isNot(equals(phone)));
  });

  test('同一手机号再次登录 = 已注册，不再新建账号', () async {
    if (!online) return;
    final phone = uniquePhone();
    final first = await loginWithSms(auth, phone: phone);
    await UserSession.instance.clear();

    final second = await loginWithSms(auth, phone: phone);
    expect(second.registered, isFalse);
    expect(second.profile.id, first.profile.id, reason: '同一手机号必须复用同一账号');
  });

  // —— 以下三条锁定"短信验证码到底什么时候要"的判定规则 ——
  // 规则：新号码首次注册要；老号码 + 同一台设备 + 密码对，不要；
  //       老号码换设备要（防号码被他人拿去登录）。

  test('新号码首次登录必须短信验证（不许编个号就注册）', () async {
    if (!online) return;
    await expectLater(
      () => auth.login(phone: uniquePhone(), password: 'laos2026'),
      throwsA(isA<SmsCodeRequiredException>()),
      reason: '未验证号码归属就注册，会堆积假账号',
    );
  });

  test('老号码 + 同一设备 + 密码正确 = 免验证码直接登录', () async {
    if (!online) return;
    final phone = uniquePhone();
    await loginWithSms(auth, phone: phone); // 首次：注册并绑定本机设备号
    await UserSession.instance.clear();

    // 关键断言：这一次**不会**抛 SmsCodeRequiredException —— 老用户日常登录不该被打扰
    final again = await auth.login(phone: phone, password: 'laos2026');
    expect(again.registered, isFalse);
    expect(UserSession.instance.isLoggedIn, isTrue);
  });

  test('老号码换设备登录必须重新短信验证', () async {
    if (!online) return;
    final phone = uniquePhone();
    await loginWithSms(auth, phone: phone);
    await UserSession.instance.clear();

    // 直接打 HTTP 层，显式伪造另一台设备的 deviceUuid
    // （AuthService 内部的设备号由 DeviceIdentity 管理，测试里不便于替换）
    await expectLater(
      () => ApiClient(config: config).post('/auth/login', data: {
        'countryCode': '856',
        'phone': phone,
        'password': 'laos2026',
        'deviceUuid': 'e2e-other-device-${DateTime.now().microsecondsSinceEpoch}',
      }),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 428)),
    );
  });

  test('演示环境回显的验证码真的能用（短信未上线时的登录通路）', () async {
    if (!online) return;
    final phone = uniquePhone();

    // 演示档 app.sms.expose-code=true 时接口会带回 demo_code；
    // 生产环境该字段不存在，登录页也就不会出现"已自动填入"的提示。
    final sent = await auth.sendSmsCode(phone: phone);
    expect(sent.demoCode, isNotNull, reason: '演示档应回显验证码');
    expect(sent.demoCode!.length, 6);

    final outcome = await auth.login(
        phone: phone, password: 'laos2026', smsCode: sent.demoCode!);
    expect(outcome.registered, isTrue, reason: '带正确验证码应完成注册并登录');
    expect(UserSession.instance.isLoggedIn, isTrue);
  });

  test('密码错误被拒绝', () async {
    if (!online) return;
    final phone = uniquePhone();
    await loginWithSms(auth, phone: phone);
    await UserSession.instance.clear();

    await expectLater(
      () => auth.login(phone: phone, password: 'wrong-password'),
      throwsA(isA<ApiException>()),
    );
  });

  test('手机号格式非法被拒绝', () async {
    if (!online) return;
    await expectLater(
      () => auth.login(phone: 'abc', password: 'laos2026'),
      throwsA(isA<ApiException>()),
    );
  });

  test('带令牌取资料 / 改资料', () async {
    if (!online) return;
    final phone = uniquePhone();
    await loginWithSms(auth, phone: phone);

    final me = await auth.fetchMe();
    expect(me.id, greaterThan(0));

    final updated = await auth.updateProfile(
      nickname: 'ທ້າວ ຄຳ',
      province: '万象',
      district: '赛色塔',
    );
    expect(updated.nickname, 'ທ້າວ ຄຳ');
    expect(updated.regionProvince, '万象');
    expect(updated.regionDistrict, '赛色塔');
    // 会话中的资料同步更新，界面无需重新拉取
    expect(UserSession.instance.profile?.nickname, 'ທ້າວ ຄຳ');
  });

  test('改密码后旧令牌立即失效（令牌版本机制）', () async {
    if (!online) return;
    final phone = uniquePhone();
    await loginWithSms(auth, phone: phone);

    // 改密码：服务端递增 token_version，本机会话被主动清理
    await auth.changePassword(oldPassword: 'laos2026', newPassword: 'laos2027');
    expect(UserSession.instance.isLoggedIn, isFalse, reason: '改密码后应退出登录');

    // 旧密码不再可用，新密码可用
    await expectLater(
      () => auth.login(phone: phone, password: 'laos2026'),
      throwsA(isA<ApiException>()),
    );
    final again = await loginWithSms(auth, phone: phone, password: 'laos2027');
    expect(again.registered, isFalse);
  });

  test('未登录访问需要鉴权的接口 → 401', () async {
    if (!online) return;
    await UserSession.instance.clear();
    await expectLater(
      () => auth.fetchMe(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 401)),
    );
  });

  test('退出登录后本地令牌被清空', () async {
    if (!online) return;
    await loginWithSms(auth, phone: uniquePhone());
    expect(UserSession.instance.isLoggedIn, isTrue);

    await auth.logout();
    expect(UserSession.instance.isLoggedIn, isFalse);
    expect(UserSession.instance.token, isNull);
    expect(UserSession.instance.profile, isNull);
  });

  // ==================== 国际手机号（多国用户） ====================

  test('国家区号列表可拉取，且老挝为默认', () async {
    if (!online) return;
    final countries = await auth.fetchCountries(language: 'zh');
    expect(countries, isNotEmpty);
    expect(countries.map((c) => c.code), contains('856'));
    expect(countries.map((c) => c.code), contains('86'));
    expect(countries.first.code, '856', reason: '平台主战场是老挝，默认区号应为 856');
  });

  test('中国号码(+86)可注册并正确回传区号', () async {
    if (!online) return;
    final phone = '13${(DateTime.now().millisecondsSinceEpoch % 1000000000).toString().padLeft(9, '0').substring(0, 9)}';
    final outcome = await loginWithSms(auth,
        phone: phone, nickname: '中国技术员', countryCode: '86');
    expect(outcome.registered, isTrue);
    expect(outcome.profile.countryCode, '86');
    // 展示串应带区号，便于区分不同国家的用户
    expect(outcome.profile.phoneLabel, contains('+86'));
    expect(outcome.profile.phoneLabel, contains('****'));
  });

  test('同一号码在不同区号下是不同账号（区号参与唯一性）', () async {
    if (!online) return;
    final local = '9${(DateTime.now().millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
    final lao = await loginWithSms(auth, phone: local, countryCode: '856');
    await UserSession.instance.clear();
    final thai = await loginWithSms(auth, phone: local, countryCode: '66');

    expect(lao.profile.id, isNot(equals(thai.profile.id)),
        reason: '同样的本地号码在 +856 与 +66 下应是两个账号');
    expect(lao.profile.countryCode, '856');
    expect(thai.profile.countryCode, '66');
  });

  test('传完整国际号码（+856...）也能自动识别区号登录', () async {
    if (!online) return;
    final local = '20${(DateTime.now().millisecondsSinceEpoch % 100000000).toString().padLeft(8, '0')}';
    final first = await loginWithSms(auth, phone: local, countryCode: '856');
    await UserSession.instance.clear();

    // 老用户可能直接粘贴 +85620xxxxxxx
    final again = await auth.login(phone: '+856$local', password: 'laos2026');
    expect(again.registered, isFalse, reason: '应命中同一账号，而不是新建');
    expect(again.profile.id, first.profile.id);
  });

  test('号码位数不足会被拒绝', () async {
    if (!online) return;
    await expectLater(
      () => auth.login(phone: '123', password: 'laos2026', countryCode: '86'),
      throwsA(isA<ApiException>()),
    );
  });
}
