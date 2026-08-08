import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/database/offline_knowledge.dart';

/// 知识库列表页
class KnowledgeListPage extends StatefulWidget {
  final AppConfig config;
  final String language;
  const KnowledgeListPage({super.key, required this.config, this.language = 'zh'});

  @override
  State<KnowledgeListPage> createState() => _KnowledgeListPageState();
}

class _KnowledgeListPageState extends State<KnowledgeListPage> {
  final OfflineKnowledge _offline = OfflineKnowledge();
  final _searchCtrl = TextEditingController();
  String get _l => widget.language;
  String t(String zh, String lo) => _l == 'lo' ? lo : zh;
  String cn(String zh) => _l == 'lo' ? OfflineKnowledge.cropNameLo(zh) : zh;
  List<Map<String, dynamic>> _results = [];
  List<String> _cropNames = [];
  String? _selectedCrop;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _offline.loadBuiltinData();
    _cropNames = _offline.getCropNames(widget.config.version);
  }

  void _search(String q) {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _results = _offline.search(q, version: widget.config.version));
  }

  void _selectCrop(String crop) {
    setState(() => _selectedCrop = crop);
    _results = _offline.getByCrop(crop)
        .where((d) => d['version'] == widget.config.version)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(widget.config.primaryColor);
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl, autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: t('搜索病虫害…', 'ຊອກຫາ…'),
                  hintStyle: const TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: _search,
              )
            : Text(t('知识库', 'ຄວາມຮູ້')),
        backgroundColor: primaryColor, foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () { setState(() { _showSearch = !_showSearch; _searchCtrl.clear(); _results = []; }); },
          ),
        ],
      ),
      body: _showSearch ? _buildSearchResults(primaryColor) : _buildCropList(primaryColor),
    );
  }

  Widget _buildCropList(Color primaryColor) {
    final diseases = widget.config.version == 'vegetable'
        ? ['白菜', '番茄', '辣椒', '黄瓜', '茄子']
        : ['芒果', '香蕉', '荔枝', '柑橘'];

    if (_selectedCrop != null) {
      final cropResults = _offline.getByCrop(_selectedCrop!)
          .where((d) => d['version'] == widget.config.version).toList();
      return Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          color: primaryColor.withValues(alpha: 0.05),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => setState(() => _selectedCrop = null)),
            Text('${cn(_selectedCrop!)} ${t("病虫害", "ພະຍາດ")}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
        Expanded(
          child: cropResults.isEmpty
              ? Center(child: Text(t('暂无数据', 'ບໍ່ມີຂໍ້ມູນ'), style: const TextStyle(color: Colors.grey)))
              : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: cropResults.length,
                  itemBuilder: (_, i) => _buildDiseaseCard(cropResults[i], primaryColor)),
        ),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('常见${widget.config.version == "vegetable" ? "蔬菜" : "果树"}',
              '${widget.config.version == "vegetable" ? "ຜັກ" : "ໝາກໄມ້"} ທົ່ວໄປ'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: diseases.map((crop) => GestureDetector(
          onTap: () { _searchCtrl.clear(); _selectCrop(crop); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor.withValues(alpha: 0.2))),
            child: Text(cn(crop), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primaryColor)),
          ),
        )).toList()),
      ])),
      const Divider(),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(t('所有作物', 'ພືດທັງໝົດ'), style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
      Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: _cropNames.length,
        itemBuilder: (_, i) {
          final crop = _cropNames[i];
          final count = _offline.getByCrop(crop).where((d) => d['version'] == widget.config.version).length;
          return ListTile(
            leading: CircleAvatar(backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.eco, color: primaryColor, size: 20)),
            title: Text(cn(crop), style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(t('$count种', '$count ຊະນິດ'), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ]),
            onTap: () => _selectCrop(crop),
          );
        },
      )),
    ]);
  }

  Widget _buildSearchResults(Color primaryColor) {
    if (_results.isEmpty && _searchCtrl.text.isNotEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, size: 48, color: Colors.grey[400]), const SizedBox(height: 8),
        Text(t('未找到匹配结果', 'ບໍ່ພົບຜົນການຊອກຫາ'), style: const TextStyle(color: Colors.grey)),
      ]));
    }
    if (_results.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]), const SizedBox(height: 8),
        Text(t('输入关键词搜索 或 退出搜索浏览作物', 'ພິມຄຳຄົ້ນຫາ ຫຼື ອອກຈາກການຊອກຫາ'), style: const TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), itemCount: _results.length,
        itemBuilder: (_, i) => _buildDiseaseCard(_results[i], primaryColor));
  }

  Widget _buildDiseaseCard(Map<String, dynamic> item, Color primaryColor) {
    final isPest = item['type'] == 'pest';
    final name = _l == 'lo' && item['name_lo'] != null && (item['name_lo'] as String).isNotEmpty
        ? item['name_lo'] : item['name_zh'] as String;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: isPest ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        child: Icon(isPest ? Icons.pest_control : Icons.bug_report, color: isPest ? Colors.orange : Colors.red, size: 22),
      ),
      title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text('${cn(item['crop_name_zh'] ?? "")} | ${_severity(item['severity'])} | ${isPest ? t("虫害", "ແມງໄມ້") : t("病害", "ພະຍາດ")}',
          style: const TextStyle(fontSize: 12)),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item['symptoms_zh'] != null) ...[
          _label(t('症状', 'ອາການ')),
          Text(_l == 'lo' && item['symptoms_lo'] != null ? item['symptoms_lo'] : item['symptoms_zh'],
              style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 10),
        ],
        if (item['conditions_zh'] != null) ...[
          _label(t('发病条件', 'ເງື່ອນໄຂ')),
          Text(item['conditions_zh'], style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 10),
        ],
        if (item['prevention_zh'] != null) ...[
          _label(t('防治建议', 'ວິທີປ້ອງກັນ')),
          Text(_l == 'lo' && item['prevention_lo'] != null ? item['prevention_lo'] : item['prevention_zh'],
              style: const TextStyle(fontSize: 13, height: 1.5)),
        ],
      ]))],
    ));
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 2),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])));

  String _severity(String? s) => switch (s) {
    'severe' => t('严重', 'ຮຸນແຮງ'), 'moderate' => t('中等', 'ປານກາງ'), 'mild' => t('轻微', 'ເບົາ'), _ => '-',
  };
}
