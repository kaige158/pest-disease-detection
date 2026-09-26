import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laos_agri_app/shared/models/user_profile.dart';

/// 登录态 —— 全局唯一，令牌与用户资料的共同持有者
///
/// 设计要点：
///   1. 令牌在内存里同步可读（Dio 拦截器每发一个请求都要读，不能是异步的）
///   2. 持久化到 SharedPreferences，冷启动时 [restore] 恢复登录态
///   3. 令牌失效（后端返回 401/403）时由拦截器调用 [clear]，界面自动回到未登录
///
/// 为什么不用 provider/riverpod：本项目已有 provider 依赖，但登录态是
/// "基础设施"级别的东西（网络层也要读），用 ChangeNotifier 单例更直接，
/// 避免网络层反向依赖 UI 状态容器。
class UserSession extends ChangeNotifier {
  UserSession._();

  static final UserSession instance = UserSession._();

  static const String _kToken = 'auth_token';
  static const String _kUser = 'auth_user';

  String? _token;
  UserProfile? _profile;
  bool _restored = false;

  /// 当前令牌（未登录为 null）
  String? get token => _token;

  /// 当前用户（未登录为 null）
  UserProfile? get profile => _profile;

  /// 是否已登录
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  /// 是否已完成冷启动恢复（避免首帧误判为未登录而跳登录页）
  bool get restored => _restored;

  /// 昵称兜底展示名
  String get displayName {
    final p = _profile;
    if (p == null) return '';
    if (p.nickname.isNotEmpty) return p.nickname;
    return p.phone;
  }

  /// 冷启动恢复登录态（main 里 await 一次）
  Future<void> restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final token = sp.getString(_kToken);
      final userJson = sp.getString(_kUser);
      if (token != null && token.isNotEmpty) {
        _token = token;
        if (userJson != null && userJson.isNotEmpty) {
          _profile = UserProfile.fromJson(_decode(userJson));
        }
      }
    } catch (e) {
      debugPrint('[UserSession] 恢复登录态失败: $e');
    } finally {
      _restored = true;
      notifyListeners();
    }
  }

  /// 登录成功后写入
  Future<void> save({required String token, required UserProfile profile}) async {
    _token = token;
    _profile = profile;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kToken, token);
      await sp.setString(_kUser, _encode(profile));
    } catch (e) {
      debugPrint('[UserSession] 持久化登录态失败: $e');
    }
  }

  /// 仅更新用户资料（改昵称/语言后调用）
  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kUser, _encode(profile));
    } catch (e) {
      debugPrint('[UserSession] 持久化用户资料失败: $e');
    }
  }

  /// 退出登录 / 令牌失效
  Future<void> clear() async {
    _token = null;
    _profile = null;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kToken);
      await sp.remove(_kUser);
    } catch (e) {
      debugPrint('[UserSession] 清理登录态失败: $e');
    }
  }

  // ---- JSON 编解码 ----
  static Map<String, dynamic> _decode(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[UserSession] 解析本地用户资料失败: $e');
    }
    return {};
  }

  static String _encode(UserProfile p) => jsonEncode({
        'id': p.id,
        'uuid': p.uuid,
        'phone': p.phone,
        'nickname': p.nickname,
        'avatar_url': p.avatarUrl,
        'role': p.role,
        'language': p.language,
        'region_province': p.regionProvince,
        'region_district': p.regionDistrict,
        'crop_preferences': p.cropPreferences,
        'is_active': p.isActive,
        'login_count': p.loginCount,
        'last_login_at': p.lastLoginAt,
        'created_at': p.createdAt,
      });
}
