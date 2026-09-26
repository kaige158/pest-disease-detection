import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:laos_agri_app/core/auth/user_session.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/config/environment.dart';

/// 接口调用失败 —— 携带后端返回的中文提示，便于直接展示给用户
class ApiException implements Exception {
  final int code;
  final String message;

  const ApiException(this.code, this.message);

  @override
  String toString() => 'ApiException($code): $message';
}

/// API 客户端 —— 全 APP 唯一的后端访问入口
///
/// 职责：
///   1. 统一 baseUrl（来自 [AppEnvironment]，不再各处硬编码）
///   2. 统一解包后端 `{code, message, data}` 信封，失败直接抛 [ApiException]
///   3. 统一超时、日志（仅 debug 打开）
///
/// 与后端契约（务必与 Java 侧保持一致）：
///   | 接口                        | 后端        | 方法 | 请求体               |
///   |-----------------------------|-------------|------|----------------------|
///   | POST /recognition/identify  | Spring Boot | 多部分 | image=文件 + 表单字段 |
///   | POST /recognition/{id}/feedback | Spring Boot | JSON | {feedback, note} |
///   | POST /diagnosis/diagnose    | FastAPI     | JSON | {session_id, ...}    |
///
/// ⚠️ `/identify` 必须是 multipart 文件上传：Java 侧签名是
/// `@RequestParam("image") MultipartFile image`，
/// 早期客户端发的是 `{"image": "<base64字符串>"}`，后端一律 400。
class ApiClient {
  final AppConfig config;
  final Dio _dio;

  /// 业务后端接口
  ApiClient({required this.config, Dio? dio})
      : _dio = dio ?? _buildDio(AppEnvironment.springApiBaseUrl);

  static Dio _buildDio(String baseUrl) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60), // AI 识别+入库，留足时间
      headers: {
        'Accept': 'application/json',
      },
    ));

    // 自动附带登录令牌 —— 所有接口无需各自处理鉴权头
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = UserSession.instance.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        // 令牌失效（过期 / 被停用 / 改过密码）→ 清本地登录态，
        // 界面会因 UserSession 通知自动回到未登录状态
        final status = error.response?.statusCode;
        if (status == 401 || status == 403) {
          final hadToken = UserSession.instance.isLoggedIn;
          if (hadToken) {
            UserSession.instance.clear();
          }
        }
        handler.next(error);
      },
    ));

    // 只在 debug 构建打开请求日志，release 包不打印用户数据
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: false, responseBody: false));
    }
    return dio;
  }

  /// 业务后端基础地址（排障展示用）
  String get baseUrl => _dio.options.baseUrl;

  /// 解包 `{code, message, data}`；业务失败（code != 200）抛 [ApiException]
  ///
  /// 注意 `data` 允许是标量：后端部分接口（如反馈提交）返回的是
  /// `{"code":200,"message":"success","data":"反馈已提交"}`，
  /// 因此非对象类型的 `data` 归一化为空 Map，交给调用方按需忽略。
  static Map<String, dynamic> unwrap(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map) {
      throw const ApiException(-1, '服务器返回格式异常');
    }
    final map = Map<String, dynamic>.from(body);
    final code = map['code'];
    if (code is int && code != 200) {
      throw ApiException(code, (map['message'] ?? '请求失败').toString());
    }
    final data = map['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  /// GET
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _dio.get<dynamic>(path, queryParameters: {
      'version': config.version,
      ...?query,
    });
    return unwrap(response);
  }

  /// GET（不注入 version、不拆信封）—— 用于 `/auth/countries` 这类返回裸列表的接口
  Future<Map<String, dynamic>> getRaw(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _dio.get<dynamic>(path, queryParameters: query);
    final body = response.data;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw const ApiException(-1, '服务器返回格式异常');
  }

  /// POST JSON
  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
  }) async {
    final response = await _dio.post<dynamic>(path, data: data);
    return unwrap(response);
  }

  /// PUT JSON
  Future<Map<String, dynamic>> put(
    String path, {
    Object? data,
  }) async {
    final response = await _dio.put<dynamic>(path, data: data);
    return unwrap(response);
  }

  /// POST 图片文件（multipart）—— 后端 `@RequestParam("image") MultipartFile`
  Future<Map<String, dynamic>> postImage(
    String path, {
    required Uint8List bytes,
    required String filename,
    Map<String, String>? fields,
  }) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
      'version': config.version,
      ...?fields,
    });
    final response = await _dio.post<dynamic>(path, data: form);
    return unwrap(response);
  }

  // ======================= 业务方法 =======================

  /// 图片识别 —— `POST /recognition/identify`
  ///
  /// 已登录时自动带上 `user_id`，让识别记录归属到该用户，
  /// 这样"换手机登录能看到历史记录"才成立；未登录则不传（后端允许游客识别）。
  ///
  /// [cropId] 为空时后端按通用识别处理，不做作物限定。
  Future<Map<String, dynamic>> identify({
    required Uint8List imageBytes,
    required String filename,
    required String language,
    int? cropId,
    String? deviceUuid,
  }) {
    final profile = UserSession.instance.profile;
    return postImage(
      '/recognition/identify',
      bytes: imageBytes,
      filename: filename,
      fields: {
        'language': language,
        if (cropId != null) 'crop_id': '$cropId',
        if (UserSession.instance.isLoggedIn && profile != null) 'user_id': '${profile.id}',
        if (deviceUuid != null && deviceUuid.isNotEmpty) 'device_uuid': deviceUuid,
      },
    );
  }

  /// 提交识别反馈 —— `POST /recognition/{taskId}/feedback`
  ///
  /// [feedback] 取值：`confirmed`（结果正确）/ `disputed`（结果不正确，进入专家复核）
  Future<Map<String, dynamic>> submitFeedback({
    required String taskId,
    required String feedback,
    String note = '',
  }) {
    return post('/recognition/$taskId/feedback', data: {
      'feedback': feedback,
      'note': note,
    });
  }

  /// 查询识别结果 —— `GET /recognition/result/{taskId}`
  Future<Map<String, dynamic>> fetchResult(String taskId) =>
      get('/recognition/result/$taskId');

  /// 诊断 Agent 一步 —— `POST /diagnosis/diagnose`（FastAPI 服务，独立地址）
  ///
  /// [answerKey]/[answer] 为空表示"开始新会话"。
  Future<Map<String, dynamic>> diagnose({
    required String language,
    String sessionId = '',
    String answerKey = '',
    String answer = '',
  }) async {
    final dio = _dioFor(AppEnvironment.aiApiBaseUrl);
    final response = await dio.post<dynamic>('/diagnosis/diagnose', data: {
      'session_id': sessionId,
      'version': config.version,
      'language': language,
      'answer_key': answerKey,
      'answer': answer,
    });
    // FastAPI 不走 {code,message,data} 信封，直接返回业务对象
    final body = response.data;
    if (body is Map) return Map<String, dynamic>.from(body);
    throw const ApiException(-1, '诊断服务返回格式异常');
  }

  /// 按需构造指向其它后端的 Dio（当前只有 AI 服务用到）
  static final Map<String, Dio> _otherDio = {};

  static Dio _dioFor(String baseUrl) =>
      _otherDio.putIfAbsent(baseUrl, () => _buildDio(baseUrl));
}
