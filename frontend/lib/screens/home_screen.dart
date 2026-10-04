import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'add_target_screen.dart';
import 'legal_dialogs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCheckingBackend = true;
  bool _backendOnline = false;

  @override
  void initState() {
    super.initState();
    _checkBackendStatus();
  }

  Future<void> _checkBackendStatus() async {
    setState(() => _isCheckingBackend = true);
    final online = await ApiService.checkHealth();
    if (mounted) {
      setState(() {
        _backendOnline = online;
        _isCheckingBackend = false;
      });
    }
  }

  void _showHowItWorksModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10.0)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Methodology',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildStepRow(
              number: '1',
              title: 'Provide Target Reference',
              description:
                  'Photograph the exact lost object and add any distinguishing details.',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              number: '2',
              title: 'Gemma Multimodal Profiling',
              description:
                  'Gemma establishes precise target features (colors, seam stitches, logos, materials).',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              number: '3',
              title: 'Environmental Scanning',
              description:
                  'Use your camera to scan the area. Follow directional guidance prompts.',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              number: '4',
              title: 'Multimodal Verification',
              description:
                  'Candidates are cropped and rigorously verified before confirming discovery.',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got It'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attention Seeker'),
        actions: [
          IconButton(
            tooltip: 'Refresh backend status',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _checkBackendStatus,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backend connectivity status bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(
                    color: _backendOnline
                        ? AppTheme.border
                        : AppTheme.statusError.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isCheckingBackend
                            ? AppTheme.statusIdle
                            : (_backendOnline
                                ? AppTheme.statusFound
                                : AppTheme.statusError),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isCheckingBackend
                          ? 'Checking backend connection...'
                          : (_backendOnline
                              ? 'Inference Engine Ready'
                              : 'Backend Offline (${ApiService.baseUrl})'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _backendOnline
                            ? AppTheme.textSecondary
                            : AppTheme.statusError,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // App Logo Emblem
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title and Tagline
              const Text(
                'Attention Seeker',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Find what you lost.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Show Attention Seeker what you\'re looking for, then scan your surroundings.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),

              const Spacer(flex: 3),

              // Primary Action
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddTargetScreen(),
                    ),
                  );
                },
                child: const Text('Start Search'),
              ),
              const SizedBox(height: 12),

              // Secondary Action
              OutlinedButton(
                onPressed: _showHowItWorksModal,
                child: const Text('How it works'),
              ),

              const SizedBox(height: 24),

              // Policy links footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => showPrivacyPolicyDialog(context),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('•', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  GestureDetector(
                    onTap: () => showTermsOfServiceDialog(context),
                    child: const Text(
                      'Terms of Service',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
