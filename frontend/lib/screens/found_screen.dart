import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/target_profile.dart';
import '../models/verification.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class FoundScreen extends StatelessWidget {
  final String? sessionId;
  final TargetProfile targetProfile;
  final VerificationResult verificationResult;
  final Uint8List? candidateImageBytes;
  final String? candidateCropBase64;

  const FoundScreen({
    super.key,
    this.sessionId,
    required this.targetProfile,
    required this.verificationResult,
    this.candidateImageBytes,
    this.candidateCropBase64,
  });

  Uint8List? _getImageBytes() {
    if (candidateImageBytes != null) return candidateImageBytes;
    if (candidateCropBase64 != null && candidateCropBase64!.isNotEmpty) {
      try {
        return base64Decode(candidateCropBase64!);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _getImageBytes();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Outcome'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Candidate Crop Display
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.statusFound),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Center(
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                          )
                        : const Icon(
                            Icons.check_circle_outline,
                            size: 48,
                            color: AppTheme.statusFound,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Verified Status Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: AppTheme.statusFound),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.verified,
                          size: 18,
                          color: AppTheme.statusFound,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'OBJECT FOUND',
                          style: TextStyle(
                            color: AppTheme.statusFound,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(verificationResult.confidence * 100).toInt()}% Confirmed',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Target Name
              Text(
                targetProfile.objectType.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Short explanation from Gemma
              Text(
                verificationResult.reason,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),

              // Verified Features Checklist
              if (verificationResult.matchingFeatures.isNotEmpty) ...[
                const Text(
                  'Verified Target Features',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...verificationResult.matchingFeatures.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5.0, right: 8.0),
                          child: Icon(
                            Icons.fiber_manual_record,
                            size: 6,
                            color: AppTheme.statusFound,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 24),

              // Button: Search Again
              ElevatedButton(
                onPressed: () {
                  if (sessionId != null) {
                    ApiService.completeSession(
                      sessionId: sessionId!,
                      reason: 'User acknowledged found target and finished search.',
                    ).then((_) {}).catchError((_) => null, test: (_) => true);
                  }
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Search Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
