import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/accessibility_service.dart';
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

  // Video background controller
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideoBackground();
    _checkBackendStatus();
    _announceWelcome();
  }

  Future<void> _initVideoBackground() async {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/1004.mp4');
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(0.0); // Muted background loop for clear TTS
      _videoController!.play();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Video background fallback: $e');
    }
  }

  void _announceWelcome() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        a11yService.announce(
          'Welcome to Attention Seeker. Accessible object locator. Double tap Start Search to begin, or double tap the microphone button on the next screen to voice type your item.',
        );
      }
    });
  }

  Future<void> _checkBackendStatus() async {
    setState(() => _isCheckingBackend = true);
    final online = await ApiService.checkHealth();
    if (mounted) {
      setState(() {
        _backendOnline = online;
        _isCheckingBackend = false;
      });
      a11yService.triggerHaptic(HapticType.light);
    }
  }

  void _showAccessibilitySheet() {
    a11yService.triggerHaptic(HapticType.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(a11yService.isHighContrastMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
      ),
      builder: (ctx) => ListenableBuilder(
        listenable: a11yService,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vision & Accessibility Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(
                  'High Contrast Mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Ultra-high contrast black & vivid gold for low vision'),
                value: a11yService.isHighContrastMode,
                onChanged: (_) => a11yService.toggleHighContrast(),
              ),
              SwitchListTile(
                title: const Text(
                  'Large Typography',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Enlarges fonts across all screens by 125%'),
                value: a11yService.isLargeFontMode,
                onChanged: (_) => a11yService.toggleLargeFont(),
              ),
              SwitchListTile(
                title: const Text(
                  'Haptic Vibration Feedback',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Tactile clicks when targets and guidance are detected'),
                value: a11yService.isHapticsEnabled,
                onChanged: (_) => a11yService.toggleHaptics(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close Settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowItWorksModal() {
    a11yService.triggerHaptic(HapticType.selection);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getSurfaceColor(a11yService.isHighContrastMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Methodology & Voice Guidance',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildStepRow(
              number: '1',
              title: 'Provide Target Reference or Voice Type',
              description:
                  'Take a photo of your lost item or speak its description hands-free using Voice Typing.',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              number: '2',
              title: 'Gemma Multimodal Visual Profiling',
              description:
                  'AI profiles precise visual signatures (colors, shapes, textures, materials, and logos).',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              number: '3',
              title: 'Hands-Free Spoken Navigation',
              description:
                  'Scan the room or garden. Real-time voice guidance directs you: "Look lower", "Pan right", "Move closer".',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              number: '4',
              title: 'Up to 4x Progressive Zoom Verification',
              description:
                  'The AI zooms up to 4x into cluttered bushes or desks and confirms when your exact object is found.',
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
            color: AppTheme.accentMuted,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
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
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHC = a11yService.isHighContrastMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Attention Seeker'),
        actions: [
          IconButton(
            tooltip: 'Accessibility and vision options',
            icon: const Icon(Icons.accessibility_new, size: 22),
            onPressed: _showAccessibilitySheet,
          ),
          IconButton(
            tooltip: 'Refresh backend status',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _checkBackendStatus,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video background loop (1004.mp4) or fallback solid dark background
          if (_isVideoInitialized && _videoController != null && !isHC)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            Container(color: isHC ? AppTheme.hcBackground : AppTheme.background),

          // 2. Translucent dark overlay to guarantee WCAG AAA contrast for text and controls
          Container(
            color: isHC
                ? Colors.transparent
                : Colors.black.withValues(alpha: _isVideoInitialized ? 0.72 : 0.0),
          ),

          // 3. Foreground content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Accessibility quick toggle banner
                  Semantics(
                    label: 'High contrast vision quick toggle',
                    button: true,
                    child: InkWell(
                      onTap: () => a11yService.toggleHighContrast(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isHC
                              ? const Color(0xFF222222)
                              : AppTheme.background.withValues(alpha: 0.85),
                          border: Border.all(
                            color: isHC ? Colors.white : AppTheme.border,
                            width: isHC ? 1.5 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isHC ? Icons.visibility : Icons.visibility_outlined,
                              size: 18,
                              color: AppTheme.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isHC
                                    ? 'High Contrast Mode Active (Tap to toggle)'
                                    : 'Tap for High Contrast & Low Vision Mode',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Backend connectivity status bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.background.withValues(alpha: 0.85),
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

                  // App Logo Emblem with high contrast support
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
                            color: Colors.black.withValues(alpha: 0.4),
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

                  const SizedBox(height: 24),

                  // Title and Tagline
                  const Text(
                    'Attention Seeker',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Find what you lost with voice & vision.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Designed for visually impaired and sighted users. Speak your item or take a photo, then follow real-time spoken guidance.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Primary Action - Start Search
                  Semantics(
                    label: 'Start search button. Double tap to select or describe lost object.',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        a11yService.triggerHaptic(HapticType.selection);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddTargetScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Start Search'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary Action
                  OutlinedButton.icon(
                    onPressed: _showHowItWorksModal,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('How it works & Spoken Guidance'),
                  ),

                  const SizedBox(height: 20),

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
        ],
      ),
    );
  }
}
