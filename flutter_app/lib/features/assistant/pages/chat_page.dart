import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/database/offline_knowledge.dart';

/// AI农业诊断Agent + 离线知识库页面
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final OfflineKnowledge _offline = OfflineKnowledge();

  // 离线知识搜索
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _emptyHint;

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

  // Tab切换
  int _tabIndex = 0; // 0=搜索 1=诊断

  @override
  void initState() {
    super.initState();
    _offline.loadBuiltinData();
    _emptyHint = '${_offline.getAll().length}种病虫害已离线，无网络也能查';
  }

  void _searchOffline(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = _offline.search(query, version: 'vegetable');
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _startDiagnosis() async {
    setState(() {
      _isDiagnosing = true;
      _agentCompleted = false;
      _agentDiagnosis = null;
      _agentStep = 0;
      _agentQuestion = '正在连接诊断服务...';
      _agentQuestionLo = '';
      _agentOptions = [];
    });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final response = await dio.post(
        'http://10.0.2.2:8000/api/v1/diagnosis/diagnose',
        data: {'version': 'vegetable', 'language': 'zh'},
      );
      final data = response.data;
      _updateAgentState(data);
    } catch (e) {
      setState(() {
        _agentQuestion = '诊断服务暂时不可用，请使用离线搜索或拍照识别';
        _agentQuestionLo = 'ບໍລິການບໍ່ສາມາດໃຊ້ໄດ້ຊົ່ວຄາວ';
        _agentOptions = [
          {'value': 'retry', 'label_zh': '重试', 'label_lo': 'ລອງໃໝ່'},
          {'value': 'photo', 'label_zh': '去拍照识别', 'label_lo': 'ຖ່າຍຮູບ'},
        ];
      });
    }
  }

  Future<void> _answerAgent(String answerKey, String answerValue) async {
    setState(() {
      _agentQuestion = '分析中...';
      _agentOptions = [];
    });

    try {
      final dio = Dio();
      final response = await dio.post(
        'http://10.0.2.2:8000/api/v1/diagnosis/diagnose',
        data: {
          'session_id': _agentSessionId,
          'version': 'vegetable',
          'language': 'zh',
          'answer': answerValue,
          'answer_key': answerKey,
        },
      );
      _updateAgentState(response.data);
    } catch (e) {
      setState(() {
        _agentQuestion = '连接失败，请检查网络后重试';
        _agentQuestionLo = '';
        _agentOptions = [{'value': 'retry', 'label_zh': '重试', 'label_lo': 'ລອງໃໝ່'}];
      });
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

      if (data['diagnosis'] != null) {
        _agentDiagnosis = data['diagnosis'] as Map<String, dynamic>;
      }
    });
  }

  void _resetAgent() {
    _startDiagnosis();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI诊断助手'),
        actions: [
          if (_tabIndex == 0)
            IconButton(icon: const Icon(Icons.search), onPressed: () {}, tooltip: '离线搜索'),
        ],
      ),
      body: Column(
        children: [
          // Tab切换
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildTab('🔍 离线搜索', 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTab('🩺 智能诊断', 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tabIndex == 0 ? _buildSearchTab() : _buildDiagnosisTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.green : Colors.grey[300]!),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700])),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '搜索病虫害（支持中文/老挝语）',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  _searchOffline('');
                },
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _searchOffline,
          ),
        ),
        // 提示
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_emptyHint ?? '',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ),
        // 结果列表
        Expanded(
          child: _searchResults.isNotEmpty
              ? ListView.builder(
                  itemCount: _searchResults.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: Icon(item['type'] == 'disease' ? Icons.bug_report : Icons.pest_control,
                            color: item['severity'] == 'severe' ? Colors.red : Colors.orange),
                        title: Text(item['name_zh'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${item['crop_name_zh']} | ${_severityLabel(item['severity'])}',
                            style: const TextStyle(fontSize: 12)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item['symptoms_zh'] != null)
                                  _infoRow('症状', item['symptoms_zh']),
                                if (item['conditions_zh'] != null)
                                  _infoRow('发病条件', item['conditions_zh']),
                                if (item['prevention_zh'] != null)
                                  _infoRow('防治建议', item['prevention_zh']),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text('离线可用，输入关键词搜索', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          _buildQuickCrops(),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildQuickCrops() {
    final crops = _offline.getCropNames('vegetable').take(8).toList();
    return Wrap(
      spacing: 6, runSpacing: 4,
      alignment: WrapAlignment.center,
      children: crops.map((crop) {
        return ActionChip(
          label: Text(crop, style: const TextStyle(fontSize: 12)),
          onPressed: () {
            _searchCtrl.text = crop;
            _searchOffline(crop);
          },
        );
      }).toList(),
    );
  }

  Widget _buildDiagnosisTab() {
    if (!_isDiagnosing && !_agentCompleted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.health_and_safety, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text('AI诊断Agent', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('逐步引导，帮你诊断病虫害', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('回答几个问题 → 给出诊断建议', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startDiagnosis,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始诊断'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 步骤指示
          if (!_agentCompleted)
            Row(
              children: [
                const Icon(Icons.medical_services, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text('诊断第${_agentStep}步',
                    style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: _resetAgent, child: const Text('重新开始')),
              ],
            ),

          const SizedBox(height: 16),

          // 问题
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_agentQuestion, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                if (_agentQuestionLo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_agentQuestionLo, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 拍照建议
          if (_agentImageHelp)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('建议直接拍照识别，获取更准确结果', style: TextStyle(fontSize: 13))),
                ],
              ),
            ),

          // 诊断结果
          if (_agentDiagnosis != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 诊断建议', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_agentDiagnosis!['text_zh'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _resetAgent,
                icon: const Icon(Icons.refresh),
                label: const Text('重新诊断'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
          ],

          // 选项按钮
          if (!_agentCompleted && _agentOptions.isNotEmpty) ...[
            ...(_agentOptions.map((opt) {
              final label = opt['label_zh'] ?? opt['label'] ?? '';
              final labelLo = opt['label_lo'] ?? '';
              final value = opt['value'] ?? '';
              final isDiagnosis = opt['confidence'] != null;
              final confidence = (opt['confidence'] as num?)?.toDouble() ?? 1.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: isDiagnosis
                      ? OutlinedButton(
                          onPressed: () => _answerAgent('disease_choice', value),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                            foregroundColor: confidence > 0.8 ? Colors.green[700] : Colors.orange[700],
                            side: BorderSide(color: confidence > 0.8 ? Colors.green : Colors.orange),
                          ),
                          child: Column(
                            children: [
                              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              if (labelLo.isNotEmpty) Text(labelLo, style: const TextStyle(fontSize: 12)),
                              Text('匹配度 ${(confidence * 100).toInt()}%',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => _answerAgent(
                            _getAnswerKey(_agentStep),
                            value,
                          ),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
                          child: Row(
                            children: [
                              Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
                              if (labelLo.isNotEmpty)
                                Text(labelLo, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              const Icon(Icons.arrow_forward_ios, size: 14),
                            ],
                          ),
                        ),
                ),
              );
            }).toList()),
          ],

          // 完成
          if (_agentCompleted && _agentDiagnosis == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, size: 48, color: Colors.green),
                    const SizedBox(height: 8),
                    const Text('诊断完成'),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _resetAgent,
                        child: const Text('重新诊断')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getAnswerKey(int step) {
    const keys = ['', 'crop', 'symptom_area', 'symptom_type', 'color', 'spread', 'timing', 'environment'];
    return step < keys.length ? keys[step] : 'answer_$step';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  String _severityLabel(String? level) {
    return switch (level) {
      'severe' => '严重',
      'moderate' => '中等',
      'mild' => '轻微',
      _ => '-',
    };
  }
}
