import 'package:flutter/material.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/features/recognition/pages/recognition_page.dart';
import 'package:laos_agri_app/features/knowledge/pages/knowledge_list_page.dart';
import 'package:laos_agri_app/features/assistant/pages/chat_page.dart';
import 'package:laos_agri_app/features/settings/pages/settings_page.dart';

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
        ),
      ),
      home: MainScreen(config: config),
    );
  }
}

/// 主页面 — 底部4Tab导航
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
      RecognitionPage(config: widget.config, language: _lang),
      KnowledgeListPage(config: widget.config, language: _lang),
      ChatPage(config: widget.config, language: _lang),
      SettingsPage(config: widget.config, language: _lang, onLanguageChanged: _onLanguageChanged),
    ];
  }

  void _onLanguageChanged(String newLang) {
    setState(() {
      _lang = newLang;
      _rebuildPages();
    });
  }

  // === 底部导航标签(双语 — 农业用户易懂) ===
  String _tabLabel(int index) {
    final tab = switch (index) {
      0 => (_lang == 'lo') ? 'ກວດພະຍາດ' : '拍照识病',
      1 => (_lang == 'lo') ? 'ຄວາມຮູ້' : '知识库',
      2 => (_lang == 'lo') ? 'ຜູ້ຊ່ວຍ AI' : 'AI助手',
      3 => (_lang == 'lo') ? 'ຕັ້ງຄ່າ' : '设置',
      _ => '',
    };
    return tab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.camera_alt_outlined),
            selectedIcon: const Icon(Icons.camera_alt),
            label: _tabLabel(0),
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: _tabLabel(1),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_outlined),
            selectedIcon: const Icon(Icons.chat),
            label: _tabLabel(2),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: _tabLabel(3),
          ),
        ],
      ),
    );
  }
}
