import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';

/// 设置页面 — 语言切换 + 版本信息 + 关于
class SettingsPage extends StatelessWidget {
  final AppConfig config;
  final String language;
  final void Function(String lang)? onLanguageChanged;
  const SettingsPage({super.key, required this.config, this.language = 'zh', this.onLanguageChanged});

  String t(String zh, String lo) => language == 'lo' ? lo : zh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('设置', 'ຕັ້ງຄ່າ')),
        backgroundColor: Color(config.primaryColor),
        foregroundColor: Colors.white,
      ),
      body: ListView(children: [
        // 语言切换
        _section(t('语言 / Language / ພາສາ', 'ພາສາ'), [
          SwitchListTile(
            secondary: const Icon(Icons.language),
            title: Text(t('当前语言', 'ພາສາປັດຈຸບັນ')),
            subtitle: Text(language == 'zh' ? '中文 (Chinese)' : 'ລາວ (Lao)'),
            value: language == 'lo',
            onChanged: (val) {
              final newLang = val ? 'lo' : 'zh';
              onLanguageChanged?.call(newLang);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(val ? '已切换为老挝语 ປ່ຽນເປັນພາສາລາວ' : '已切换为中文')));
            },
          ),
        ]),

        // 版本信息
        _section(t('关于', 'ກ່ຽວກັບ'), [
          ListTile(leading: const Icon(Icons.info_outline), title: Text(config.appName),
            subtitle: Text(config.version == 'vegetable' ? t('蔬菜病虫害识别与防控', 'ປ້ອງກັນພະຍາດຜັກ') : t('果树病虫害识别与防控', 'ປ້ອງກັນພະຍາດໝາກໄມ້'))),
          ListTile(leading: const Icon(Icons.tag), title: Text(t('版本', 'ເວີຊັນ')), subtitle: const Text('v1.0.0')),
          ListTile(leading: const Icon(Icons.wifi_off), title: Text(t('离线数据', 'ຂໍ້ມູນອອບລາຍ')),
            subtitle: Text(t('16种病虫害(已内置)', '16 ຊະນິດ (ຕິດຕັ້ງແລ້ວ)'))),
          ListTile(leading: const Icon(Icons.palette), title: Text(t('版本类型', 'ປະເພດ')),
            subtitle: Text(config.version == 'vegetable' ? t('蔬菜版 🥬', 'ຜັກ 🥬') : t('果树版 🥭', 'ໝາກໄມ້ 🥭'))),
        ]),

        // 免责声明
        _section(t('免责声明', 'ຂໍ້ປະຕິເສດ'), [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t('本APP提供的病虫害诊断结果仅供参考，不能替代专业农业技术人员的判断。'
                  '使用农药时请严格遵守产品说明书，注意安全间隔期。',
                'ຜົນການວິນິດໄສເປັນພຽງຂໍ້ມູນອ້າງອີງ ບໍ່ສາມາດທົດແທນຜູ້ຊ່ຽວຊານດ້ານກະສິກຳໄດ້.'),
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]))),
      Card(margin: const EdgeInsets.symmetric(horizontal: 12), child: Column(children: children)),
    ]);
  }
}
