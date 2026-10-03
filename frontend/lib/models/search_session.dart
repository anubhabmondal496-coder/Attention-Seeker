import 'target_profile.dart';

class StateTransitionRecord {
  final SearchState fromState;
  final SearchState toState;
  final String reason;
  final String timestamp;

  const StateTransitionRecord({
    required this.fromState,
    required this.toState,
    required this.reason,
    required this.timestamp,
  });

  factory StateTransitionRecord.fromJson(Map<String, dynamic> json) {
    return StateTransitionRecord(
      fromState: SearchState.fromCode(json['from_state'] as String? ?? 'IDLE'),
      toState: SearchState.fromCode(json['to_state'] as String? ?? 'IDLE'),
      reason: json['reason'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_state': fromState.code,
      'to_state': toState.code,
      'reason': reason,
      'timestamp': timestamp,
    };
  }
}

class SearchSession {
  final String sessionId;
  final SearchState state;
  final TargetProfile? targetProfile;
  final String createdAt;
  final String updatedAt;
  final double durationSeconds;
  final int attemptsCount;
  final int candidatesEvaluated;
  final List<StateTransitionRecord> history;
  final bool isActive;

  const SearchSession({
    required this.sessionId,
    required this.state,
    this.targetProfile,
    required this.createdAt,
    required this.updatedAt,
    required this.durationSeconds,
    required this.attemptsCount,
    required this.candidatesEvaluated,
    required this.history,
    required this.isActive,
  });

  factory SearchSession.fromJson(Map<String, dynamic> json) {
    return SearchSession(
      sessionId: json['session_id'] as String? ?? '',
      state: SearchState.fromCode(json['state'] as String? ?? 'SEARCHING'),
      targetProfile: json['target_profile'] != null
          ? TargetProfile.fromJson(json['target_profile'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      attemptsCount: json['attempts_count'] as int? ?? 0,
      candidatesEvaluated: json['candidates_evaluated'] as int? ?? 0,
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => StateTransitionRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'state': state.code,
      'target_profile': targetProfile?.toJson(),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'duration_seconds': durationSeconds,
      'attempts_count': attemptsCount,
      'candidates_evaluated': candidatesEvaluated,
      'history': history.map((e) => e.toJson()).toList(),
      'is_active': isActive,
    };
  }
}

class SessionResponse {
  final bool success;
  final SearchSession session;
  final String message;

  const SessionResponse({
    required this.success,
    required this.session,
    required this.message,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      success: json['success'] as bool? ?? false,
      session: SearchSession.fromJson(json['session'] as Map<String, dynamic>),
      message: json['message'] as String? ?? '',
    );
  }
}
