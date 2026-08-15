import 'dart:async';
import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/features/home/pages/notifications_page.dart';
import 'package:laos_agri_app/features/knowledge/pages/content_detail_page.dart';
import 'package:laos_agri_app/shared/widgets/scale_tap.dart';

/// 首页仪表盘 — 参照「AI植保云鉴」风格设计
/// 绿色渐变头部 + 病虫害图片轮播 + 即时资讯 + 作物宫格
class HomePage extends StatelessWidget {
  final AppConfig config;
  final String language;

  const HomePage({
    super.key,
    required this.config,
    required this.language,
  });

  bool get _isZh => language == 'zh';

  // ─── "更多"菜单 ───────────────────────────────────────────────
  Widget _menuRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Text(text),
      ],
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'help':
        _showInfoDialog(
          context,
          _isZh ? '使用帮助' : 'ວິທີໃຊ້',
          _isZh
              ? '📷 拍照识别：点击底部中间的相机按钮，拍摄或上传病虫害叶片照片，'
                  '即可获得病害名称、置信度与防治建议。\n\n'
                  '🤖 AI助手：输入作物名称或症状，获取农业知识解答。\n\n'
                  '📖 知识库：按作物浏览常见病虫害的中老双语资料。\n\n'
                  '🌐 语言切换：在"我的"页面可切换中文 / 老挝语。'
              : '📷 ຖ່າຍຮູບກວດ: ກົດປຸ່ມກ້ອງເພື່ອກວດພະຍາດ.\n\n'
                  '🤖 ຜູ້ຊ່ວຍ AI: ພິມຊື່ພືດ ຫຼື ອາການ.\n\n'
                  '📖 ຄັງຄວາມຮູ້: ເບິ່ງຂໍ້ມູນພະຍາດ.\n\n'
                  '🌐 ປ່ຽນພາສາ: ໄປທີ່ໜ້າ "ຂອງຂ້ອຍ".',
        );
        break;
      case 'about':
        _showInfoDialog(
          context,
          _isZh ? '关于' : 'ກ່ຽວກັບ',
          _isZh
              ? '${config.appName}\n版本 v1.0.0\n\n'
                  '中老双语农业病虫害识别与防控平台，由农业专家团队维护。\n\n'
                  '⚠️ 识别结果仅供参考，不能替代专业农业技术人员判断。'
                  '使用农药请严格遵守产品说明书与安全间隔期。'
              : '${config.appName}\nເວີຊັນ v1.0.0\n\n'
                  'ແພລດຟອມກວດພະຍາດພືດສອງພາສາ ຈີນ-ລາວ.\n\n'
                  '⚠️ ຜົນການກວດເປັນພຽງຂໍ້ມູນອ້າງອີງ.',
        );
        break;
      case 'feedback':
        _showInfoDialog(
          context,
          _isZh ? '意见反馈' : 'ຄຳຄິດເຫັນ',
          _isZh
              ? '感谢您的使用！\n\n如有识别错误、内容建议或使用问题，'
                  '欢迎通过以下方式反馈：\n\n📧 邮箱：feedback@laos-agri.app\n\n'
                  '您的每一条反馈都会帮助我们让AI识别更准确。'
              : 'ຂອບໃຈທີ່ໃຊ້!\n\nສົ່ງຄຳຄິດເຫັນຜ່ານ:\n📧 feedback@laos-agri.app',
        );
        break;
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(fontSize: 14, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(_isZh ? '知道了' : 'ເຂົ້າໃຈແລ້ວ'),
          ),
        ],
      ),
    );
  }

  // 根据 flavor 返回不同作物列表
  List<(String emoji, String zh, String lo)> get _crops {
    if (config.flavor == AppFlavor.vegetable) {
      return [
        ('🥬', '白菜', 'ຜັກກາດ'),
        ('🍅', '番茄', 'ໝາກເລັ່ນ'),
        ('🌶️', '辣椒', 'ໝາກເຜັດ'),
        ('🥒', '黄瓜', 'ໝາກແຕງ'),
        ('🍆', '茄子', 'ໝາກເຂືອ'),
        ('🧅', '洋葱', 'ຫົວຜັກທຽມ'),
        ('🫘', '豇豆', 'ຖົ່ວຝັກຍາວ'),
        ('🌿', '香菜', 'ຜັກຫອມ'),
        ('🥦', '西蓝花', 'ດອກໄ້'),
        ('🫑', '青椒', 'ໝາກຫຍ້ອຍ'),
      ];
    } else {
      return [
        ('🥭', '芒果', 'ໝາກມ່ວງ'),
        ('🍌', '香蕉', 'ໝາກກ້ວຍ'),
        ('🍊', '柑橘', 'ໝາກກ້ຽງ'),
        ('🫐', '荔枝', 'ໝາກລີ້ນຈີ່'),
        ('🥥', '椰子', 'ໝາກພ້າວ'),
        ('🌴', '油棕', 'ຕົ້ນປາມນ້ຳມັນ'),
        ('🍍', '菠萝', 'ໝາກນັດ'),
        ('🍈', '木瓜', 'ໝາກຫຸ່ງ'),
        ('🌾', '甘蔗', 'ອ້ອຍ'),
        ('🍇', '龙眼', 'ໝາກງ້ຽວ'),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(context),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildImageCarousel(context),
                _buildNewsTicker(context),
                _buildCropGrid(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 顶部渐变横幅 ───────────────────────────────────────────────
  Widget _buildSliverHeader(BuildContext context) {
    final isVeg = config.flavor == AppFlavor.vegetable;
    final gradientStart = isVeg ? const Color(0xFFCCF0A0) : const Color(0xFFFFE0A3);
    final gradientEnd = isVeg ? const Color(0xFF52B629) : const Color(0xFFFF9800);

    return SliverAppBar(
      expandedHeight: 185,
      pinned: true,
      stretch: true,
      backgroundColor: gradientEnd,
      elevation: 0,
      // 折叠后只显示 AppBar 标题
      title: Text(
        _isZh ? config.appName : (isVeg ? 'ພືດຜັກ AI' : 'ໝາກໄມ້ AI'),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
      actions: [
        // 铃铛 — 通知中心（带红点提示）
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              tooltip: _isZh ? '通知' : 'ແຈ້ງເຕືອນ',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsPage(config: config, language: language),
              )),
            ),
            Positioned(
              right: 10,
              top: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        // 三个点 — 更多菜单
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: Colors.white),
          tooltip: _isZh ? '更多' : 'ເພີ່ມເຕີມ',
          onSelected: (value) => _onMenuSelected(context, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'help',
              child: _menuRow(Icons.help_outline, _isZh ? '使用帮助' : 'ວິທີໃຊ້'),
            ),
            PopupMenuItem(
              value: 'about',
              child: _menuRow(Icons.info_outline, _isZh ? '关于' : 'ກ່ຽວກັບ'),
            ),
            PopupMenuItem(
              value: 'feedback',
              child: _menuRow(Icons.feedback_outlined, _isZh ? '意见反馈' : 'ຄຳຄິດເຫັນ'),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [gradientStart, gradientEnd],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 左侧文字区
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _isZh ? 'Hi, 欢迎使用' : 'ສະບາຍດີ, ຍິນດີຕ້ອນຮັບ',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          config.appName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20),
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isZh ? '让种植更简单' : 'ເຮັດໃຫ້ການປູກງ່າຍຂຶ້ນ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右侧吉祥物
                  _buildMascot(isVeg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMascot(bool isVeg) {
    return Container(
      width: 115,
      height: 130,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
          ),
          Text(
            isVeg ? '🥬' : '🥭',
            style: const TextStyle(fontSize: 68),
          ),
          // 放大镜装饰
          Positioned(
            right: 4,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.search, size: 16, color: Color(0xFF2E7D32)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 病虫害图片轮播 ───────────────────────────────────────────────
  Widget _buildImageCarousel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: _DiseaseCarousel(
        config: config,
        language: language,
      ),
    );
  }

  // ─── 即时资讯条 ───────────────────────────────────────────────────
  Widget _buildNewsTicker(BuildContext context) {
    final crop = config.flavor == AppFlavor.vegetable ? '蔬菜' : '果树';
    final news = _isZh
        ? '老挝雨季病虫害高发期已到，请关注$crop病虫防控最新公告…'
        : 'ລະດູຝົນໃນລາວ, ກະລຸນາຕິດຕາມການແຈ້ງເຕືອນ…';
    final newsBody = _isZh
        ? '当前老挝进入雨季，高温高湿气候利于$crop病虫害快速蔓延。\n\n'
            '建议农户：\n'
            '1. 加强田间巡查，及早发现病斑与虫口；\n'
            '2. 雨后及时排水，避免田间积水诱发根部与叶部病害；\n'
            '3. 发现疑似病虫害可用"拍照识别"上传照片，获取防治建议；\n'
            '4. 科学用药，严格遵守安全间隔期。\n\n'
            '（更多本地化资讯将陆续更新）'
        : 'ຂໍ້ມູນຂ່າວສານຈະຖືກອັບເດດເພີ່ມເຕີມ.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ScaleTap(
        pressedScale: 0.97,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ContentDetailPage(
            config: config,
            language: language,
            titleZh: '即时资讯',
            titleLo: 'ຂ່າວສານ',
            bodyText: newsBody,
          ),
        )),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))
            ],
          ),
          child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: config.flavor == AppFlavor.vegetable
                    ? const Color(0xFF7CB342)
                    : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isZh ? '即时\n资讯' : 'ຂ່າວ\nສານ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                news,
                style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
              const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 作物分类宫格 ─────────────────────────────────────────────────
  Widget _buildCropGrid(BuildContext context) {
    final crops = _crops;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 10,
            crossAxisSpacing: 4,
            childAspectRatio: 0.85,
          ),
          itemCount: crops.length,
          itemBuilder: (context, index) {
            final crop = crops[index];
            return ScaleTap(
              pressedScale: 0.90,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ContentDetailPage(
                  config: config,
                  language: language,
                  titleZh: crop.$2,
                  titleLo: crop.$3,
                  emoji: crop.$1,
                  cropName: crop.$2,
                ),
              )),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(crop.$1, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isZh ? crop.$2 : crop.$3,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF424242)),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── 病虫害图片轮播组件（自动滚动） ─────────────────────────────────────
