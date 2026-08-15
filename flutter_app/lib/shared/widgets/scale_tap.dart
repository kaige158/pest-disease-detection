import 'package:flutter/material.dart';

/// 点按缩放反馈组件 — 按下缩小、松手弹回。
///
/// 用于给可点击的内容/按钮增加轻微的触摸手感。
/// [pressedScale] 越小反馈越明显：导航按钮用 0.86，内容卡片用 0.96。
class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  const ScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  double _scale = 1.0;

  void _setScale(double s) {
    if (mounted) setState(() => _scale = s);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setScale(widget.pressedScale),
      onTapUp: (_) => _setScale(1.0),
      onTapCancel: () => _setScale(1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
