import 'package:flutter/material.dart';

/// AI农业助手对话页面 (占位 — 第七阶段实现)
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI助手')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('AI农业助手', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('输入作物名称或农业问题，AI助手为你解答',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
