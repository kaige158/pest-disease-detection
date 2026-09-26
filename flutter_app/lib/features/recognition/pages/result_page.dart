import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/network/api_client.dart';
import 'package:laos_agri_app/shared/widgets/image_loader.dart';

/// 识别结果展示页 — MVP核心页面
///
/// 数据来源两种形态都支持：
///   1. 真实后端（Spring Boot `/recognition/identify`）：扁平字段，如 `disease_name_zh`
///   2. 演示模式（`--dart-define=DEMO_MODE=true`）：包了一层 `results`
/// 通过 [_pickResults] 统一取到字段所在的那一层。
class ResultPage extends StatelessWidget {
  final Map<String, dynamic> resultData;
  final AppConfig config;
  final String imagePath;
  final String language;

  const ResultPage({
    super.key,
    required this.resultData,
    required this.config,
    required this.imagePath,
    this.language = 'zh',
  });

  bool get _isZh => language == 'zh';

  String t(String zh, String lo) => _isZh ? zh : lo;

  /// 按当前语言取字段：优先本语言，缺失时回退中文（老挝语内容可能尚未入库）
  String _field(Map<String, dynamic> r, String base) {
    final localised = r['${base}_$language'];
    if (localised is String && localised.isNotEmpty) return localised;
    final zh = r['${base}_zh'];
    return zh is String ? zh : '';
  }