class _DiseaseCarousel extends StatefulWidget {
  final AppConfig config;
  final String language;

  const _DiseaseCarousel({
    required this.config,
    required this.language,
  });

  @override
  State<_DiseaseCarousel> createState() => _DiseaseCarouselState();
}

class _DiseaseCarouselState extends State<_DiseaseCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _current = 0;

  bool get _isZh => widget.language == 'zh';

  /// 每张轮播图: 资源路径 + 中文名 + 老挝名
  List<(String path, String zh, String lo)> get _items {
    if (widget.config.flavor == AppFlavor.vegetable) {
      return const [
        ('assets/images/vegetable/disease1.jpg', '番茄病害', 'ພະຍາດໝາກເລັ່ນ'),
        ('assets/images/vegetable/disease2.jpg', '青虫为害', 'ໜອນຂຽວທຳລາຍ'),
        ('assets/images/vegetable/disease3.jpg', '细菌性病害', 'ພະຍາດເຊື້ອແບັກທີເຣຍ'),
        ('assets/images/vegetable/disease4.jpg', '叶枯病', 'ພະຍາດໃບແຫ້ງ'),
        ('assets/images/vegetable/disease5.jpg', '病毒病', 'ພະຍາດໄວຣັດ'),
      ];
    } else {
      return const [
        ('assets/images/fruit/disease1.jpg', '火龙果茎枯病', 'ພະຍາດລຳຕົ້ນແຫ້ງ'),
        ('assets/images/fruit/disease2.jpg', '草莓灰霉病', 'ພະຍາດເຊື້ອຣາສີເທົາ'),
        ('assets/images/fruit/disease3.jpg', '炭疽病', 'ພະຍາດແອນແທຣກໂນສ'),
        ('assets/images/fruit/disease4.jpg', '果实病害', 'ພະຍາດໝາກໄມ້'),
        ('assets/images/fruit/disease5.jpg', '瓜果病害', 'ພະຍາດແຕງ'),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    // 每 4 秒自动切换到下一张
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_current + 1) % _items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final accent = widget.config.flavor == AppFlavor.vegetable
        ? const Color(0xFF52B629)
        : const Color(0xFFFF9800);

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 168,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: items.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ContentDetailPage(
                          config: widget.config,
                          language: widget.language,
                          titleZh: item.$2,
                          titleLo: item.$3,
                          imagePath: item.$1,
                        ),
                      )),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // 病害照片
                          Image.asset(
                            item.$1,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported,
                                  size: 40, color: Colors.grey),
                            ),
                          ),
                          // 底部渐变 + 名称
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black87],
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _isZh ? '识别' : 'ກວດ',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isZh ? item.$2 : item.$3,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: Colors.white70, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 页码小圆点
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? accent : Colors.grey[350],
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}
