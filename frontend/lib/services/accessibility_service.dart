import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'voice_service.dart';

class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  bool _isHighContrastMode = false;
  bool _isLargeFontMode = false;
  bool _isHapticsEnabled = true;
  bool _isScreenReaderAnnouncementsEnabled = true;

  bool get isHighContrastMode => _isHighContrastMode;
  bool get isLargeFontMode => _isLargeFontMode;
  bool get isHapticsEnabled => _isHapticsEnabled;
  bool get isScreenReaderAnnouncementsEnabled => _isScreenReaderAnnouncementsEnabled;

  void toggleScreenReaderAnnouncements() {
    _isScreenReaderAnnouncementsEnabled = !_isScreenReaderAnnouncementsEnabled;
    notifyListeners();
  }

  void toggleHighContrast() {
    _isHighContrastMode = !_isHighContrastMode;
    triggerHaptic(HapticType.selection);
    announce(_isHighContrastMode ? 'High contrast mode turned on.' : 'High contrast mode turned off.');
    notifyListeners();
  }

  void toggleLargeFont() {
    _isLargeFontMode = !_isLargeFontMode;
    triggerHaptic(HapticType.selection);
    announce(_isLargeFontMode ? 'Large font mode enabled.' : 'Standard font mode restored.');
    notifyListeners();
  }

  void toggleHaptics() {
    _isHapticsEnabled = !_isHapticsEnabled;
    notifyListeners();
  }

  /// Announces text via TTS for visually impaired users without interrupting ongoing speech
  void announce(String message) {
    if (_isScreenReaderAnnouncementsEnabled) {
      voiceGuidance.speak(message);
    }
  }

  /// Tactile feedback patterns designed for low-vision orientation
  void triggerHaptic(HapticType type) {
    if (!_isHapticsEnabled) return;
    switch (type) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticType.success:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 150), () {
          HapticFeedback.heavyImpact();
        });
        break;
      case HapticType.alert:
        HapticFeedback.vibrate();
        break;
    }
  }
}

enum HapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  alert,
}

final a11yService = AccessibilityService();
