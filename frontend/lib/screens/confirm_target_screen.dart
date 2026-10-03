import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/target_profile.dart';
import '../theme/app_theme.dart';
import 'search_screen.dart';

class ConfirmTargetScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Target Confirmation'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reference image preview
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Center(
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes!,
                            fit: BoxFit.contain,
                          )
                        : (imagePath != null
                            ? Image.file(
                                File(imagePath!),
                                fit: BoxFit.contain,
                              )
                            : const Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: AppTheme.textMuted,
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
                      targetProfile.objectType.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceElevated,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(targetProfile.confidence * 100).toInt()}% Match Profile',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 16),

              // Characteristics Grid / Key-Values
              _buildCharacteristicRow('Primary Color', targetProfile.primaryColor),
              if (targetProfile.secondaryColor != null &&
                  targetProfile.secondaryColor!.isNotEmpty)
                _buildCharacteristicRow('Secondary Color', targetProfile.secondaryColor!),
              _buildCharacteristicRow('Shape', targetProfile.shape),
              _buildCharacteristicRow('Material', targetProfile.material),

              if (targetProfile.userDescription != null &&
                  targetProfile.userDescription!.isNotEmpty)
                _buildCharacteristicRow(
                  'User Context',
                  targetProfile.userDescription!,
                ),

              const SizedBox(height: 14),

              // Distinctive Features
              const Text(
                'Distinctive Identifying Features',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              if (targetProfile.distinctiveFeatures.isEmpty)
                const Text(
                  'None identified',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                )
              else
                ...targetProfile.distinctiveFeatures.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6.0, right: 8.0),
                          child: Icon(
                            Icons.fiber_manual_record,
                            size: 6,
                            color: AppTheme.accent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Action button
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(
                        targetProfile: targetProfile,
                      ),
                    ),
                  );
                },
                child: const Text('Start Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacteristicRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
