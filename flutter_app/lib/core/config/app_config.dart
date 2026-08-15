/// Flavor-based application configuration.
/// Controls all differences between vegetable and fruit versions.
enum AppFlavor { vegetable, fruit }

class AppConfig {
  final AppFlavor flavor;
  final String appName;
  final String appId;
  final String version; // 'vegetable' or 'fruit' sent to backend
  final int primaryColor;

  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.appId,
    required this.version,
    required this.primaryColor,
  });

  /// Vegetable version config.
  static const vegetable = AppConfig(
    flavor: AppFlavor.vegetable,
    appName: '老挝蔬菜病虫害识别与防控',
    appId: 'com.laos.agri.veggie',
    version: 'vegetable',
    primaryColor: 0xFF4CAF50, // Green
  );

  /// Fruit version config.
  static const fruit = AppConfig(
    flavor: AppFlavor.fruit,
    appName: '老挝果树病虫害识别与防控',
    appId: 'com.laos.agri.fruit',
    version: 'fruit',
    primaryColor: 0xFFFF9800, // Orange
  );
}
