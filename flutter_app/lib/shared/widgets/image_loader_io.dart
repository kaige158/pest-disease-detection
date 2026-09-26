import 'dart:io';

import 'package:flutter/material.dart';

/// IO 平台实现：直接读本地文件（Android / iOS / 桌面）
Widget buildLocalImage(
  String source, {
  BoxFit fit = BoxFit.contain,
  Widget? placeholder,
}) {
  return Image.file(
    File(source),
    fit: fit,
    errorBuilder: (_, _, _) => placeholder ?? _broken(),
  );
}

Widget _broken() => const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
    );
