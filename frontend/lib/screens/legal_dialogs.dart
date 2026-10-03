import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

void showPrivacyPolicyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Text(
        'Privacy Policy',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const SingleChildScrollView(
        child: Text(
          'Attention Seeker processes visual camera input solely to locate your specified lost physical object.\n\n'
          '1. Camera Data: Live camera frames are processed in-memory for visual candidate detection and are never permanently stored, sold, or retained on servers.\n\n'
          '2. Target Reference: Photos of lost objects are analyzed temporarily to establish physical target characteristics and discarded after the search session ends.\n\n'
          '3. Security: All inference requests are authenticated using server-side tokens and protected in transit.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close', style: TextStyle(color: AppTheme.accent)),
        ),
      ],
    ),
  );
}

void showTermsOfServiceDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: const Text(
        'Terms of Service',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: const SingleChildScrollView(
        child: Text(
          '1. Visual Assistance: Attention Seeker is a visual search aid designed to help locate physical objects. It does not control physical hardware or robots.\n\n'
          '2. Physical Safety: You are solely responsible for your own safety and surroundings while moving through the environment.\n\n'
          '3. Verification: While Gemma multimodal reasoning performs rigorous verification, users should confirm the identity of located items.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close', style: TextStyle(color: AppTheme.accent)),
        ),
      ],
    ),
  );
}
