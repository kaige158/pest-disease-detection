import 'package:laos_agri_app/core/auth/device_identity.dart';
import 'package:laos_agri_app/core/auth/user_session.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/network/api_client.dart';
import 'package:laos_agri_app/shared/models/user_profile.dart';

/// 需要短信验证码才能继续（后端返回 HTTP 428）
///
/// 出现时机：① 该号码首次注册 ② 换设备登录。
/// 界面据此展开验证码输入框，而不是当成普通登录失败。
class SmsCodeRequiredException extends ApiException {
  final String reason;

  SmsCodeRequiredException(String message)
      : reason = message,
        super(428, message);
}

/// 登录结果
///
/// [registered] 为 true 表示本次是"首次登录自动注册"，界面可给出对应提示
/// （例如提示用户记住密码），这是本项目降低农户使用门槛的关键设计。
class LoginOutcome {
  final UserProfile profile;
  final bool registered;

  const LoginOutcome({required this.profile, required this.registered});
}

/// 一个国家/地区选项（区号 + 名称），由后端 `/auth/countries` 下发
class CountryOption {
  final String code;
  final String name;
  final String flag;

  const CountryOption({required this.code, required this.name, this.flag = ''});

  /// 内置兜底列表 —— 后端不可达时登录页仍可正常使用。
  /// 保留此列表是为了"离线也能登录"（识别/知识库本就支持离线）。
  static const List<CountryOption> fallback = [
    CountryOption(code: '856', name: '老挝 ລາວ', flag: '🇱🇦'),
    CountryOption(code: '86', name: '中国', flag: '🇨🇳'),
    CountryOption(code: '66', name: '泰国', flag: '🇹🇭'),
    CountryOption(code: '84', name: '越南', flag: '🇻🇳'),
    CountryOption(code: '855', name: '柬埔寨', flag: '🇰🇭'),
  ];

  static const String defaultCode = '856';
}

/// 短信验证码发送结果
class SmsSendResult {
  final String message;
  final int expiresInSeconds;
  final String countryCode;

  /// 开发/演示环境专属：后端直接把验证码回显回来（生产环境为 null）
  ///
  /// 为什么需要：老挝短信通道还没接入，开发期如果只能去服务器日志里翻验证码，
  /// 那"注册 / 换设备登录"这条链路在真机上根本走不通。是否回显由后端
  /// `app.sms.expose-code` 控制，生产必须关闭，届时这里永远是 null。
  final String? demoCode;

  const SmsSendResult({
    required this.message,
    required this.expiresInSeconds,
    required this.countryCode,
    this.demoCode,
  });

  /// 是否为"演示环境回显了验证码"
  bool get hasDemoCode => demoCode != null && demoCode!.isNotEmpty;
}

/// 认证服务 —— 手机号 + 密码，首次登录自动注册
///
/// 与后端契约（/api/v1/auth/*）：
///   GET  /countries?language=zh|lo → 支持的国家区号列表
///   POST /login    {countryCode, phone, password, nickname?} → {token, registered, user}
///   GET  /me       (Bearer) → user
///   PUT  /profile  (Bearer) → user
///   POST /password (Bearer) {oldPassword, newPassword}
class AuthService {
  final AppConfig config;

  AuthService({required this.config});

  ApiClient get _api => ApiClient(config: config);

  /// 拉取支持的国家区号（失败时返回内置列表，保证登录页可用）
  Future<List<CountryOption>> fetchCountries({String language = 'zh'}) async {
    try {
      final res = await ApiClient(config: config)
          .getRaw('/auth/countries', query: {'language': language});
      final data = res['data'];
      if (data is List && data.isNotEmpty) {
        return data
            .whereType<Map>()
            .map((m) => CountryOption(
                  code: (m['code'] ?? '').toString(),
                  name: (m['name'] ?? '').toString(),
                  flag: (m['flag'] ?? '').toString(),
                ))
            .where((c) => c.code.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // 静默回退：登录页不应因为拉不到国家列表而不可用
    }
    return CountryOption.fallback;
  }

  /// 登录（手机号不存在时后端自动注册）
  ///
  /// 后端可能返回 428（需要短信验证码）→ 抛 [SmsCodeRequiredException]，
  /// 界面应展开验证码输入框后带 [smsCode] 重试。
  Future<LoginOutcome> login({
    required String phone,
    required String password,
    String? nickname,
    String countryCode = CountryOption.defaultCode,
    String? smsCode,
  }) async {
    final deviceId = await DeviceIdentity.get();
    try {
      final data = await _api.post('/auth/login', data: {
        'countryCode': countryCode,
        'phone': phone.trim(),
        'password': password,
        if (nickname != null && nickname.trim().isNotEmpty) 'nickname': nickname.trim(),
        if (smsCode != null && smsCode.trim().isNotEmpty) 'smsCode': smsCode.trim(),
        'deviceUuid': deviceId,
      });

      final token = (data['token'] ?? '').toString();
      if (token.isEmpty) {
        throw const ApiException(-1, '服务器未返回登录令牌');
      }
      final user = UserProfile.fromJson(
          Map<String, dynamic>.from(data['user'] as Map? ?? const {}));
      final registered = data['registered'] == true;

      await UserSession.instance.save(token: token, profile: user);
      return LoginOutcome(profile: user, registered: registered);
    } on ApiException catch (e) {
      // 428 = 需要短信验证码，单独抛出便于界面识别
      if (e.code == 428) {
        throw SmsCodeRequiredException(e.message);
      }
      rethrow;
    }
  }

  /// 请求发送短信验证码
  ///
  /// 返回提示文案与有效期；被限流时抛 [ApiException]（后端返回 429）。
  Future<SmsSendResult> sendSmsCode({
    required String phone,
    String countryCode = CountryOption.defaultCode,
  }) async {
    final deviceId = await DeviceIdentity.get();
    final data = await _api.post('/auth/sms/send', data: {
      'phone': phone.trim(),
      'countryCode': countryCode,
      'deviceUuid': deviceId,
    });
    return SmsSendResult(
      message: (data['message'] ?? '').toString(),
      expiresInSeconds: (data['expires_in_seconds'] as num?)?.toInt() ?? 300,
      countryCode: (data['country_code'] ?? countryCode).toString(),
      demoCode: (data['demo_code'] as String?)?.trim(),
    );
  }

  /// 拉取当前登录用户（冷启动校验令牌是否仍有效）
  Future<UserProfile> fetchMe() async {
    final data = await _api.get('/auth/me');
    final user = UserProfile.fromJson(data);
    await UserSession.instance.updateProfile(user);
    return user;
  }

  /// 更新个人资料
  Future<UserProfile> updateProfile({
    String? nickname,
    String? language,
    String? province,
    String? district,
    String? cropPreferences,
  }) async {
    final data = await _api.put('/auth/profile', data: {
      // 只提交调用方显式传入的字段，未传的字段后端保持原值不变
      // （`?value` 为空时整个条目会被省略）
      'nickname': ?nickname,
      'language': ?language,
      'province': ?province,
      'district': ?district,
      'cropPreferences': ?cropPreferences,
    });
    final user = UserProfile.fromJson(data);
    await UserSession.instance.updateProfile(user);
    return user;
  }

  /// 修改密码（成功后其他设备登录态失效，本机令牌也失效，需重新登录）
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.post('/auth/password', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    // 后端递增了 token_version，本机令牌同样失效，主动清理避免"假登录"
    await UserSession.instance.clear();
  }

  /// 退出登录（仅清本地，后端无状态）
  Future<void> logout() => UserSession.instance.clear();
}
