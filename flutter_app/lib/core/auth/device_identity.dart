import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设备标识 —— 用于判断"是否换设备登录"
///
/// 为什么要它：短信验证码如果每次登录都要，农户会嫌烦（老挝短信还可能要钱）；
/// 但完全不验证又挡不住盗号。折中方案是"**只在换设备时验证**"，
/// 前提就是能稳定识别同一台设备。
///
/// 设计取舍：
///   * 不用 IMEI/ANDROID_ID 等真实硬件标识 —— 需要额外权限，且在隐私合规上更敏感
///   * 改为"首次安装时生成随机 ID 并持久化"，足以区分设备，
///     不收集任何可识别个人的硬件信息
///   * 卸载重装或清除数据后会生成新 ID → 触发一次短信验证。
///     这是**预期行为**：那两个动作本身就意味着"换了设备环境"
///
/// 注意：这个 ID 会随登录请求上传，仅用于安全判定，不用于追踪用户行为。
class DeviceIdentity {
  DeviceIdentity._();

  static const String _key = 'device_uuid';
  static String? _cached;

  /// 同步返回已加载的设备号（未加载过则为 null）
  static String? get cached => _cached;

  /// 获取设备标识，首次调用时生成并持久化
  static Future<String> get() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;
    try {
      final sp = await SharedPreferences.getInstance();
      var id = sp.getString(_key);
      if (id == null || id.isEmpty) {
        id = _generate();
        await sp.setString(_key, id);
        debugPrint('[DeviceIdentity] 已生成新的设备标识');
      }
      _cached = id;
      return id;
    } catch (e) {
      // 持久化失败（如 Web 隐私模式）时退化为内存态：
      // 本次运行内保持一致，避免同一次使用中设备号乱跳导致反复要求验证码
      debugPrint('[DeviceIdentity] 持久化失败，退化为本次运行内有效: $e');
      _cached ??= _generate();
      return _cached!;
    }
  }

  /// 32 位十六进制随机串（不用 UUID 库，减少依赖）
  static String _generate() {
    final rnd = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buf.write(rnd.nextInt(16).toRadixString(16));
    }
    return buf.toString();
  }
}
