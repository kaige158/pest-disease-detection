import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:laos_agri_app/core/config/app_config.dart';
import 'package:laos_agri_app/features/recognition/pages/result_page.dart';

/// 病虫害拍照识别页面 — MVP核心功能
class RecognitionPage extends StatefulWidget {
  final AppConfig config;
  const RecognitionPage({super.key, required this.config});

  @override
  State<RecognitionPage> createState() => _RecognitionPageState();
}

class _RecognitionPageState extends State<RecognitionPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isUploading = false;
  // ignore: unused_field
  String? _statusText;

  Future<void> _pickFromCamera() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _statusText = null;
        });
      }
    } catch (e) {
      _showError('无法打开相机: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _statusText = null;
        });
      }
    } catch (e) {
      _showError('无法打开相册: $e');
    }
  }

  Future<void> _uploadAndIdentify() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true;
      _statusText = '正在上传图片...';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() => _statusText = 'AI正在识别病虫害...');

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ));

      // 调用Spring Boot后端识别API
      final response = await dio.post(
        'http://10.0.2.2:8080/api/v1/recognition/identify',
        data: {
          'image': base64Image,
          'version': widget.config.version,
          'language': 'zh',
        },
      );

      if (!mounted) return;

      final data = response.data;
      if (data['code'] == 200 && data['data'] != null) {
        // 跳转到结果页
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultPage(
              resultData: data['data'],
              config: widget.config,
              imagePath: _selectedImage!.path,
            ),
          ),
        );
      } else {
        _showError(data['message'] ?? '识别失败');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        _showError('无法连接服务器，请检查网络');
      } else {
        _showError('识别失败: ${e.message}');
      }
    } catch (e) {
      _showError('发生错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusText = null;
        });
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('病虫害识别'),
        backgroundColor: Color(widget.config.primaryColor),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 图片展示区域
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImage!.path),
                          fit: BoxFit.contain,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('拍照或选择图片进行病虫害识别',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
              ),
            ),

            // 上传状态
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('AI正在分析植物健康状态...'),
                  ],
                ),
              ),

            // 操作按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('相册'),
                    ),
                  ),
                ],
              ),
            ),

            // 识别按钮
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadAndIdentify,
                    icon: const Icon(Icons.search),
                    label: const Text('开始识别', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(widget.config.primaryColor),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
