import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/target_profile.dart';

class ApiService {
  // Base URL auto-selection:
  // - Android emulator uses 10.0.2.2 to access host machine
  // - Windows desktop / web / iOS simulator use 127.0.0.1
  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  static String baseUrl = defaultBaseUrl;

  /// Check backend connectivity and status
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send reference image and user description to Gemma for TargetProfile extraction
  static Future<TargetAnalyzeResponse> analyzeTarget({
    String? imagePath,
    Uint8List? imageBytes,
    String? description,
  }) async {
    final uri = Uri.parse('$baseUrl/target/analyze');
    final request = http.MultipartRequest('POST', uri);

    if (imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'reference.jpg',
        ),
      );
    } else if (imagePath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imagePath),
      );
    } else {
      throw Exception('No reference image provided.');
    }

    if (description != null && description.trim().isNotEmpty) {
      request.fields['description'] = description.trim();
    }

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Connection to Gemma inference service timed out.'),
        );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return TargetAnalyzeResponse.fromJson(data);
    } else {
      final errorDetail = _extractErrorDetail(response.body);
      throw Exception('Analysis error (${response.statusCode}): $errorDetail');
    }
  }

  static String _extractErrorDetail(String body) {
    try {
      final data = json.decode(body);
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return body;
  }
}
