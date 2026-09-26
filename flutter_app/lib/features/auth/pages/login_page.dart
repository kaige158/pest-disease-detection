import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:laos_agri_app/core/auth/auth_service.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/config/environment.dart';
import 'package:laos_agri_app/core/network/api_client.dart';

/// 登录 / 注册页 —— 手机号 + 密码，首次登录自动注册
///
/// 产品决策（贴合老挝农户实际）：
///   * 不做短信验证码：老挝短信通道不稳定且需额外采购，首版用手机号+密码跑通用户体系
///   * 登录与注册同一个入口：农户分不清"注册/登录"，输一次凭据即可，不存在则自动建号
///   * 必须提供「先逛逛」：知识库/识别等核心价值不登录也能用，避免因登录流失用户，
///     登录只在"需要沉淀个人数据"时（历史记录、反馈、偏好同步）才要求
class LoginPage extends StatefulWidget {
  final AppConfig config;
  final String language;

  /// 是否允许跳过（作为独立页面被 push 时为 true；作为强制登录页时为 false）
  final bool allowSkip;

  const LoginPage({
    super.key,
    required this.config,
    this.language = 'zh',
    this.allowSkip = true,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _nickCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _obscure = true;
  bool _isRegisterMode = false;
  String? _error;

  /// 是否需要短信验证码（后端返回 428 时置位）
  bool _smsNeeded = false;
  /// 需要验证码的原因（"首次使用该号码" / "检测到在新设备登录"）
  String _smsReason = '';
  final _smsCtrl = TextEditingController();
  /// 重新发送倒计时（秒），>0 表示冷却中
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  /// 演示环境回显的验证码（非空时界面提示"已自动填入"）；生产环境恒为 null
  String? _demoCodeNotice;

  String get _l => widget.language;
  String t(String zh, String lo) => _l == 'zh' ? zh : lo;

  late final AuthService _auth = AuthService(config: widget.config);
  Color get _primary => Color(widget.config.primaryColor);

  /// 国家/地区（区号）—— 登录前从后端拉取，失败用内置列表，保证登录页不依赖网络
  List<CountryOption> _countries = CountryOption.fallback;
  String _countryCode = CountryOption.defaultCode;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final list = await _auth.fetchCountries(language: _l);
    if (!mounted || list.isEmpty) return;
    setState(() {
      _countries = list;
      if (!_countries.any((c) => c.code == _countryCode)) {
        _countryCode = _countries.first.code;
      }
    });
  }

  CountryOption get _selectedCountry => _countries.firstWhere(
        (c) => c.code == _countryCode,
        orElse: () => _countries.first,
      );

  /// 选择国家区号 —— 平台面向老挝，但用户会跨国流动（中国技术员、泰国客商等）
  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(t('选择国家 / 地区', 'ເລືອກປະເທດ / ພາກພື້ນ'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ..._countries.map((c) => ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(c.name),
                  trailing: Text('+${c.code}',
                      style: TextStyle(
                          color: c.code == _countryCode ? _primary : Colors.grey[600],
                          fontWeight: c.code == _countryCode ? FontWeight.bold : null)),
                  onTap: () => Navigator.pop(ctx, c.code),
                )),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _countryCode = picked);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pwdCtrl.dispose();
    _nickCtrl.dispose();
    _smsCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // 需要验证码时，验证码本身也要填
    if (_smsNeeded && _smsCtrl.text.trim().isEmpty) {
      setState(() => _error = t('请输入短信验证码', 'ກະລຸນາໃສ່ລະຫັດ SMS'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final outcome = await _auth.login(
        phone: _phoneCtrl.text,
        password: _pwdCtrl.text,
        nickname: _isRegisterMode ? _nickCtrl.text : null,
        countryCode: _countryCode,
        smsCode: _smsNeeded ? _smsCtrl.text : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(outcome.registered
            ? t('注册成功，欢迎使用！', 'ລົງທະບຽນສຳເລັດ, ຍິນດີຕ້ອນຮັບ!')
            : t('登录成功', 'ເຂົ້າສູ່ລະບົບສຳເລັດ')),
        backgroundColor: Colors.green,
      ));
      Navigator.of(context).pop(true);
    } on SmsCodeRequiredException catch (e) {
      // 后端要求验证码（首次注册 / 换设备）→ 展开验证码输入并自动发一条
      if (!mounted) return;
      setState(() {
        _smsNeeded = true;
        _smsReason = e.reason;
        _error = null;
      });
      await _sendSmsCode(auto: true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      // 连不上后端是外场最常见问题，提示里带上当前地址便于现场排障
      setState(() => _error = t(
        '无法连接服务器，请检查网络\n当前地址: ${AppEnvironment.springApiBaseUrl}',
        'ບໍ່ສາມາດເຊື່ອມຕໍ່ເຊີບເວີໄດ້',
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 发送验证码
  ///
  /// [auto] 为 true 表示是"后端要求验证码"后自动触发，失败时不弹错误提示打断用户，
  /// 而是让用户自己点「重新发送」——避免自动请求被限流时反复报错。
  Future<void> _sendSmsCode({bool auto = false}) async {
    if (_resendCooldown > 0) return;
    try {
      final r = await _auth.sendSmsCode(
        phone: _phoneCtrl.text,
        countryCode: _countryCode,
      );
      if (!mounted) return;
      _startCooldown(60);

      // 开发/演示环境：后端把验证码回显了（生产环境不会有这个字段）。
      // 自动填入并继续登录 —— 老挝短信通道还没接入，否则演示时谁都登不进去。
      if (r.hasDemoCode) {
        _smsCtrl.text = r.demoCode!;
        setState(() => _demoCodeNotice = r.demoCode);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('演示环境：验证码 $r.demoCode 已自动填入',
              'ສະພາບທົດລອງ: ລະຫັດ $r.demoCode ຖືກໃສ່ໃຫ້ແລ້ວ')),
          backgroundColor: Colors.orange[800],
          duration: const Duration(seconds: 5),
        ));
        if (_smsNeeded && !_busy) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          if (mounted) await _submit();
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      // 限流（429）时后端会告知还需等待多久，这里也启动倒计时避免用户狂点
      if (e.code == 429) {
        final wait = RegExp(r'(\d+)\s*秒').firstMatch(e.message);
        _startCooldown(wait != null ? int.parse(wait.group(1)!) : 60);
      }
      if (!auto) {
        setState(() => _error = e.message);
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (mounted && !auto) {
        setState(() => _error = t('验证码发送失败，请稍后重试',
            'ສົ່ງລະຫັດບໍ່ສຳເລັດ'));
      }
    }
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('登录 / 注册', 'ເຂົ້າສູ່ລະບົບ / ລົງທະບຽນ')),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: widget.allowSkip,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 品牌头
                Center(
                  child: Column(children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.agriculture, size: 42, color: _primary),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.config.appName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      t('用手机号登录，首次使用自动创建账号',
                          'ເຂົ້າສູ່ລະບົບດ້ວຍເບີໂທ, ໃຊ້ຄັ້ງທຳອິດຈະສ້າງບັນຊີອັດຕະໂນມັດ'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t('支持多国号码，点左侧区号可切换',
                          'ຮອງຮັບເບີຫຼາຍປະເທດ, ກົດລະຫັດປະເທດເພື່ອປ່ຽນ'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // 手机号 —— 前缀为可点击的国家区号选择器
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: t('手机号', 'ເບີໂທ'),
                    hintText: _countryCode == '856' ? '2055551234' : '',
                    prefixIcon: InkWell(
                      onTap: _busy ? null : _pickCountry,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_selectedCountry.flag, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 4),
                          Text('+$_countryCode',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: _primary)),
                          const Icon(Icons.arrow_drop_down, size: 18),
                        ]),
                      ),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return t('请输入手机号', 'ກະລຸນາໃສ່ເບີໂທ');
                    if (s.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
                      return t('号码位数不足', 'ເບີໂທສັ້ນເກີນໄປ');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 密码
                TextFormField(
                  controller: _pwdCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: t('密码', 'ລະຫັດຜ່ານ'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return t('请输入密码', 'ກະລຸນາໃສ່ລະຫັດຜ່ານ');
                    if (s.length < 6) return t('密码至少 6 位', 'ລະຫັດຜ່ານຢ່າງໜ້ອຍ 6 ຕົວ');
                    return null;
                  },
                ),

                // 昵称（仅注册模式）
                if (_isRegisterMode) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nickCtrl,
                    inputFormatters: [LengthLimitingTextInputFormatter(20)],
                    decoration: InputDecoration(
                      labelText: t('称呼（可选）', 'ຊື່ເອີ້ນ (ບໍ່ບັງຄັບ)'),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],

                // 短信验证码（仅在后端要求时出现：首次注册 / 换设备登录）
                if (_smsNeeded) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(children: [
                      const Icon(Icons.sms_outlined, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _smsReason.isNotEmpty
                              ? _smsReason
                              : t('为确认手机号归你本人所有，请填写短信验证码',
                                  'ກະລຸນາໃສ່ລະຫັດ SMS ເພື່ອຢືນຢັນເບີໂທ'),
                          style: const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _smsCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: t('短信验证码', 'ລະຫັດ SMS'),
                          prefixIcon: const Icon(Icons.password),
                          border: const OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: (_busy || _resendCooldown > 0)
                            ? null
                            : () => _sendSmsCode(),
                        child: Text(
                          _resendCooldown > 0
                              ? t('$_resendCooldown s 后重发', 'ອີກ $_resendCooldown ວິ')
                              : t('重新发送', 'ສົ່ງຄືນ'),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ]),

                  // 演示环境提示：短信通道未接入，验证码是后端回显的
                  if (_demoCodeNotice != null) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.science_outlined, size: 16, color: Colors.orange[800]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          t('当前为演示环境（未接入短信通道），验证码 $_demoCodeNotice 已自动填入',
                              'ສະພາບທົດລອງ: ລະຫັດ $_demoCodeNotice ຖືກໃສ່ໃຫ້ແລ້ວ'),
                          style: TextStyle(color: Colors.orange[800], fontSize: 12),
                        ),
                      ),
                    ]),
                  ],
                ],

                // 错误提示
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 22),

                // 主按钮
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isRegisterMode
                                ? t('注册并登录', 'ລົງທະບຽນ ແລະ ເຂົ້າສູ່ລະບົບ')
                                : t('登录', 'ເຂົ້າສູ່ລະບົບ'),
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _isRegisterMode = !_isRegisterMode;
                            _error = null;
                          }),
                  child: Text(
                    _isRegisterMode
                        ? t('已有账号？直接登录', 'ມີບັນຊີແລ້ວ? ເຂົ້າສູ່ລະບົບ')
                        : t('第一次使用？填个称呼即可', 'ໃຊ້ຄັ້ງທຳອິດ? ຕື່ມຊື່ເອີ້ນ'),
                  ),
                ),

                if (widget.allowSkip) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: Text(t('先逛逛（不登录也能识别和查知识库）',
                        'ເບິ່ງກ່ອນ (ບໍ່ເຂົ້າລະບົບກໍ່ໃຊ້ໄດ້)')),
                  ),
                ],

                const SizedBox(height: 16),
                Text(
                  t('登录后识别记录会保存在云端，换手机也不丢',
                      'ຫຼັງເຂົ້າລະບົບ ປະຫວັດການກວດຈະຖືກບັນທຶກໄວ້'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
