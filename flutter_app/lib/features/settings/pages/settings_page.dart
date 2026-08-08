import 'package:flutter/material.dart';

/// 设置页面 (占位 — 第八阶段实现双语切换等功能)
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.language),
            title: Text('语言 / Language / ພາສາ'),
            subtitle: Text('当前: 中文'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('中老双语农业病虫害识别与防控APP'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
