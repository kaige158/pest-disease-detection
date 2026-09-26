// 端到端测试公共工具 —— 与"运行中的真实后端"打交道的那部分能力
//
// 抽出来的原因：认证 e2e 测试与持久化格式导出测试都要走
// "首次登录需要短信验证码" 这条真实链路，逻辑必须只有一份（DRY）。
//
// 运行前提：后端已启动，且 API_BASE_URL 指向它：
//   flutter test --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:laos_agri_app/core/auth/auth_service.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/network/api_client.dart';

/// 每次运行用不同手机号，避免与历史数据冲突（后端强制手机号唯一）
///
/// **必须带随机数**：`flutter test` 会并行跑多个测试文件，
/// 它们共用同一个真实后端。早期只用时间戳（毫秒 % 1e8），
/// 两个文件在同一毫秒生成同一个号码 → 互相把对方注册掉，
/// 表现为"随机某个用例偶发失败"。加随机段后碰撞概率可忽略。
String uniquePhone() {
  final rand = Random();
  final tail = rand.nextInt(90000000) + 10000000; // 8 位，首位非 0
  return '020$tail';
}

/// 从后端日志读取某号码最近一条短信验证码（兜底方案）
///
/// 正常路径不用它 —— 演示档的发送接口会直接回显验证码（见 [loginWithSms]）。
/// 只有"通道未接入且接口没回显"时才需要翻日志。
///
/// 匹配 [phone] 的后 8 位，而不是简单取最后一条：`flutter test` 会并行跑多个
/// 测试文件，日志里随时可能插入别的用例的验证码，取最后一条会串号。
///
/// 解码用 latin1：Java 日志在中文 Windows 上是 GBK、Linux 上是 UTF-8，
/// 而这行标记全是 ASCII，ASCII 字节在任何编码下都一致，无需猜编码。
String? readSmsCodeFromLog(String phone) {
  final candidates = [
    File(r'F:\lao-cn-APP\spring-backend\demo_run.log'),
    File('../spring-backend/demo_run.log'),
    File('spring-backend/demo_run.log'),
  ];
  final suffix = phone.replaceAll(RegExp(r'\D'), '');
  final key = suffix.length >= 8 ? suffix.substring(suffix.length - 8) : suffix;

  for (final f in candidates) {
    if (!f.existsSync()) continue;
    final text = latin1.decode(f.readAsBytesSync());
    final matches = RegExp(r'\[DEMO-SMS\] code=(\d{6}) country=\d+ phone=(\d+)')
        .allMatches(text)
        .where((m) => m.group(2)!.endsWith(key))
        .toList();
    if (matches.isNotEmpty) return matches.last.group(1);
  }
  return null;
}

/// 登录（自动处理"需要短信验证码"的情况）
///
/// 演示档开启了强制验证码，因此新号码首次登录必定抛 428；
/// 这里模拟真实 APP 的流程：发码 → 取码 → 带码重试。
Future<LoginOutcome> loginWithSms(AuthService auth,
    {required String phone,
    String password = 'laos2026',
    String? nickname,
    String countryCode = '856'}) async {
  try {
    return await auth.login(
        phone: phone,
        password: password,
        nickname: nickname,
        countryCode: countryCode);
  } on SmsCodeRequiredException {
    final sent = await auth.sendSmsCode(phone: phone, countryCode: countryCode);
    // 优先用接口回显的验证码（与 APP 登录页走的是同一条路径）；
    // 没回显才退回翻日志，保证在生产式配置下也不至于直接崩
    final code = sent.demoCode ?? readSmsCodeFromLog(phone);
    if (code == null) {
      throw StateError('需要短信验证码，但既没有 demo_code 回显、日志里也没有该号码的 '
          '[DEMO-SMS] 行（请确认演示档后端正在运行，且已用最新代码重启）');
    }
    return await auth.login(
        phone: phone,
        password: password,
        nickname: nickname,
        countryCode: countryCode,
        smsCode: code);
  }
}

/// 后端是否可达 —— 调一次真实登录接口，只要能返回结构化响应即视为在线
/// （用非法手机号，不会产生任何数据）
Future<bool> backendReachable() async {
  try {
    await AuthService(config: AppConfig.vegetable).login(phone: 'x', password: 'x');
    return true;
  } on ApiException {
    return true; // 能拿到业务错误说明服务在线
  } catch (_) {
    return false; // 网络层异常（连接被拒/超时）说明服务不在
  }
}
