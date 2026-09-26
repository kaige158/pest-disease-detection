import 'package:flutter/widgets.dart';

import 'image_loader_io.dart' if (dart.library.js_interop) 'image_loader_web.dart'
    as impl;

/// 跨平台本地图片加载
///
/// 背景：`Image.file(File(path))` 依赖 `dart:io`，在 Flutter Web 上会直接抛
/// `UnsupportedError`，导致识别结果页一打开就白屏。这里按平台条件导入：
///   * Android / iOS / 桌面 → `image_loader_io.dart`（读文件）
///   * Web                 → `image_loader_web.dart`（读字节流）
///
/// [source] 在 IO 平台是文件路径，在 Web 上是 `XFile.path` 形式的 blob URL。
Widget buildLocalImage(
  String source, {
  BoxFit fit = BoxFit.contain,
  Widget? placeholder,
}) {
  if (source.isEmpty) return placeholder ?? const SizedBox.expand();
  return impl.buildLocalImage(source, fit: fit, placeholder: placeholder);
}
