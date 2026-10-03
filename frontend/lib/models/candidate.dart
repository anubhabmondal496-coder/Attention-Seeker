import 'target_profile.dart';

class BoundingBox {
  final double ymin;
  final double xmin;
  final double ymax;
  final double xmax;

  const BoundingBox({
    required this.ymin,
    required this.xmin,
    required this.ymax,
    required this.xmax,
  });

  double get width => (xmax - xmin).clamp(0.0, 1.0);
  double get height => (ymax - ymin).clamp(0.0, 1.0);

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      ymin: (json['ymin'] as num).toDouble(),
      xmin: (json['xmin'] as num).toDouble(),
      ymax: (json['ymax'] as num).toDouble(),
      xmax: (json['xmax'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ymin': ymin,
      'xmin': xmin,
      'ymax': ymax,
      'xmax': xmax,
    };
  }
}

class Candidate {
  final String id;
  final BoundingBox boundingBox;
  final double confidence;
  final double areaRatio;
  final double aspectRatio;
  final String? cropBase64;
  final String reason;

  const Candidate({
    required this.id,
    required this.boundingBox,
    required this.confidence,
    required this.areaRatio,
    required this.aspectRatio,
    this.cropBase64,
    required this.reason,
  });

  factory Candidate.fromJson(Map<String, dynamic> json) {
    return Candidate(
      id: json['id'] as String? ?? '',
      boundingBox: BoundingBox.fromJson(
        json['bounding_box'] as Map<String, dynamic>,
      ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      areaRatio: (json['area_ratio'] as num?)?.toDouble() ?? 0.0,
      aspectRatio: (json['aspect_ratio'] as num?)?.toDouble() ?? 1.0,
      cropBase64: json['crop_base64'] as String?,
      reason: json['reason'] as String? ?? '',
    );
  }
}

class CandidateDetectResponse {
  final bool candidateFound;
  final SearchState state;
  final List<Candidate> candidates;
  final Candidate? bestCandidate;
  final String message;

  const CandidateDetectResponse({
    required this.candidateFound,
    required this.state,
    required this.candidates,
    this.bestCandidate,
    required this.message,
  });

  factory CandidateDetectResponse.fromJson(Map<String, dynamic> json) {
    final rawCandidates = (json['candidates'] as List<dynamic>?) ?? [];
    return CandidateDetectResponse(
      candidateFound: json['candidate_found'] as bool? ?? false,
      state: SearchState.fromCode(
        json['state'] as String? ?? 'SEARCHING',
      ),
      candidates: rawCandidates
          .map((c) => Candidate.fromJson(c as Map<String, dynamic>))
          .toList(),
      bestCandidate: json['best_candidate'] != null
          ? Candidate.fromJson(
              json['best_candidate'] as Map<String, dynamic>,
            )
          : null,
      message: json['message'] as String? ?? '',
    );
  }
}
