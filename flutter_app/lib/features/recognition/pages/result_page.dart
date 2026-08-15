import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';

/// 识别结果展示页 — MVP核心页面
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

  String t(String zh, String lo) => language == 'lo' ? lo : zh;

  /// 提交用户反馈到后端 API
  Future<void> _submitFeedback(BuildContext context, String feedback) async {
    final taskId = resultData['task_id'] ?? '';
    if (taskId.toString().isEmpty) {
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
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      await dio.post(
        'http://10.0.2.2:8080/api/v1/recognition/$taskId/feedback',
        data: jsonEncode({
          'feedback': feedback,
          'note': feedback == 'confirmed' ? '用户确认结果正确' : '用户认为结果不正确',
        }),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedback == 'confirmed' ? '感谢反馈！结果已记录' : '已记录，将提交专家复核'),
            backgroundColor: feedback == 'confirmed' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('反馈提交失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = resultData['results'] as Map<String, dynamic>? ?? resultData;
    final disease = results['disease_name_zh'] ?? '未知';
    final diseaseLo = results['disease_name_lo'] ?? '';
    final confidence = (results['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidencePercent = (confidence * 100).toStringAsFixed(0);
    final symptoms = results['symptoms_zh'] ?? '';
    final symptomsLo = results['symptoms_lo'] ?? '';
    final conditions = results['conditions_zh'] ?? '';
    final severity = results['severity'] ?? 'moderate';
    final prevention = results['prevention'] as Map<String, dynamic>? ?? {};
    final needExpert = results['need_expert_review'] == true;
    // final confidenceLevel = results['confidence_level'] ?? 'medium';  // reserved for future use

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
            // 图片预览
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                image: imagePath.isNotEmpty
                    ? DecorationImage(
                        image: FileImage(File(imagePath)),
                        fit: BoxFit.contain,
                      )
                    : null,
              ),
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
                                if (diseaseLo.isNotEmpty)
                                  Text(diseaseLo,
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
                        _buildSectionTitle('症状描述', Icons.visibility),
                        const SizedBox(height: 4),
                        Text(symptoms, style: const TextStyle(fontSize: 14, height: 1.5)),
                        if (symptomsLo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(symptomsLo,
                                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // 发病条件
                      if (conditions.isNotEmpty) ...[
                        _buildSectionTitle('发病条件', Icons.thermostat),
                        const SizedBox(height: 4),
                        Text(conditions, style: const TextStyle(fontSize: 14, height: 1.5)),
                        const SizedBox(height: 16),
                      ],

                      // 严重程度
                      _buildSectionTitle('严重程度', Icons.warning),
                      const SizedBox(height: 4),
                      _SeverityBadge(severity: severity),
                      const SizedBox(height: 16),

                      // 防控方案
                      if (prevention.isNotEmpty) ...[
                        _buildSectionTitle('防控方案', Icons.healing),
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
      'chemical': ('化学防治', Icons.science),
      'biological': ('生物防治', Icons.eco),
      'physical': ('物理防治', Icons.handyman),
      'cultivation': ('栽培管理', Icons.agriculture),
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
                      Text(item['method_zh'] ?? '',
                          style: const TextStyle(fontSize: 14)),
                      if (item['details_zh']?.isNotEmpty == true)
                        Text(item['details_zh'],
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
}

class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (severity) {
      'severe' => ('严重', Colors.red),
      'moderate' => ('中等', Colors.orange),
      _ => ('轻微', Colors.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
