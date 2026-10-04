import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/target_profile.dart';
import '../theme/app_theme.dart';
import '../services/accessibility_service.dart';
import 'search_screen.dart';

class ConfirmTargetScreen extends StatefulWidget {
  final TargetProfile targetProfile;
  final Uint8List? imageBytes;
  final String? imagePath;

  const ConfirmTargetScreen({
    super.key,
    required this.targetProfile,
    this.imageBytes,
    this.imagePath,
  });

  @override
  State<ConfirmTargetScreen> createState() => _ConfirmTargetScreenState();
}

class _ConfirmTargetScreenState extends State<ConfirmTargetScreen> {
  @override
  void initState() {
    super.initState();
    _announceProfile();
  }

  void _announceProfile() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final tp = widget.targetProfile;
        final featText = tp.distinctiveFeatures.isNotEmpty
            ? 'Key features: ${tp.distinctiveFeatures.take(2).join(", ")}.'
            : '';
        a11yService.announce(
          'Target confirmed: ${tp.primaryColor} ${tp.objectType}. $featText Double tap Start Search to begin camera search.',
        );
      }
    });
  }

  void _readAloudDetails() {
    final tp = widget.targetProfile;
    final text = 'Target: ${tp.objectType}. Color: ${tp.primaryColor}. Shape: ${tp.shape}. Material: ${tp.material}. Features: ${tp.distinctiveFeatures.join(", ")}.';
    a11yService.announce(text);
  }

  @override
  Widget build(BuildContext context) {
    final tp = widget.targetProfile;
    final isHC = a11yService.isHighContrastMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Confirmation'),
        actions: [
          IconButton(
            tooltip: 'Read details aloud',
            icon: const Icon(Icons.volume_up, color: AppTheme.accent),
            onPressed: _readAloudDetails,
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
              // Spoken audio summary banner
              Semantics(
                button: true,
                label: 'Listen to target description aloud',
                child: InkWell(
                  onTap: _readAloudDetails,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isHC ? const Color(0xFF1E1E1E) : AppTheme.surfaceElevated,
                      border: Border.all(
                        color: isHC ? Colors.white : AppTheme.accent.withValues(alpha: 0.6),
                        width: isHC ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.volume_up, color: AppTheme.accent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap here to read target profile aloud',
                            style: TextStyle(
                              fontSize: 13,
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

              // Reference image preview (or acoustic icon placeholder if voice-only)
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: isHC ? Colors.black : AppTheme.surface,
                  border: Border.all(
                    color: isHC ? Colors.white : AppTheme.border,
                    width: isHC ? 2.0 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7.0),
                  child: Center(
                    child: widget.imageBytes != null
                        ? Image.memory(
                            widget.imageBytes!,
                            fit: BoxFit.contain,
                          )
                        : (widget.imagePath != null
                            ? Image.file(
                                File(widget.imagePath!),
                                fit: BoxFit.contain,
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.mic,
                                    size: 48,
                                    color: isHC ? AppTheme.hcAccent : AppTheme.accent,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Voice-Profiled Target',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Target Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      tp.objectType.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      border: Border.all(color: isHC ? Colors.white : AppTheme.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(tp.confidence * 100).toInt()}% Match Profile',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),

              // Key physical characteristics
              _buildCharacteristicRow('Primary Color', tp.primaryColor),
              if (tp.secondaryColor != null && tp.secondaryColor!.isNotEmpty)
                _buildCharacteristicRow('Secondary Color', tp.secondaryColor!),
              _buildCharacteristicRow('Shape', tp.shape),
              _buildCharacteristicRow('Material', tp.material),

              if (tp.userDescription != null && tp.userDescription!.isNotEmpty)
                _buildCharacteristicRow('Voice / Clue', tp.userDescription!),

              const SizedBox(height: 16),

              // Distinctive Features
              const Text(
                'Distinctive Identifying Features',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              if (tp.distinctiveFeatures.isEmpty)
                const Text(
                  'Standard appearance',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                )
              else
                ...tp.distinctiveFeatures.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6.0, right: 8.0),
                          child: Icon(
                            Icons.fiber_manual_record,
                            size: 8,
                            color: AppTheme.accent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Start Search button
              Semantics(
                label: 'Start search button. Double tap to activate camera search with spoken guidance.',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: () {
                    a11yService.triggerHaptic(HapticType.selection);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(
                          targetProfile: widget.targetProfile,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam, size: 22),
                  label: const Text('Start Search'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacteristicRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