  /// 演示模式的数据包在 `results` 里，真实后端的数据是扁平的
  static Map<String, dynamic> _pickResults(Map<String, dynamic> raw) {
    final nested = raw['results'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return raw;
  }

  /// 提交用户反馈到后端 API
  Future<void> _submitFeedback(BuildContext context, String feedback) async {
    final taskId = (resultData['task_id'] ?? '').toString();
    if (taskId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务ID缺失，无法提交反馈')),
      );
      return;
    }

    // 演示模式：本地提示，不请求后端
    if (taskId == 'demo') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedback == 'confirmed'
              ? t('感谢反馈！（演示模式）', 'ຂອບໃຈ！(ໂໝດສາທິດ)')
              : t('已记录，将提交专家复核（演示模式）', 'ບັນທຶກແລ້ວ (ໂໝດສາທິດ)')),
          backgroundColor: feedback == 'confirmed' ? Colors.green : Colors.orange,
        ),
      );
      return;
    }

    try {
      await ApiClient(config: config).submitFeedback(
        taskId: taskId,
        feedback: feedback,
        note: feedback == 'confirmed' ? '用户确认结果正确' : '用户认为结果不正确',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedback == 'confirmed'
              ? t('感谢反馈！结果已记录', 'ຂອບໃຈ! ບັນທຶກແລ້ວ')
              : t('已记录，将提交专家复核', 'ບັນທຶກແລ້ວ ຈະສົ່ງໃຫ້ຜູ້ຊ່ຽວຊານກວດ')),
          backgroundColor: feedback == 'confirmed' ? Colors.green : Colors.orange,
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t('反馈提交失败', 'ສົ່ງຄຳຄິດເຫັນບໍ່ສຳເລັດ')}: ${e.message}'),
            backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t('反馈提交失败', 'ສົ່ງຄຳຄິດເຫັນບໍ່ສຳເລັດ')}: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _pickResults(resultData);
    final disease = _field(results, 'disease_name');
    final diseaseAlt = _isZh
        ? (results['disease_name_lo'] ?? '').toString()
        : (results['disease_name_zh'] ?? '').toString();
    final confidence = (results['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidencePercent = (confidence * 100).toStringAsFixed(0);
    final symptoms = _field(results, 'symptoms');
    final symptomsAlt = _isZh
        ? (results['symptoms_lo'] ?? '').toString()
        : (results['symptoms_zh'] ?? '').toString();
    final conditions = _field(results, 'conditions');
    final severity = (results['severity'] ?? 'moderate').toString();
    final prevention = results['prevention'] is Map
        ? Map<String, dynamic>.from(results['prevention'] as Map)
        : <String, dynamic>{};
    final needExpert = results['need_expert_review'] == true;

    final confidenceColor = confidence >= 0.90
        ? Colors.green
        : confidence >= 0.70
            ? Colors.orange
            : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('识别结果', 'ຜົນການກວດສອບ')),
        backgroundColor: Color(config.primaryColor),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片预览（跨平台：Android/iOS 读文件，Web 读字节）
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(color: Colors.black),
              child: buildLocalImage(imagePath, fit: BoxFit.contain),
            ),


            // 识别结果卡片
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 病虫害名称 + 置信度
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(disease,
                                    style: const TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.bold)),
                                if (diseaseAlt.isNotEmpty)
                                  Text(diseaseAlt,
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          // 置信度圆环
                          SizedBox(
                            width: 70,
                            height: 70,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: CircularProgressIndicator(
                                    value: confidence,
                                    strokeWidth: 6,
                                    backgroundColor: Colors.grey[200],
                                    color: confidenceColor,
                                  ),
                                ),
                                Text('$confidencePercent%',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: confidenceColor)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // 置信度级别提示
                      if (needExpert)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('该结果置信度较低，建议专家复核确认',
                                    style: TextStyle(color: Colors.orange)),
                              ),
                            ],
                          ),
                        ),

                      // 症状描述
                      if (symptoms.isNotEmpty) ...[
                        _buildSectionTitle(t('症状描述', 'ອາການ'), Icons.visibility),
                        const SizedBox(height: 4),
                        Text(symptoms, style: const TextStyle(fontSize: 14, height: 1.5)),
                        if (symptomsAlt.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(symptomsAlt,
                                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // 发病条件
                      if (conditions.isNotEmpty) ...[
                        _buildSectionTitle(t('发病条件', 'ເງື່ອນໄຂການເກີດພະຍາດ'), Icons.thermostat),
                        const SizedBox(height: 4),
                        Text(conditions, style: const TextStyle(fontSize: 14, height: 1.5)),
                        const SizedBox(height: 16),
                      ],

                      // 严重程度
                      _buildSectionTitle(t('严重程度', 'ລະດັບຄວາມຮຸນແຮງ'), Icons.warning),
                      const SizedBox(height: 4),
                      _SeverityBadge(severity: severity, language: language),
                      const SizedBox(height: 16),

                      // 防控方案
                      if (prevention.isNotEmpty) ...[
                        _buildSectionTitle(t('防控方案', 'ແຜນການປ້ອງກັນ'), Icons.healing),
                        const SizedBox(height: 8),
                        ..._buildPreventionList(prevention),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // 反馈按钮 — Sprint 10.2: 真实API调用
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _submitFeedback(context, 'confirmed'),
                      icon: const Icon(Icons.thumb_up, color: Colors.green),
                      label: const Text('结果正确'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _submitFeedback(context, 'disputed'),
                      icon: const Icon(Icons.thumb_down, color: Colors.red),
                      label: const Text('结果不正确'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Color(config.primaryColor)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  List<Widget> _buildPreventionList(Map<String, dynamic> prevention) {
    final widgets = <Widget>[];
    final categories = {
      'chemical': (t('化学防治', 'ການປ້ອງກັນທາງເຄມີ'), Icons.science),
      'biological': (t('生物防治', 'ການປ້ອງກັນທາງຊີວະພາບ'), Icons.eco),
      'physical': (t('物理防治', 'ການປ້ອງກັນທາງກາຍະພາບ'), Icons.handyman),
      'cultivation': (t('栽培管理', 'ການຈັດການການປູກ'), Icons.agriculture),
    };

    for (final entry in categories.entries) {
      final items = prevention[entry.key] as List<dynamic>? ?? [];
      if (items.isEmpty) continue;

      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(entry.value.$2, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(entry.value.$1,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700])),
          ],
        ),
      ));

      for (final item in items) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final method = _localised(map, 'method');
          final details = _localised(map, 'details');
          widgets.add(Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method, style: const TextStyle(fontSize: 14)),
                      if (details.isNotEmpty)
                        Text(details,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ));
        }
      }
    }

    return widgets;
  }

  /// 防控条目字段：`method_zh/lo`、`details_zh/lo`
  String _localised(Map<String, dynamic> map, String base) {
    final localised = map['${base}_$language'];
    if (localised is String && localised.isNotEmpty) return localised;
    final zh = map['${base}_zh'];
    return zh is String ? zh : '';
  }
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  final String language;
  const _SeverityBadge({required this.severity, this.language = 'zh'});

  @override
  Widget build(BuildContext context) {
    final zh = language == 'zh';
    final (label, color) = switch (severity) {
      'severe' => (zh ? '严重' : 'ຮຸນແຮງ', Colors.red),
      'moderate' => (zh ? '中等' : 'ປານກາງ', Colors.orange),
      _ => (zh ? '轻微' : 'ເລັກນ້ອຍ', Colors.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
