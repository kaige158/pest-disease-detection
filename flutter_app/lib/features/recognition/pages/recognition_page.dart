import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/features/recognition/pages/result_page.dart';

/// 拍照识病页面 — 农业用户易懂的拍照识别
class RecognitionPage extends StatefulWidget {
  final AppConfig config;
  final String language;
  const RecognitionPage({super.key, required this.config, this.language = 'zh'});

  @override
  State<RecognitionPage> createState() => _RecognitionPageState();
}

class _RecognitionPageState extends State<RecognitionPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;

  /// 演示模式 — 编译时通过 --dart-define=DEMO_MODE=true 开启。
  /// 开启后识别不请求后端，直接返回演示结果（用于无服务器的UI演示APK）。
  static const bool _demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);

  String get _l => widget.language;
  String t(String zh, String lo) => _l == 'lo' ? lo : zh;

  Future<void> _pickFromCamera() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 800);
      if (image != null) setState(() => _selectedImage = image);
    } catch (e) {
      _showError(t('无法打开相机', 'ບໍ່ສາມາດເປີດກ້ອງຖ່າຍຮູບໄດ້'));
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
      if (image != null) setState(() => _selectedImage = image);
    } catch (e) {
      _showError(t('无法打开相册', 'ບໍ່ສາມາດເປີດຮູບພາບໄດ້'));
    }
  }

  Future<void> _uploadAndIdentify() async {
    if (_selectedImage == null) return;
    setState(() => _isUploading = true);

    // 演示模式：模拟AI分析耗时后返回演示结果，不请求后端
    if (_demoMode) {
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() => _isUploading = false);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResultPage(
          resultData: _buildDemoResult(),
          config: widget.config,
          imagePath: _selectedImage!.path,
          language: _l,
        ),
      ));
      return;
    }

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 30)));
      final response = await dio.post('http://10.0.2.2:8080/api/v1/recognition/identify',
          data: {'image': base64Image, 'version': widget.config.version, 'language': _l});
      if (!mounted) return;

      final data = response.data;
      if (data['code'] == 200 && data['data'] != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ResultPage(resultData: data['data'], config: widget.config, imagePath: _selectedImage!.path, language: _l)));
      } else {
        _showError(data['message'] ?? t('识别失败', 'ກວດສອບບໍ່ສຳເລັດ'));
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        _showError(t('无法连接服务器', 'ບໍ່ສາມາດເຊື່ອມຕໍ່ເຊີບເວີໄດ້'));
      } else {
        _showError(t('识别失败', 'ກວດສອບບໍ່ສຳເລັດ: ${e.message}'));
      }
    } catch (e) {
      _showError(t('发生错误', 'ເກີດຂໍ້ຜິດພາດ: $e'));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red[700]));
  }

  /// 演示模式识别结果 — 按版本返回一个真实感的示例（标注"演示"）
  Map<String, dynamic> _buildDemoResult() {
    final isVeg = widget.config.version == 'vegetable';
    return {
      'task_id': 'demo',
      'results': isVeg
          ? {
              'disease_name_zh': '番茄晚疫病（演示）',
              'disease_name_lo': 'ພະຍາດໃບໄໝ້ໝາກເລັ່ນ',
              'confidence': 0.92,
              'symptoms_zh': '叶片出现暗绿色水渍状病斑，边缘不清晰，湿度大时背面产生白色霉层；'
                  '果实产生褐色硬质病斑，迅速扩大导致腐烂。',
              'symptoms_lo': 'ໃບມີຈຸດສີຂຽວເຂັ້ມຄ້າຍນ້ຳ ດ້ານຫຼັງມີເຊື້ອຣາສີຂາວ.',
              'conditions_zh': '低温高湿、连续阴雨、昼夜温差大时最易流行。',
              'severity': 'severe',
              'need_expert_review': false,
              'prevention': {
                'chemical': [
                  {'method_zh': '发病初期喷施代森锰锌', 'details_zh': '每隔7～10天一次，连续2～3次，注意轮换用药。'},
                  {'method_zh': '严重时选用霜脲·锰锌', 'details_zh': '严格遵守安全间隔期，采收前禁用。'},
                ],
                'cultivation': [
                  {'method_zh': '及时排水、加强通风', 'details_zh': '降低田间湿度，摘除病叶病果并集中销毁。'},
                  {'method_zh': '合理密植', 'details_zh': '避免植株过密，保持通风透光。'},
                ],
              },
            }
          : {
              'disease_name_zh': '芒果炭疽病（演示）',
              'disease_name_lo': 'ພະຍາດແອນແທຣກໂນສໝາກມ່ວງ',
              'confidence': 0.89,
              'symptoms_zh': '叶片、花穗和果实出现黑褐色病斑，果实近成熟时病斑扩大凹陷，'
                  '潮湿时病斑上产生粉红色黏质孢子堆。',
              'symptoms_lo': 'ໃບ ດອກ ແລະ ໝາກ ມີຈຸດສີດຳ ເມື່ອຊຸ່ມມີສະປໍສີບົວ.',
              'conditions_zh': '高温多雨、果园郁闭、通风不良时发病重。',
              'severity': 'moderate',
              'need_expert_review': false,
              'prevention': {
                'chemical': [
                  {'method_zh': '花期及幼果期喷施咪鲜胺', 'details_zh': '每隔10～14天一次，雨后补喷。'},
                ],
                'cultivation': [
                  {'method_zh': '修剪郁闭枝、清除病果病叶', 'details_zh': '改善通风透光，减少侵染源。'},
                  {'method_zh': '果实套袋保护', 'details_zh': '减少病菌接触，提高果实品质。'},
                ],
              },
            },
    };
  }

  /// 版本差异化快捷作物
  Widget _buildQuickCrops() {
    final primary = Color(widget.config.primaryColor);
    final crops = widget.config.version == 'vegetable'
        ? [('🥬', t('白菜', 'ຜັກກາດ')), ('🍅', t('番茄', 'ໝາກເລັ່ນ')), ('🌶️', t('辣椒', 'ໝາກເຜັດ')), ('🥒', t('黄瓜', 'ໝາກແຕງ'))]
        : [('🥭', t('芒果', 'ໝາກມ່ວງ')), ('🍌', t('香蕉', 'ກ້ວຍ')), ('🍒', t('荔枝', 'ໝາກລິ້ນຈີ່')), ('🍊', t('柑橘', 'ໝາກກ້ຽງ'))];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: crops.map((c) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: ActionChip(
              avatar: Text(c.$1, style: const TextStyle(fontSize: 14)),
              label: Text(c.$2, style: const TextStyle(fontSize: 13)),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t('已选: ${c.$2}，拍照优先匹配', 'ເລືອກ: ${c.$2}')))),
              backgroundColor: primary.withValues(alpha: 0.06),
            ),
          )).toList(),
        ),
      ),
    );
  }

  /// 版本差异化提醒卡片
  Widget _buildAlertCard() {
    final primary = Color(widget.config.primaryColor);
    final isVeg = widget.config.version == 'vegetable';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary.withValues(alpha: 0.12), primary.withValues(alpha: 0.04)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Text(isVeg ? '🌱' : '🌳', style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isVeg ? t('今日蔬菜病害提醒', 'ເຕືອນພະຍາດຜັກມື້ນີ້') : t('果树健康管理', 'ການດູແລສຸຂະພາບຕົ້ນໄມ້'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          Text(isVeg ? t('高温注意茄果类晚疫病', 'ອາກາດຮ້ອນ ລະວັງພະຍາດໃບໄໝ້') : t('本月芒果炭疽病高发', 'ເດືອນນີ້ພະຍາດແອນແທຣກໂນສລະບາດຫຼາຍ'),
              style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ])),
        Icon(Icons.warning_amber, color: primary, size: 24),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(widget.config.primaryColor);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('拍照识病', 'ກວດພະຍາດ')),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(children: [
          _buildAlertCard(),
          _buildQuickCrops(),
          const SizedBox(height: 8),
          // 图片区域
          Expanded(
            child: Container(
              width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!)),
              child: _selectedImage != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_selectedImage!.path), fit: BoxFit.contain))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.camera_alt, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(t('拍照识别病虫害', 'ຖ່າຍຮູບກວດພະຍາດ'), style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      Text(t('拍照或从相册上传叶片照片', 'ຖ່າຍຮູບ ຫຼື ເລືອກຮູບໃບໄມ້'), style: TextStyle(color: Colors.grey[500])),
                    ]),
            ),
          ),
          if (_isUploading)
            const Padding(padding: EdgeInsets.all(8), child: Column(children: [
              CircularProgressIndicator(), SizedBox(height: 8),
              Text('AI正在分析...', style: TextStyle(color: Colors.grey)),
            ])),
          // 按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _isUploading ? null : _pickFromCamera, icon: const Icon(Icons.camera_alt), label: Text(t('拍照', 'ຖ່າຍຮູບ')))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(onPressed: _isUploading ? null : _pickFromGallery, icon: const Icon(Icons.photo_library), label: Text(t('相册', 'ຮູບພາບ')))),
            ]),
          ),
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadAndIdentify,
                  icon: const Icon(Icons.search), label: Text(t('开始识别', 'ເລີ່ມກວດສອບ'), style: const TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
