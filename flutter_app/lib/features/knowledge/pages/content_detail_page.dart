import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/database/offline_knowledge.dart';

/// 通用内容详情页 — 作物 / 病害 / 资讯共用。
///
/// 设计目标：即使暂无正式资料，点击也能进入对应页面，
/// 展示已有的离线数据 + "资料建设中"占位区块（后续补实物图和资料）。
class ContentDetailPage extends StatelessWidget {
  final AppConfig config;
  final String language;
  final String titleZh;
  final String titleLo;

  /// 作物 emoji（作物详情用）
  final String? emoji;

  /// 病害照片资源路径（轮播病害详情用）
  final String? imagePath;

  /// 作物名（中文）— 提供后会加载该作物的离线病虫害数据
  final String? cropName;

  /// 正文文本（资讯详情用）
  final String? bodyText;

  const ContentDetailPage({
    super.key,
    required this.config,
    required this.language,
    required this.titleZh,
    required this.titleLo,
    this.emoji,
    this.imagePath,
    this.cropName,
    this.bodyText,
  });

  bool get _isZh => language == 'zh';
  String _pick(String zh, String lo) => _isZh ? zh : (lo.isEmpty ? zh : lo);

  @override
  Widget build(BuildContext context) {
    final primary = Color(config.primaryColor);
    final diseases = cropName != null ? _loadDiseases() : <Map<String, dynamic>>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_pick(titleZh, titleLo)),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          _buildHero(primary),
          if (bodyText != null) _buildBodyText(),
          if (diseases.isNotEmpty) ...[
            _sectionTitle(_pick('常见病虫害', 'ພະຍາດ & ແມງໄມ້'), primary),
            ...diseases.map((d) => _diseaseCard(d, primary)),
          ],
          // 占位区块 —— 后续补充
          _sectionTitle(_pick('实物图鉴', 'ຮູບຕົວຈິງ'), primary),
          _placeholder(
            Icons.photo_camera_outlined,
            _pick('实物图片资料建设中', 'ກຳລັງກະກຽມຮູບພາບ'),
            _pick('后续将上传真实照片供对照识别', 'ຈະອັບໂຫຼດຮູບຈິງໃນພາຍຫຼັງ'),
          ),
          _sectionTitle(_pick('种植与防治资料', 'ຂໍ້ມູນການປູກ & ປ້ອງກັນ'), primary),
          _placeholder(
            Icons.menu_book_outlined,
            _pick('详细资料完善中', 'ກຳລັງເພີ່ມຂໍ້ມູນ'),
            _pick('敬请期待栽培要点、病害图谱与用药建议', 'ຕິດຕາມຂໍ້ມູນການດູແລ & ຢາປ້ອງກັນ'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _loadDiseases() {
    final offline = OfflineKnowledge()..loadBuiltinData();
    return offline
        .getByCrop(cropName!)
        .where((d) => d['version'] == config.version)
        .toList();
  }

  // ─── 顶部主视觉 ───────────────────────────────────────────────
  Widget _buildHero(Color primary) {
    if (imagePath != null) {
      return SizedBox(
        height: 200,
        width: double.infinity,
        child: Image.asset(
          imagePath!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
          ),
        ),
      );
    }
    // 作物 emoji 主视觉
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primary.withValues(alpha: 0.18), primary.withValues(alpha: 0.04)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji ?? '🌱', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 8),
          Text(
            _pick(titleZh, titleLo),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
          ),
          if (!_isZh || titleLo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _isZh ? titleLo : titleZh,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBodyText() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text(bodyText!, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF333333))),
    );
  }

  Widget _sectionTitle(String text, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF212121))),
        ],
      ),
    );
  }

  Widget _placeholder(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey[350]),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[400]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _diseaseCard(Map<String, dynamic> item, Color primary) {
    final isPest = item['type'] == 'pest';
    final name = !_isZh && item['name_lo'] != null && (item['name_lo'] as String).isNotEmpty
        ? item['name_lo']
        : item['name_zh'] as String;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (isPest ? Colors.orange : Colors.red).withValues(alpha: 0.1),
          child: Icon(isPest ? Icons.pest_control : Icons.bug_report, color: isPest ? Colors.orange : Colors.red, size: 22),
        ),
        title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        subtitle: Text(isPest ? _pick('虫害', 'ແມງໄມ້') : _pick('病害', 'ພະຍາດ'), style: const TextStyle(fontSize: 12)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['symptoms_zh'] != null) ...[
                  _label(_pick('症状', 'ອາການ')),
                  Text(!_isZh && item['symptoms_lo'] != null ? item['symptoms_lo'] : item['symptoms_zh'],
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                  const SizedBox(height: 10),
                ],
                if (item['prevention_zh'] != null) ...[
                  _label(_pick('防治建议', 'ວິທີປ້ອງກັນ')),
                  Text(!_isZh && item['prevention_lo'] != null ? item['prevention_lo'] : item['prevention_zh'],
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      );
}
