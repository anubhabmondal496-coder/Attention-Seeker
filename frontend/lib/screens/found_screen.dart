import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/target_profile.dart';
import '../models/verification.dart';
import '../services/api_service.dart';
import '../services/accessibility_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class FoundScreen extends StatefulWidget {
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

  @override
  State<FoundScreen> createState() => _FoundScreenState();
}

class _FoundScreenState extends State<FoundScreen> {
  @override
  void initState() {
    super.initState();
    _announceDiscovery();
  }

  void _announceDiscovery() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        a11yService.triggerHaptic(HapticType.success);
        final reason = widget.verificationResult.reason;
        a11yService.announce(
          'Target found! ${widget.targetProfile.primaryColor} ${widget.targetProfile.objectType} verified with ${(widget.verificationResult.confidence * 100).toInt()}% confidence. $reason Double tap Search Again to look for another item.',
        );
      }
    });
  }

  Uint8List? _getImageBytes() {
    if (widget.candidateImageBytes != null) return widget.candidateImageBytes;
    if (widget.candidateCropBase64 != null && widget.candidateCropBase64!.isNotEmpty) {
      try {
        return base64Decode(widget.candidateCropBase64!);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = _getImageBytes();
    final isHC = a11yService.isHighContrastMode;
    final vr = widget.verificationResult;
    final tp = widget.targetProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Discovered!'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Read discovery findings aloud',
            icon: const Icon(Icons.volume_up, color: AppTheme.statusFound),
            onPressed: () {
              a11yService.announce(
                'Target discovered! ${tp.primaryColor} ${tp.objectType}. Findings: ${vr.reason}.',
              );
            },
          ),
          IconButton(
            tooltip: 'Toggle High Contrast Mode',
            icon: Icon(
              isHC ? Icons.visibility : Icons.visibility_outlined,
              color: AppTheme.accent,
            ),
            onPressed: () => a11yService.toggleHighContrast(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Spoken summary banner for low vision
              Semantics(
                button: true,
                label: 'Listen to discovery report aloud',
                child: InkWell(
                  onTap: () {
                    a11yService.announce(
                      'Object found! ${tp.primaryColor} ${tp.objectType} confirmed. ${vr.reason}',
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isHC ? const Color(0xFF1B2B1B) : AppTheme.surfaceElevated,
                      border: Border.all(
                        color: isHC ? const Color(0xFF00FF66) : AppTheme.statusFound,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.statusFound, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Object Discovered! Tap to replay voice announcement.',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Verified Candidate Crop Display
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: isHC ? Colors.black : AppTheme.surface,
                  border: Border.all(
                    color: isHC ? Colors.white : AppTheme.statusFound,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7.0),
                  child: Center(
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                          )
                        : const Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: AppTheme.statusFound,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 3. Status Header & Match Percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'FOUND: ${tp.objectType.toUpperCase()}',
                      style: const TextStyle(
                        color: AppTheme.statusFound,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      border: Border.all(color: AppTheme.statusFound),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(vr.confidence * 100).toInt()}% CONFIRMED',
                      style: const TextStyle(
                        color: AppTheme.statusFound,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 14),

              // 4. Forensic Verification Findings
              const Text(
                'AI Reasoning & Findings',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                vr.reason,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 16),

              // 5. Verified Features Checklist
              if (vr.matchingFeatures.isNotEmpty) ...[
                const Text(
                  'Matching Distinguishing Markers',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...vr.matchingFeatures.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 5.0, right: 8.0),
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: AppTheme.statusFound,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
              Semantics(
                label: 'Search again button. Double tap to return to home and start a new search.',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: () {
                    a11yService.triggerHaptic(HapticType.selection);
                    if (widget.sessionId != null) {
                      ApiService.completeSession(
                        sessionId: widget.sessionId!,
                        reason: 'User acknowledged found target and finished search.',
                      ).then((_) {}).catchError((_) => null, test: (_) => true);
                    }
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Search Again'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
