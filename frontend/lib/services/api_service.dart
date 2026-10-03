import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/target_profile.dart';
import '../models/candidate.dart';
import '../models/verification.dart';
import '../models/guidance.dart';
import '../models/search_session.dart';

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

  /// Phase 3: Sampled camera frame candidate detection
  static Future<CandidateDetectResponse> detectCandidate({
    required Uint8List frameBytes,
    required TargetProfile targetProfile,
  }) async {
    final uri = Uri.parse('$baseUrl/candidate/detect');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'frame',
        frameBytes,
        filename: 'frame.jpg',
      ),
    );

    request.fields['target_profile'] = json.encode(targetProfile.toJson());

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('Candidate detector timed out.'),
        );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return CandidateDetectResponse.fromJson(data);
    } else {
      final errorDetail = _extractErrorDetail(response.body);
      throw Exception('Candidate detection error (${response.statusCode}): $errorDetail');
    }
  }

  /// Phase 4: Gemma multimodal verification of candidate crop
  static Future<VerifyCandidateResponse> verifyCandidate({
    required Uint8List candidateCropBytes,
    required TargetProfile targetProfile,
    Uint8List? referenceBytes,
  }) async {
    final uri = Uri.parse('$baseUrl/candidate/verify');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'candidate_crop',
        candidateCropBytes,
        filename: 'crop.jpg',
      ),
    );

    request.fields['target_profile'] = json.encode(targetProfile.toJson());

    if (referenceBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'reference_image',
          referenceBytes,
          filename: 'ref.jpg',
        ),
      );
    }

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw Exception('Gemma candidate verification timed out.'),
        );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return VerifyCandidateResponse.fromJson(data);
    } else {
      final errorDetail = _extractErrorDetail(response.body);
      throw Exception('Verification error (${response.statusCode}): $errorDetail');
    }
  }

  /// Phase 5: Directional guidance search decision
  static Future<SearchDecisionResponse> getSearchDecision(
    SearchDecisionRequest request,
  ) async {
    final uri = Uri.parse('$baseUrl/search/decision');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('Guidance decision timed out.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SearchDecisionResponse.fromJson(data);
    } else {
      final errorDetail = _extractErrorDetail(response.body);
      throw Exception('Decision error (${response.statusCode}): $errorDetail');
    }
  }

  /// Phase 6: Initialize a formalized search session with state machine
  static Future<SessionResponse> startSession({
    required TargetProfile targetProfile,
    String? sessionId,
  }) async {
    final uri = Uri.parse('$baseUrl/session/start');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        ...?sessionId != null ? {'session_id': sessionId} : null,
        'target_profile': targetProfile.toJson(),
      }),
    ).timeout(
      const Duration(seconds: 6),
      onTimeout: () => throw Exception('Start session request timed out.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SessionResponse.fromJson(data);
    } else {
      final errorDetail = _extractErrorDetail(response.body);
      throw Exception('Session start error (${response.statusCode}): $errorDetail');
    }
  }

  /// Phase 6: Transition state machine to next state with explicit reason
  static Future<SessionResponse> transitionState({
    required String sessionId,
    required SearchState toState,
    required String reason,
  }) async {
    final uri = Uri.parse('$baseUrl/session/transition');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'session_id': sessionId,
        'to_state': toState.code,
        'reason': reason,
      }),
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('State transition request timed out.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SessionResponse.fromJson(data);
    } else {
      final errorDetail = _extractErrorDetail(response.body);
      throw Exception('Transition error (${response.statusCode}): $errorDetail');
    }
  }

  /// Phase 6: Complete search session
  static Future<SessionResponse> completeSession({
    required String sessionId,
    String reason = 'Search finished',
  }) async {
    final uri = Uri.parse('$baseUrl/session/complete');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'session_id': sessionId,
        'reason': reason,
      }),
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('Complete session request timed out.'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SessionResponse.fromJson(data);
    } else {
      final errorDetail = _extractErrorDetail(response.body);
      throw Exception('Complete error (${response.statusCode}): $errorDetail');
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
