import 'package:flutter/material.dart';

/// Web 平台实现
///
/// Web 上没有文件系统：`image_picker` 返回的 `XFile.path` 是 blob URL，
/// 直接交给 `Image.network` 加载即可，不能走 `dart:io`。
Widget buildLocalImage(
  String source, {
  BoxFit fit = BoxFit.contain,
  Widget? placeholder,
}) {
  return Image.network(
    source,
    fit: fit,
    errorBuilder: (_, _, _) => placeholder ?? _broken(),
  );
}

Widget _broken() => const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
    );
