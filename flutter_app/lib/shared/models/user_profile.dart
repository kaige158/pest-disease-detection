/// 用户资料模型 —— 与后端 `UserPublicView` 字段一一对应
///
/// 注意：后端只回传脱敏手机号（如 `0205****234`），明文手机号不下发。
class UserProfile {
  final int id;
  final String uuid;
  final String phone;
  final String nickname;
  final String avatarUrl;
  final String role;
  final String language;
  final String regionProvince;
  final String regionDistrict;
  final String cropPreferences;
  final bool isActive;
  final int loginCount;
  final String? lastLoginAt;
  final String? createdAt;

  /// 国际区号（856=老挝 86=中国…），后端未拆分的历史数据为空
  final String countryCode;

  /// 带区号的脱敏号码（如 `+856 0205****234`），后端直接给好，界面无需再拼
  final String phoneDisplay;

  /// 是否需要提醒改密（初始密码或被管理员重置后为 true）
  final bool mustChangePassword;

  const UserProfile({
    required this.id,
    required this.uuid,
    required this.phone,
    required this.nickname,
    required this.avatarUrl,
    required this.role,
    required this.language,
    required this.regionProvince,
    required this.regionDistrict,
    required this.cropPreferences,
    required this.isActive,
    required this.loginCount,
    this.countryCode = '',
    this.phoneDisplay = '',
    this.mustChangePassword = false,
    this.lastLoginAt,
    this.createdAt,
  });

  /// 界面展示用号码：优先用后端给的带区号脱敏串
  String get phoneLabel => phoneDisplay.isNotEmpty ? phoneDisplay : phone;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      nickname: (json['nickname'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? '').toString(),
      role: (json['role'] ?? 'FARMER').toString(),
      countryCode: (json['country_code'] ?? '').toString(),
      phoneDisplay: (json['phone_display'] ?? '').toString(),
      mustChangePassword: json['must_change_password'] == true,
      language: (json['language'] ?? 'lo').toString(),
      regionProvince: (json['region_province'] ?? '').toString(),
      regionDistrict: (json['region_district'] ?? '').toString(),
      cropPreferences: (json['crop_preferences'] ?? '[]').toString(),
      isActive: json['is_active'] != false,
      loginCount: (json['login_count'] as num?)?.toInt() ?? 0,
      lastLoginAt: json['last_login_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  /// 角色的双语展示名
  String roleLabel(String language) {
    final zh = language == 'zh';
    return switch (role) {
      'ADMIN' => zh ? '平台管理员' : 'ຜູ້ດູແລລະບົບ',
      'EXPERT' => zh ? '农业专家' : 'ຜູ້ຊ່ຽວຊານກະສິກຳ',
      'TECHNICIAN' => zh ? '农技员' : 'ພະນັກງານສົ່ງເສີມກະສິກຳ',
      _ => zh ? '农户' : 'ຊາວກະສິກອນ',
    };
  }

  /// 用于「我的」页展示的所在地
  String get regionLabel {
    if (regionProvince.isEmpty && regionDistrict.isEmpty) return '';
    if (regionDistrict.isEmpty) return regionProvince;
    if (regionProvince.isEmpty) return regionDistrict;
    return '$regionProvince · $regionDistrict';
  }
}
