import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/database/offline_knowledge.dart';

/// AI农业诊断Agent + 离线知识库页面
class ChatPage extends StatefulWidget {
  final AppConfig config;
  final String language;
  const ChatPage({super.key, required this.config, this.language = 'zh'});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final OfflineKnowledge _offline = OfflineKnowledge();
  String get _l => widget.language;
  String t(String zh, String lo) => _l == 'lo' ? lo : zh;

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  int _tabIndex = 0;

  // 诊断Agent
  bool _isDiagnosing = false;
  bool _agentCompleted = false;
  String _agentSessionId = '';
  String _agentQuestion = '';
  String _agentQuestionLo = '';
  List<Map<String, dynamic>> _agentOptions = [];
  bool _agentImageHelp = false;
  Map<String, dynamic>? _agentDiagnosis;
  int _agentStep = 0;

  @override
  void initState() {
    super.initState();
    _offline.loadBuiltinData();
  }

  void _searchOffline(String query) {
    if (query.trim().isEmpty) { setState(() => _searchResults = []); return; }
    setState(() => _searchResults = _offline.search(query, version: widget.config.version));
  }

  Future<void> _startDiagnosis() async {
    setState(() { _isDiagnosing = true; _agentCompleted = false; _agentDiagnosis = null; _agentStep = 0;
      _agentQuestion = t('正在连接...', 'ກຳລັງເຊື່ອມຕໍ່...'); _agentQuestionLo = ''; _agentOptions = []; });
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 15)));
      final response = await dio.post('http://10.0.2.2:8000/api/v1/diagnosis/diagnose',
          data: {'version': widget.config.version, 'language': _l});
      _updateAgentState(response.data);
    } catch (e) {
      setState(() {
        _agentQuestion = t('诊断服务暂不可用', 'ບໍລິການບໍ່ສາມາດໃຊ້ໄດ້ຊົ່ວຄາວ');
        _agentQuestionLo = ''; _agentOptions = [
          {'value': 'retry', 'label': t('重试', 'ລອງໃໝ່')},
          {'value': 'photo', 'label': t('去拍照识别', 'ຖ່າຍຮູບ')},
        ];
      });
    }
  }

  Future<void> _answerAgent(String answerKey, String answerValue) async {
    setState(() { _agentQuestion = t('分析中...', 'ກຳລັງວິເຄາະ...'); _agentOptions = []; });
    try {
      final dio = Dio();
      final response = await dio.post('http://10.0.2.2:8000/api/v1/diagnosis/diagnose', data: {
        'session_id': _agentSessionId, 'version': widget.config.version, 'language': _l,
        'answer': answerValue, 'answer_key': answerKey,
      });
      _updateAgentState(response.data);
    } catch (e) {
      setState(() { _agentQuestion = t('连接失败，请重试', 'ເຊື່ອມຕໍ່ບໍ່ໄດ້'); _agentOptions = [
        {'value': 'retry', 'label': t('重试', 'ລອງໃໝ່')}]; });
    }
  }

  void _updateAgentState(Map<String, dynamic> data) {
    setState(() {
      _agentSessionId = data['session_id'] ?? '';
      _agentStep = data['step'] ?? 0;
      _agentCompleted = data['completed'] ?? false;
      _agentQuestion = data['question_text_zh'] ?? '';
      _agentQuestionLo = data['question_text_lo'] ?? '';
      _agentImageHelp = data['image_help'] ?? false;
      final options = data['options'] as List<dynamic>? ?? [];
      _agentOptions = options.map((o) => o as Map<String, dynamic>).toList();
      if (data['diagnosis'] != null) _agentDiagnosis = data['diagnosis'] as Map<String, dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('AI助手', 'ຜູ້ຊ່ວຍ AI')), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          Expanded(child: _buildTab(t('🔍 离线搜索', '🔍 ຄົ້ນຫາ'), 0)),
          const SizedBox(width: 8),
          Expanded(child: _buildTab(t('🩺 智能诊断', '🩺 ວິນິດໄສ'), 1)),
        ])),
        Expanded(child: _tabIndex == 0 ? _buildSearchTab() : _buildDiagnosisTab()),
      ]),
    );
  }

  Widget _buildTab(String label, int index) {
    final sel = _tabIndex == index;
    return GestureDetector(onTap: () => setState(() => _tabIndex = index), child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: sel ? Colors.green : Colors.grey[100], borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? Colors.green : Colors.grey[300]!)),
      child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey[700])),
    ));
  }

  Widget _buildSearchTab() => Column(children: [
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(hintText: t('搜索病虫害（中文/老挝语）', 'ຊອກຫາ (ຈີນ/ລາວ)'),
          prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _searchOffline(''); })),
      onChanged: _searchOffline,
    )),
    Padding(padding: const EdgeInsets.all(8), child: Text(
      t('${_offline.getAll().length}种病虫害已离线', '${_offline.getAll().length} ຊະນິດ (ອອບລາຍ)'),
      style: TextStyle(fontSize: 12, color: Colors.grey[500]))),
    Expanded(child: _searchResults.isNotEmpty
        ? ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _searchResults.length,
            itemBuilder: (_, i) => _diseaseCard(_searchResults[i]))
        : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]), const SizedBox(height: 8),
            Text(t('离线可用，输入关键词搜索', 'ອອບລາຍ, ພິມຄຳຄົ້ນຫາ'), style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, alignment: WrapAlignment.center, children: _offline.getCropNames(widget.config.version).take(6).map((c) =>
              ActionChip(label: Text(c, style: const TextStyle(fontSize: 12)), onPressed: () { _searchCtrl.text = c; _searchOffline(c); })).toList()),
          ]))),
  ]);

  Widget _diseaseCard(Map<String, dynamic> item) {
    final isPest = item['type'] == 'pest';
    final name = (_l == 'lo' && item['name_lo'] != null && (item['name_lo'] as String).isNotEmpty) ? item['name_lo'] : item['name_zh'] ?? '';
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ExpansionTile(
      leading: Icon(isPest ? Icons.pest_control : Icons.bug_report, color: isPest ? Colors.orange : Colors.red),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('${item['crop_name_zh'] ?? ""} | ${t("病害", "ພະຍາດ")}', style: const TextStyle(fontSize: 12)),
      children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (item['symptoms_zh'] != null) _row(t('症状', 'ອາການ'), item['symptoms_zh']),
        if (item['conditions_zh'] != null) _row(t('条件', 'ເງື່ອນໄຂ'), item['conditions_zh']),
        if (item['prevention_zh'] != null) _row(t('防治', 'ປ້ອງກັນ'), item['prevention_zh']),
      ]))],
    ));
  }

  Widget _row(String label, String val) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
      Text(val, style: const TextStyle(fontSize: 13, height: 1.4)),
    ]));

  Widget _buildDiagnosisTab() {
    if (!_isDiagnosing && !_agentCompleted) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.health_and_safety, size: 64, color: Colors.green), const SizedBox(height: 16),
        Text(t('AI诊断Agent', 'AI ວິນິດໄສ'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t('逐步引导，帮你诊断病虫害', 'ຖາມຕອບເທື່ອລະຂັ້ນຕອນ'), style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Text(t('回答几个问题 → 给出诊断建议', 'ຕອບຄຳຖາມ → ໄດ້ຜົນວິນິດໄສ'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(onPressed: _startDiagnosis, icon: const Icon(Icons.play_arrow),
          label: Text(t('开始诊断', 'ເລີ່ມວິນິດໄສ')),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14))),
      ]));
    }
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!_agentCompleted) Row(children: [
        const Icon(Icons.medical_services, color: Colors.green, size: 20), const SizedBox(width: 8),
        Text(t('诊断第$_agentStep步', 'ຂັ້ນຕອນ $_agentStep'), style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w600)),
        const Spacer(), TextButton(onPressed: _startDiagnosis, child: Text(t('重新开始', 'ເລີ່ມໃໝ່'))),
      ]),
      const SizedBox(height: 12),
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[200]!)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_agentQuestion, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (_agentQuestionLo.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_agentQuestionLo, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
        ])),
      if (_agentImageHelp) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
        child: Row(children: [const Icon(Icons.camera_alt, color: Colors.blue, size: 20), const SizedBox(width: 8),
          Expanded(child: Text(t('建议拍照获取更准确结果', 'ແນະນຳໃຫ້ຖ່າຍຮູບ'), style: const TextStyle(fontSize: 13)))]),
      ),
      if (_agentDiagnosis != null) ...[
        const SizedBox(height: 12),
        Container(width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('📋 诊断建议', '📋 ຜົນວິນິດໄສ'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8), Text(_agentDiagnosis!['text_zh'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
          ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _startDiagnosis,
          icon: const Icon(Icons.refresh), label: Text(t('重新诊断', 'ວິນິດໄສໃໝ່')),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white))),
      ],
      if (!_agentCompleted && _agentOptions.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final opt in _agentOptions)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: SizedBox(width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _answerAgent(_agentStep == 1 ? 'crop' : _agentStep == 2 ? 'symptom_area' : _agentStep == 3 ? 'symptom_type' : 'answer_$_agentStep', opt['value'] ?? ''),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)), child: Row(children: [
                Expanded(child: Text(_l == 'lo' && (opt['label_lo'] ?? '').isNotEmpty ? opt['label_lo'] : opt['label_zh'] ?? opt['label'] ?? '', style: const TextStyle(fontSize: 15))),
                const Icon(Icons.arrow_forward_ios, size: 14),
              ])),
          )),
      ],
    ]));
  }

}
