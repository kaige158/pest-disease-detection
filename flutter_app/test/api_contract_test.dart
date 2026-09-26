// 契约验证测试 —— 用真实 HTTP 请求打本地模拟后端，确认客户端请求格式与 Java 侧一致。
//
// 运行方式（模拟后端需先启动在 127.0.0.1:18080）:
//   node .dsh-home/mock_backend.js &
//   flutter test test/api_contract_test.dart --dart-define=API_BASE_URL=http://127.0.0.1:18080/api/v1
//
// 未注入 API_BASE_URL 时整个文件自动跳过，不会影响常规的 `flutter test`。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/core/config/environment.dart';
import 'package:laos_agri_app/core/network/api_client.dart';

void main() {
  final base = AppEnvironment.springApiBaseUrl;
  final enabled = base.contains('18080');

  group('API 契约（需模拟后端）', () {
    setUpAll(() {
      if (!enabled) {
        // ignore: avoid_print
        print('跳过：未注入 API_BASE_URL=http://127.0.0.1:18080/api/v1');
      }
    });

    test('identify 必须发 multipart 文件上传，且字段名与后端 @RequestParam 对齐', () async {
      if (!enabled) return;

      final client = ApiClient(config: AppConfig.vegetable);
      final data = await client.identify(
        imageBytes: Uint8List.fromList(List<int>.filled(2048, 7)),
        filename: 'leaf.jpg',
        language: 'lo',
        cropId: 2,
      );

      // 1) 响应信封被正确解包，字段可直接取用
      expect(data['task_id'], 'rec_mock01');
      expect(data['disease_name_zh'], '番茄晚疫病');
      expect(data['disease_name_lo'], 'ພະຍາດໃບໄໝ້ໝາກເລັ່ນ');
      expect(data['confidence'], 0.93);
      expect((data['prevention'] as Map)['chemical'], isA<List<dynamic>>());

      // 2) 请求侧：核对 mock 服务记录下来的实际请求
      final recorded = await _lastRequest();
      expect(recorded['contentType'], 'multipart/form-data',
          reason: 'Java 侧是 @RequestParam("image") MultipartFile，必须是 multipart');
      final fields = (recorded['fields'] as List).cast<String>();
      expect(fields, contains('image'));
      expect(fields, contains('version'));
      expect(fields, contains('language'));
      expect(fields, contains('crop_id'));
      expect(recorded['bodyBytes'], greaterThan(2048));
    });

    test('submitFeedback 发 JSON，字段为 feedback/note', () async {
      if (!enabled) return;

      final client = ApiClient(config: AppConfig.vegetable);
      await client.submitFeedback(taskId: 'rec_mock01', feedback: 'disputed', note: '识别错了');

      final recorded = await _lastRequest();
      expect(recorded['contentType'], 'application/json');
      expect(recorded['url'], endsWith('/recognition/rec_mock01/feedback'));
      final json = recorded['json'] as Map;
      expect(json['feedback'], 'disputed');
      expect(json['note'], '识别错了');
    });

    test('后端返回非 200 时抛出 ApiException 并带出后端 message', () async {
      if (!enabled) return;

      final client = ApiClient(config: AppConfig.vegetable);
      expect(
        () => client.get('/not-exist'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'not found')),
      );
    });
  });
}

/// 从模拟后端读取最后一条请求记录（mock 服务把记录追加到 requests.jsonl）
Future<Map<String, dynamic>> _lastRequest() async {
  final file = File(r'F:\lao-cn-APP\.dsh-home\mock_requests.jsonl');
  for (var i = 0; i < 40; i++) {
    if (await file.exists()) {
      final lines = await file.readAsLines();
      if (lines.isNotEmpty) {
        return jsonDecode(lines.last) as Map<String, dynamic>;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('模拟后端未记录到任何请求');
}
