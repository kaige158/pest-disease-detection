import 'package:flutter/material.dart';

/// 病虫害拍照识别页面 (占位 — 第五阶段实现)
class RecognitionPage extends StatelessWidget {
  const RecognitionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('病虫害识别')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('拍照识别病虫害', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('拍照或从相册上传叶片照片，AI自动识别病虫害',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
