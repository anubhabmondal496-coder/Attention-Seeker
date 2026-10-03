enum SearchState {
  idle('IDLE', 'Idle'),
  targetReady('TARGET_READY', 'Target Ready'),
  searching('SEARCHING', 'Searching'),
  candidateDetected('CANDIDATE_DETECTED', 'Candidate Detected'),
  verifying('VERIFYING', 'Verifying'),
  guiding('GUIDING', 'Guiding'),
  found('FOUND', 'Target Found'),
  searchComplete('SEARCH_COMPLETE', 'Search Complete');

  final String code;
  final String label;
  const SearchState(this.code, this.label);

  static SearchState fromCode(String code) {
    return SearchState.values.firstWhere(
      (s) => s.code == code,
      orElse: () => SearchState.idle,
    );
  }
}

class TargetProfile {
  final String objectType;
  final String primaryColor;
  final String? secondaryColor;
  final String shape;
  final String material;
  final List<String> distinctiveFeatures;
  final String? userDescription;
  final double confidence;

  TargetProfile({
    required this.objectType,
    required this.primaryColor,
    this.secondaryColor,
    required this.shape,
    required this.material,
    required this.distinctiveFeatures,
    this.userDescription,
    required this.confidence,
  });

  factory TargetProfile.fromJson(Map<String, dynamic> json) {
    return TargetProfile(
      objectType: json['object_type'] as String? ?? 'Unknown Object',
      primaryColor: json['primary_color'] as String? ?? 'Unknown',
      secondaryColor: json['secondary_color'] as String?,
      shape: json['shape'] as String? ?? 'Unknown',
      material: json['material'] as String? ?? 'Unknown',
      distinctiveFeatures: (json['distinctive_features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      userDescription: json['user_description'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'object_type': objectType,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'shape': shape,
      'material': material,
      'distinctive_features': distinctiveFeatures,
      'user_description': userDescription,
      'confidence': confidence,
    };
  }
}

class TargetAnalyzeResponse {
  final TargetProfile targetProfile;
  final SearchState state;
  final String summary;

  TargetAnalyzeResponse({
    required this.targetProfile,
    required this.state,
    required this.summary,
  });

  factory TargetAnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return TargetAnalyzeResponse(
      targetProfile: TargetProfile.fromJson(
        json['target_profile'] as Map<String, dynamic>,
      ),
      state: SearchState.fromCode(json['state'] as String? ?? 'TARGET_READY'),
      summary: json['summary'] as String? ?? '',
    );
  }
}
