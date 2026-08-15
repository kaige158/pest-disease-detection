import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/features/knowledge/pages/content_detail_page.dart';
import 'package:laos_agri_app/shared/widgets/scale_tap.dart';

/// 通知中心 — 病虫害预警 / 图鉴更新 / 系统公告。
class NotificationsPage extends StatelessWidget {
  final AppConfig config;
  final String language;
  const NotificationsPage({super.key, required this.config, required this.language});

  bool get _isZh => language == 'zh';
  String _pick(String zh, String lo) => _isZh ? zh : lo;

  List<_NotifItem> get _items {
    final crop = config.flavor == AppFlavor.vegetable ? '蔬菜' : '果树';
    return [
      _NotifItem(
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFEF6C00),
        titleZh: '雨季病虫害预警',
        titleLo: 'ເຕືອນໄພພະຍາດໃນລະດູຝົນ',
        timeZh: '今天 08:30',
        timeLo: 'ມື້ນີ້ 08:30',
        bodyZh: '当前老挝进入雨季，高温高湿利于$crop病虫害快速蔓延。\n\n'
            '请重点防范叶部与根部病害，加强田间巡查，雨后及时排水。'
            '发现疑似病害可用"拍照识别"上传照片获取防治建议。',
        bodyLo: 'ເຂົ້າສູ່ລະດູຝົນ ຄວນລະວັງພະຍາດ. ໃຊ້ຟັງຊັນຖ່າຍຮູບເພື່ອກວດສອບ.',
      ),
      _NotifItem(
        icon: Icons.auto_awesome,
        color: const Color(0xFF2E7D32),
        titleZh: '新增病害图鉴',
        titleLo: 'ເພີ່ມຮູບພະຍາດໃໝ່',
        timeZh: '昨天 16:00',
        timeLo: 'ມື້ວານ 16:00',
        bodyZh: '知识库新增多种$crop常见病虫害的中老双语资料，'
            '涵盖症状识别与防治建议，欢迎在"知识库"中查阅。',
        bodyLo: 'ເພີ່ມຂໍ້ມູນພະຍາດໃນຄັງຄວາມຮູ້.',
      ),
      _NotifItem(
        icon: Icons.campaign_outlined,
        color: const Color(0xFF1565C0),
        titleZh: '系统公告',
        titleLo: 'ປະກາດລະບົບ',
        timeZh: '3天前',
        timeLo: '3 ມື້ກ່ອນ',
        bodyZh: '感谢使用中老双语农业病虫害识别APP。'
            '本应用由农业专家团队持续维护，识别结果仅供参考，'
            '用药请遵守产品说明与安全间隔期。',
        bodyLo: 'ຂອບໃຈທີ່ໃຊ້ແອັບ. ຜົນການກວດເປັນພຽງຂໍ້ມູນອ້າງອີງ.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(config.primaryColor);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_pick('通知中心', 'ການແຈ້ງເຕືອນ')),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _items.map((n) => _card(context, n, primary)).toList(),
      ),
    );
  }

  Widget _card(BuildContext context, _NotifItem n, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ScaleTap(
        pressedScale: 0.97,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ContentDetailPage(
            config: config,
            language: language,
            titleZh: n.titleZh,
            titleLo: n.titleLo,
            bodyText: _isZh ? n.bodyZh : n.bodyLo,
          ),
        )),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: n.color.withValues(alpha: 0.12),
                child: Icon(n.icon, color: n.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _pick(n.titleZh, n.titleLo),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(_pick(n.timeZh, n.timeLo), style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isZh ? n.bodyZh : n.bodyLo,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifItem {
  final IconData icon;
  final Color color;
  final String titleZh, titleLo, timeZh, timeLo, bodyZh, bodyLo;
  const _NotifItem({
    required this.icon,
    required this.color,
    required this.titleZh,
    required this.titleLo,
    required this.timeZh,
    required this.timeLo,
    required this.bodyZh,
    required this.bodyLo,
  });
}
