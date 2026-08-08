import 'package:dio/dio.dart';
import 'package:laos_agri_app/core/config/app_config.dart';

/// API客户端 — 封装Dio，统一处理baseUrl、错误、超时等。
class ApiClient {
  late final Dio _dio;
  final AppConfig config;
  String _language = 'zh';

  ApiClient({required this.config}) {
    _dio = Dio(BaseOptions(
      // TODO: 替换为实际后端地址，开发期用本地
      baseUrl: 'http://10.0.2.2:8000/api/v1', // Android模拟器 → 宿主机
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// 设置当前语言
  void setLanguage(String lang) {
    _language = lang;
  }

  /// GET 请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    final params = {
      'version': config.version,
      'language': _language,
      ...?queryParameters,
    };
    return _dio.get(path, queryParameters: params);
  }

  /// POST 请求
  Future<Response> post(
    String path, {
    dynamic data,
  }) {
    return _dio.post(path, data: data);
  }

  /// POST multipart (图片上传)
  Future<Response> upload(
    String path, {
    required String filePath,
    Map<String, String>? extraFields,
  }) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
      'version': config.version,
      'language': _language,
      ...?extraFields,
    });
    return _dio.post(path, data: formData);
  }
}
