import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuidanceService {
  static final VoiceGuidanceService _instance = VoiceGuidanceService._internal();
  factory VoiceGuidanceService() => _instance;
  VoiceGuidanceService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isEnabled = true;
  String _lastSpokenText = '';
  DateTime _lastSpokenTime = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isEnabled => _isEnabled;

  void toggleVoice() {
    _isEnabled = !_isEnabled;
    if (!_isEnabled) {
      stop();
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage("en-US");
      await _flutterTts!.setSpeechRate(0.52);
      await _flutterTts!.setPitch(1.0);
      await _flutterTts!.awaitSpeakCompletion(true);
      _isInitialized = true;
    } catch (e) {
      debugPrint('VoiceGuidanceService init fallback: $e');
    }
  }

  /// Speaks short guidance instruction, with rate-limiting to prevent spamming
  Future<void> speak(String text) async {
    if (!_isEnabled) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    // Do not repeat identical utterance within 3 seconds
    if (trimmed == _lastSpokenText && now.difference(_lastSpokenTime).inMilliseconds < 3000) {
      return;
    }
    // Throttle any speech to minimum 1500ms intervals
    if (now.difference(_lastSpokenTime).inMilliseconds < 1500) {
      return;
    }

    _lastSpokenText = trimmed;
    _lastSpokenTime = now;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts?.stop();
      await _flutterTts?.speak(trimmed);
    } catch (e) {
      debugPrint('Voice speech error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
    } catch (_) {}
  }
}

final voiceGuidance = VoiceGuidanceService();
