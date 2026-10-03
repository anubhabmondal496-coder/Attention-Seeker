import 'target_profile.dart';

enum VerificationStatus {
  notAMatch('NOT_A_MATCH', 'Not a Match'),
  possibleMatch('POSSIBLE_MATCH', 'Possible Match'),
  likelyMatch('LIKELY_MATCH', 'Likely Match'),
  found('FOUND', 'Object Found');

  final String code;
  final String label;
  const VerificationStatus(this.code, this.label);

  static VerificationStatus fromCode(String code) {
    return VerificationStatus.values.firstWhere(
      (s) => s.code == code.toUpperCase().trim(),
      orElse: () => VerificationStatus.possibleMatch,
    );
  }
}

class VerificationResult {
  final VerificationStatus status;
  final double confidence;
  final String reason;
  final String guidance;
  final List<String> matchingFeatures;
  final List<String> missingOrDifferingFeatures;

  const VerificationResult({
    required this.status,
    required this.confidence,
    required this.reason,
    required this.guidance,
    required this.matchingFeatures,
    required this.missingOrDifferingFeatures,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      status: VerificationStatus.fromCode(
        json['status'] as String? ?? 'POSSIBLE_MATCH',
      ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.7,
      reason: json['reason'] as String? ?? '',
      guidance: json['guidance'] as String? ?? 'Move closer.',
      matchingFeatures: (json['matching_features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      missingOrDifferingFeatures: (json['missing_or_differing_features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class VerifyCandidateResponse {
  final VerificationStatus status;
  final SearchState state;
  final VerificationResult result;
  final String message;

  const VerifyCandidateResponse({
    required this.status,
    required this.state,
    required this.result,
    required this.message,
  });

  factory VerifyCandidateResponse.fromJson(Map<String, dynamic> json) {
    return VerifyCandidateResponse(
      status: VerificationStatus.fromCode(
        json['status'] as String? ?? 'POSSIBLE_MATCH',
      ),
      state: SearchState.fromCode(
        json['state'] as String? ?? 'VERIFYING',
      ),
      result: VerificationResult.fromJson(
        json['result'] as Map<String, dynamic>,
      ),
      message: json['message'] as String? ?? '',
    );
  }
}
