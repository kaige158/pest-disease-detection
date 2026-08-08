import 'package:flutter/material.dart';

/// 农业知识库页面 (占位 — 第七阶段实现)
class KnowledgeListPage extends StatelessWidget {
  const KnowledgeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('知识库')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('农业知识库', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('浏览作物分类与病虫害知识', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
