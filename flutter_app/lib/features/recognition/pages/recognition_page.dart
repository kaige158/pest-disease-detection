import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/config/environment.dart';
import 'package:laos_agri_app/core/network/api_client.dart';
import 'package:laos_agri_app/features/recognition/pages/result_page.dart';
import 'package:laos_agri_app/shared/widgets/image_loader.dart';

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

  /// 用户预选的作物（可为空=不限定），随识别请求上传给后端
  int? _selectedCropId;

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
    final image = _selectedImage;
    if (image == null) return;
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
          imagePath: image.path,
          language: _l,
        ),
      ));
      return;
    }

    try {
      // 统一走 ApiClient：后端地址来自 AppEnvironment，multipart 字段与 Java 侧对齐
      final bytes = await image.readAsBytes();
      final data = await ApiClient(config: widget.config).identify(
        imageBytes: bytes,
        filename: image.name.isEmpty ? 'photo.jpg' : image.name,
        language: _l,
        cropId: _selectedCropId,
      );
      if (!mounted) return;

      if (data.isEmpty) {
        _showError(t('识别服务未返回结果', 'ບໍ່ມີຜົນການກວດສອບ'));
        return;
      }
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ResultPage(
          resultData: data,
          config: widget.config,
          imagePath: image.path,
          language: _l,
        ),
      ));
    } on ApiException catch (e) {
      _showError('${t('识别失败', 'ກວດສອບບໍ່ສຳເລັດ')}: ${e.message}');
    } catch (e) {
      // 连不上后端是外场最常见的问题，提示里带上当前地址，便于现场排障
      _showError(t(
        '无法连接服务器，请检查网络\n当前地址: ${AppEnvironment.springApiBaseUrl}',
        'ບໍ່ສາມາດເຊື່ອມຕໍ່ເຊີບເວີໄດ້',
      ));
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

  /// 版本差异化快捷作物 — (emoji, 中文名, 老挝语名, 后端 crop_id)
  /// crop_id 与数据库 `core.crop.id` 对齐，选中后随识别请求上传，缩小 AI 判定范围。
  List<(String, String, String, int?)> get _quickCrops =>
      widget.config.version == 'vegetable'
          ? [
              ('🥬', '白菜', 'ຜັກກາດຂາວ', 4),
              ('🍅', '番茄', 'ໝາກເລັ່ນ', 2),
              ('🌶️', '辣椒', 'ໝາກເຜັດ', 1),
              ('🥒', '黄瓜', 'ໝາກແຕງ', 3),
            ]
          : [
              ('🥭', '芒果', 'ໝາກມ່ວງ', 7),
              ('🍌', '香蕉', 'ກ້ວຍ', 6),
              ('🍊', '柑橘', 'ໝາກກ້ຽງ', 8),
            ];

  void _toggleCrop(int? cropId) {
    setState(() => _selectedCropId = _selectedCropId == cropId ? null : cropId);
    if (cropId == null) return;
    final crop = _quickCrops.firstWhere((c) => c.$4 == cropId, orElse: () => ('', '', '', null));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t('已选定作物：${crop.$2}，识别将优先匹配',
          'ເລືອກພືດແລ້ວ: ${crop.$3}')),
      duration: const Duration(seconds: 2),
    ));
  }

  /// 版本差异化快捷作物
  Widget _buildQuickCrops() {
    final primary = Color(widget.config.primaryColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 6),
              child: Text(t('作物(可选)', 'ພືດ (ທາງເລືອກ)'),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            ..._quickCrops.map((c) {
              final selected = _selectedCropId == c.$4;
              final name = _l == 'zh' ? c.$2 : c.$3;
              // 这里刻意不用 ActionChip：Flutter Web (CanvasKit) 下
              // Chip 的 label 会被压缩到不可见（实测语义树里也没有该节点），
              // 自绘容器可以完全控制布局，行为一致且各平台渲染稳定。
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => _toggleCrop(c.$4),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? primary : primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? primary : primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      '${c.$1} $name',
                      style: TextStyle(
                        fontSize: 13,
                        color: selected ? Colors.white : Colors.grey[800],
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
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
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: buildLocalImage(_selectedImage!.path, fit: BoxFit.contain),
                    )
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
