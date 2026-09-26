import 'package:flutter/material.dart';

import 'package:laos_agri_app/core/auth/auth_service.dart';
import 'package:laos_agri_app/core/auth/user_session.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/network/api_client.dart';
import 'package:laos_agri_app/features/auth/pages/login_page.dart';
import 'package:laos_agri_app/shared/models/user_profile.dart';

/// 个人中心 —— 资料维护 + 改密码 + 语言偏好 + 退出登录
///
/// 未登录时展示"登录后可同步数据"的引导，任何功能都不会被强制拦截。
class ProfilePage extends StatefulWidget {
  final AppConfig config;
  final String language;
  final void Function(String lang)? onLanguageChanged;

  const ProfilePage({
    super.key,
    required this.config,
    this.language = 'zh',
    this.onLanguageChanged,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nickCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  bool _busy = false;

  String get _l => widget.language;
  String t(String zh, String lo) => _l == 'zh' ? zh : lo;
  Color get _primary => Color(widget.config.primaryColor);
  AuthService get _auth => AuthService(config: widget.config);

  @override
  void dispose() {
    _nickCtrl.dispose();
    _provinceCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _goLogin() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => LoginPage(config: widget.config, language: _l),
    ));
    if (ok == true && mounted) setState(() {});
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('退出登录', 'ອອກຈາກລະບົບ')),
        content: Text(t('退出后识别记录仍保存在服务器，重新登录即可查看。',
            'ປະຫວັດຍັງຢູ່ໃນເຊີບເວີ, ເຂົ້າຄືນໄດ້')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('取消', 'ຍົກເລີກ'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('确认退出', 'ຢືນຢັນ'))),
        ],
      ),
    );
    if (confirmed == true) {
      await _auth.logout();
      if (mounted) setState(() {});
    }
  }

  /// 编辑资料（昵称 / 省份 / 县）
  Future<void> _editProfile(UserProfile p) async {
    _nickCtrl.text = p.nickname;
    _provinceCtrl.text = p.regionProvince;
    _districtCtrl.text = p.regionDistrict;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('编辑资料', 'ແກ້ໄຂຂໍ້ມູນ'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _nickCtrl,
              decoration: InputDecoration(
                labelText: t('称呼', 'ຊື່ເອີ້ນ'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _provinceCtrl,
              decoration: InputDecoration(
                labelText: t('省份（如 万象）', 'ແຂວງ'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _districtCtrl,
              decoration: InputDecoration(
                labelText: t('县/区（可选）', 'ເມືອງ (ບໍ່ບັງຄັບ)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: Colors.white, minimumSize: const Size(0, 46)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('保存', 'ບັນທຶກ')),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    setState(() => _busy = true);
    try {
      await _auth.updateProfile(
        nickname: _nickCtrl.text.trim(),
        province: _provinceCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t('资料已保存', 'ບັນທຶກແລ້ວ')), backgroundColor: Colors.green));
      }
    } on ApiException catch (e) {
      _snack('${t('保存失败', 'ບັນທຶກບໍ່ສຳເລັດ')}: ${e.message}', Colors.red);
    } catch (e) {
      _snack(t('网络异常，请稍后重试', 'ເຄືອຂ່າຍຜິດພາດ'), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 修改密码
  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('修改密码', 'ປ່ຽນລະຫັດຜ່ານ')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: oldCtrl,
            obscureText: true,
            decoration: InputDecoration(labelText: t('原密码', 'ລະຫັດເກົ່າ')),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: newCtrl,
            obscureText: true,
            decoration: InputDecoration(labelText: t('新密码（至少6位）', 'ລະຫັດໃໝ່')),
          ),
          const SizedBox(height: 8),
          Text(t('修改后需要重新登录', 'ຫຼັງປ່ຽນແລ້ວຕ້ອງເຂົ້າຄືນ'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('取消', 'ຍົກເລີກ'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('确认', 'ຢືນຢັນ'))),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _auth.changePassword(
        oldPassword: oldCtrl.text.trim(),
        newPassword: newCtrl.text.trim(),
      );
      _snack(t('密码已修改，请重新登录', 'ປ່ຽນສຳເລັດ, ກະລຸນາເຂົ້າຄືນ'), Colors.green);
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      _snack(e.message, Colors.red);
    } catch (e) {
      _snack(t('网络异常，请稍后重试', 'ເຄືອຂ່າຍຜິດພາດ'), Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSession.instance;
    final p = session.profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('我的', 'ຂອງຂ້ອຍ')),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _header(session, p),
          if (session.isLoggedIn && p != null) ...[
            _sectionTitle(t('账号', 'ບັນຊີ')),
            _tile(
              icon: Icons.person_outline,
              title: t('编辑资料', 'ແກ້ໄຂຂໍ້ມູນ'),
              subtitle: p.nickname.isEmpty ? null : p.nickname,
              onTap: _busy ? null : () => _editProfile(p),
            ),
            _tile(
              icon: Icons.lock_outline,
              title: t('修改密码', 'ປ່ຽນລະຫັດຜ່ານ'),
              onTap: _busy ? null : _changePassword,
            ),
          ],
          _sectionTitle(t('偏好', 'ການຕັ້ງຄ່າ')),
          _languageTile(session),
          if (session.isLoggedIn)
            _tile(
              icon: Icons.logout,
              title: t('退出登录', 'ອອກຈາກລະບົບ'),
              danger: true,
              onTap: _busy ? null : _logout,
            ),

          _sectionTitle(t('关于', 'ກ່ຽວກັບ')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(widget.config.appName),
                subtitle: Text(widget.config.version == 'vegetable'
                    ? t('蔬菜病虫害识别与防控', 'ປ້ອງກັນພະຍາດຜັກ')
                    : t('果树病虫害识别与防控', 'ປ້ອງກັນພະຍາດໝາກໄມ້')),
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: Text(t('版本', 'ເວີຊັນ')),
                subtitle: const Text('v1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.wifi_off),
                title: Text(t('离线数据', 'ຂໍ້ມູນອອບລາຍ')),
                subtitle: Text(t('无需网络也能查询病虫害',
                    'ບໍ່ມີເຄືອຂ່າຍກໍ່ຄົ້ນຫາໄດ້')),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Text(
              t('本APP提供的病虫害诊断结果仅供参考，不能替代专业农业技术人员的判断。'
                  '使用农药时请严格遵守产品说明书，注意安全间隔期。',
                  'ຜົນການວິນິດໄສເປັນພຽງຂໍ້ມູນອ້າງອີງ ບໍ່ສາມາດທົດແທນຜູ້ຊ່ຽວຊານໄດ້.'),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(UserSession session, UserProfile? p) {
    if (!session.isLoggedIn || p == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Icon(Icons.account_circle, size: 56, color: _primary),
          const SizedBox(height: 10),
          Text(t('还没有登录', 'ຍັງບໍ່ໄດ້ເຂົ້າສູ່ລະບົບ'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            t('登录后识别记录保存在云端，换手机也不丢',
                'ຫຼັງເຂົ້າລະບົບ ປະຫວັດຈະຖືກບັນທຶກໄວ້'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _goLogin,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: Colors.white),
              child: Text(t('登录 / 注册', 'ເຂົ້າສູ່ລະບົບ / ລົງທະບຽນ')),
            ),
          ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          _primary.withValues(alpha: 0.16),
          _primary.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: _primary,
          child: Text(
            p.nickname.isNotEmpty ? p.nickname.characters.first : '🌾',
            style: const TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(session.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(p.roleLabel(_l),
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(p.phoneLabel, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            if (p.regionLabel.isNotEmpty)
              Text(p.regionLabel, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(
              t('已识别 ${p.loginCount} 次登录', 'ເຂົ້າສູ່ລະບົບ ${p.loginCount} ຄັ້ງ'),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _languageTile(UserSession session) {
    final current = session.profile?.language ?? _l;
    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(t('语言 / ພາສາ', 'ພາສາ / 语言')),
      subtitle: Text(current == 'zh' ? '中文' : 'ລາວ (老挝语)'),
      trailing: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'zh', label: Text('中文')),
          ButtonSegment(value: 'lo', label: Text('ລາວ')),
        ],
        selected: {current == 'zh' ? 'zh' : 'lo'},
        onSelectionChanged: (s) => _switchLanguage(s.first, session),
      ),
    );
  }

  Future<void> _switchLanguage(String lang, UserSession session) async {
    widget.onLanguageChanged?.call(lang);
    if (!session.isLoggedIn) return;
    try {
      await _auth.updateProfile(language: lang);
    } catch (_) {
      // 语言偏好同步失败不影响本地切换，静默处理避免打扰用户
    }
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool danger = false,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        leading: Icon(icon, color: danger ? Colors.red : null),
        title: Text(title, style: TextStyle(color: danger ? Colors.red : null)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
