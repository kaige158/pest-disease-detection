import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/features/home/pages/home_page.dart';
import 'package:laos_agri_app/features/recognition/pages/recognition_page.dart';
import 'package:laos_agri_app/features/knowledge/pages/knowledge_list_page.dart';
import 'package:laos_agri_app/features/assistant/pages/chat_page.dart';
import 'package:laos_agri_app/features/settings/pages/settings_page.dart';
import 'package:laos_agri_app/shared/widgets/scale_tap.dart';

class LaosAgriApp extends StatelessWidget {
  final AppConfig config;
  const LaosAgriApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(config.primaryColor),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: MainScreen(config: config),
    );
  }
}

/// 主页面 — 底部导航：首页 / AI助手 / 知识库 / 我的
/// 病虫害识别从首页卡片进入（Navigator.push），不占底部Tab
class MainScreen extends StatefulWidget {
  final AppConfig config;
  const MainScreen({super.key, required this.config});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _lang = 'zh'; // zh / lo

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _rebuildPages();
  }

  void _rebuildPages() {
    _pages = [
      // Tab 0 — 首页仪表盘
      HomePage(
        config: widget.config,
        language: _lang,
      ),
      // Tab 1 — AI助手（对话）
      ChatPage(config: widget.config, language: _lang),
      // Tab 2 — 拍照识别（放中间，单手拇指最易触达）
      RecognitionPage(config: widget.config, language: _lang),
      // Tab 3 — 知识库
      KnowledgeListPage(config: widget.config, language: _lang),
      // Tab 4 — 我的（设置）
      SettingsPage(
        config: widget.config,
        language: _lang,
        onLanguageChanged: _onLanguageChanged,
      ),
    ];
  }

  void _jumpTo(int index) {
    setState(() => _currentIndex = index);
  }

  void _onLanguageChanged(String newLang) {
    setState(() {
      _lang = newLang;
      _rebuildPages();
    });
  }

  String _tabLabel(int index) {
    final isZh = _lang == 'zh';
    return switch (index) {
      0 => isZh ? '首页' : 'ໜ້າຫຼັກ',
      1 => isZh ? 'AI助手' : 'ຜູ້ຊ່ວຍ AI',
      2 => isZh ? '拍照识别' : 'ຖ່າຍຮູບ',
      3 => isZh ? '知识库' : 'ຄວາມຮູ້',
      4 => isZh ? '我的' : 'ຂອງຂ້ອຍ',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(widget.config.primaryColor);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // 中间凸起的拍照识别按钮（带点按缩放反馈）
      floatingActionButton: ScaleTap(
        pressedScale: 0.86,
        onTap: () => _jumpTo(2),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: primary.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_currentIndex == 2 ? Icons.camera_alt : Icons.camera_alt_outlined, size: 26, color: Colors.white),
              const SizedBox(height: 2),
              Text(_tabLabel(2), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 64,
        color: Colors.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 7,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.home_outlined, Icons.home, primary),
            _navItem(1, Icons.smart_toy_outlined, Icons.smart_toy, primary),
            const SizedBox(width: 64), // 给中间凸起按钮让位
            _navItem(3, Icons.menu_book_outlined, Icons.menu_book, primary),
            _navItem(4, Icons.person_outline, Icons.person, primary),
          ],
        ),
      ),
    );
  }

  /// 底部导航项（非中间的四个）
  Widget _navItem(int index, IconData icon, IconData activeIcon, Color primary) {
    final selected = _currentIndex == index;
    final color = selected ? primary : Colors.grey[500];
    return Expanded(
      child: ScaleTap(
        pressedScale: 0.86,
        onTap: () => _jumpTo(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              _tabLabel(index),
              style: TextStyle(fontSize: 10, color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }
}
