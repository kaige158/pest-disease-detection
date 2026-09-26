import 'package:flutter/material.dart';
import 'package:laos_agri_app/app.dart';
import 'package:laos_agri_app/core/auth/user_session.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/config/environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启动即打印实际生效的后端地址 —— 外场排障第一条信息
  debugPrint('[LaosAgri] ${AppEnvironment.describe()}');

  // 恢复本地登录态（令牌 + 用户资料）。必须 await，
  // 否则首帧会误判为未登录、界面闪一下再跳回登录态
  await UserSession.instance.restore();

  runApp(LaosAgriApp(config: AppConfig.fruit));
}
