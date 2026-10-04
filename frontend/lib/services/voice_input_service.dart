import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceInputService {
  static final VoiceInputService _instance = VoiceInputService._internal();
  factory VoiceInputService() => _instance;
  VoiceInputService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isInitialized;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech-to-text error: ${errorNotification.errorMsg}');
          _isListening = false;
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('VoiceInputService init error: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start listening and streaming voice recognized text
  Future<void> startListening({
    required Function(String recognizedText) onResult,
    Function(bool isListening)? onListeningStateChanged,
  }) async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) {
        onListeningStateChanged?.call(false);
        return;
      }
    }

    // Provide haptic feedback for visually impaired users
    HapticFeedback.mediumImpact();

    _isListening = true;
    onListeningStateChanged?.call(true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Error starting speech listen: $e');
      _isListening = false;
      onListeningStateChanged?.call(false);
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    HapticFeedback.lightImpact();
    _isListening = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }
}

final voiceInputService = VoiceInputService();
