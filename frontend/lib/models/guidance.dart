import 'target_profile.dart';
import 'candidate.dart';
import 'verification.dart';

enum GuidanceAction {
  panLeft('PAN_LEFT'),
  panRight('PAN_RIGHT'),
  tiltUp('TILT_UP'),
  tiltDown('TILT_DOWN'),
  moveCloser('MOVE_CLOSER'),
  holdSteady('HOLD_STEADY'),
  cropping('CROPPING'),
  objectFound('OBJECT_FOUND'),
  continueScanning('CONTINUE_SCANNING');

  final String code;
  const GuidanceAction(this.code);

  static GuidanceAction fromCode(String code) {
    return GuidanceAction.values.firstWhere(
      (a) => a.code == code.toUpperCase().trim(),
      orElse: () => GuidanceAction.continueScanning,
    );
  }
}

class DeviceOrientationData {
  final double pitch;
  final double roll;
  final double? azimuth;

  const DeviceOrientationData({
    required this.pitch,
    required this.roll,
    this.azimuth,
  });

  Map<String, dynamic> toJson() {
    return {
      'pitch': pitch,
      'roll': roll,
      'azimuth': azimuth,
    };
  }
}

class SearchDecisionRequest {
  final String? sessionId;
  final SearchState currentState;
  final Candidate? candidate;
  final VerificationStatus? verificationStatus;
  final DeviceOrientationData? orientation;
  final int attemptsCount;

  const SearchDecisionRequest({
    this.sessionId,
    required this.currentState,
    this.candidate,
    this.verificationStatus,
    this.orientation,
    required this.attemptsCount,
  });

  Map<String, dynamic> toJson() {
    return {
      if (sessionId != null) 'session_id': sessionId,
      'current_state': currentState.code,
      'candidate': candidate != null
          ? {
              'id': candidate!.id,
              'bounding_box': candidate!.boundingBox.toJson(),
              'confidence': candidate!.confidence,
              'area_ratio': candidate!.areaRatio,
              'aspect_ratio': candidate!.aspectRatio,
              'reason': candidate!.reason,
            }
          : null,
      'verification_status': verificationStatus?.code,
      'orientation': orientation?.toJson(),
      'attempts_count': attemptsCount,
    };
  }
}

class SearchDecisionResponse {
  final GuidanceAction action;
  final String guidanceText;
  final SearchState nextState;
  final String reason;

  const SearchDecisionResponse({
    required this.action,
    required this.guidanceText,
    required this.nextState,
    required this.reason,
  });

  factory SearchDecisionResponse.fromJson(Map<String, dynamic> json) {
    return SearchDecisionResponse(
      action: GuidanceAction.fromCode(
        json['action'] as String? ?? 'CONTINUE_SCANNING',
      ),
      guidanceText: json['guidance_text'] as String? ?? 'Scanning...',
      nextState: SearchState.fromCode(
        json['next_state'] as String? ?? 'SEARCHING',
      ),
      reason: json['reason'] as String? ?? '',
    );
  }
}
