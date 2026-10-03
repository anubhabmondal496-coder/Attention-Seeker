import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/target_profile.dart';
import '../models/candidate.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  final TargetProfile targetProfile;

  const SearchScreen({
    super.key,
    required this.targetProfile,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _cameraUnavailable = false;
  String _cameraError = '';

  // Periodic sampling state
  Timer? _samplingTimer;
  bool _isProcessingFrame = false;
  bool _isDisposed = false;

  // Runtime search state
  SearchState _currentState = SearchState.searching;
  String _guidanceText = 'Scanning... Hold steady while scanning.';
  Candidate? _currentCandidate;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraUnavailable = true;
            _cameraError = 'No physical camera device detected on this system.';
          });
        }
        return;
      }

      final backCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _availableCameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _cameraUnavailable = false;
      });

      _startFrameSampling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraUnavailable = true;
        _cameraError = 'Camera initialization failed: $e';
      });
    }
  }

  void _startFrameSampling() {
    _samplingTimer?.cancel();
    // Sample frames periodically (every 1800 ms) to keep latency low and avoid bandwidth saturation
    _samplingTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      _sampleAndDetectFrame();
    });
  }

  Future<void> _sampleAndDetectFrame() async {
    if (_isProcessingFrame || _isDisposed) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _isProcessingFrame = true;

    try {
      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();

      if (_isDisposed || !mounted) return;

      final response = await ApiService.detectCandidate(
        frameBytes: bytes,
        targetProfile: widget.targetProfile,
      );

      if (_isDisposed || !mounted) return;

      setState(() {
        if (response.candidateFound && response.bestCandidate != null) {
          _currentState = SearchState.candidateDetected;
          _currentCandidate = response.bestCandidate;
          _guidanceText = 'Possible match detected. Move closer.';
        } else {
          _currentState = SearchState.searching;
          _currentCandidate = null;
          _guidanceText = 'Scanning... Move camera slowly.';
        }
      });
    } catch (_) {
      // Keep search active on transient frame errors
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _samplingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Feed (or fallback viewfinder)
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else if (_cameraUnavailable)
            _buildCameraFallbackView()
          else
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent,
                ),
              ),
            ),

          // 2. Viewfinder Reticle
          _buildViewfinderReticle(),

          // 3. Dynamic Candidate Bounding Box Overlay
          if (_currentCandidate != null)
            _buildCandidateBoundingBoxOverlay(_currentCandidate!),

          // 4. Top HUD: Target Tag & Search State Badge
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.background.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 18,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),

                    // Target tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Text(
                        'TARGET: ${widget.targetProfile.objectType.toUpperCase()}',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    // State Indicator Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _currentState == SearchState.candidateDetected
                              ? AppTheme.statusCandidate
                              : AppTheme.statusSearching,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentState == SearchState.candidateDetected
                                  ? AppTheme.statusCandidate
                                  : AppTheme.statusSearching,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentState.code,
                            style: TextStyle(
                              color: _currentState == SearchState.candidateDetected
                                  ? AppTheme.statusCandidate
                                  : AppTheme.statusSearching,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Bottom HUD: Real-time Guidance and Action Controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Guidance banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _currentState == SearchState.candidateDetected
                              ? AppTheme.statusCandidate
                              : AppTheme.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _guidanceText,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isProcessingFrame
                                ? 'Sampling frame...'
                                : (_currentState == SearchState.candidateDetected
                                    ? 'Candidate region locked. Move closer to verify.'
                                    : 'Hold phone steady and scan surroundings slowly.'),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stop search button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppTheme.background.withValues(alpha: 0.8),
                        side: const BorderSide(color: AppTheme.border),
                        minimumSize: const Size(double.infinity, 44),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Stop Search'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateBoundingBoxOverlay(Candidate candidate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = candidate.boundingBox;
        final left = box.xmin * constraints.maxWidth;
        final top = box.ymin * constraints.maxHeight;
        final width = box.width * constraints.maxWidth;
        final height = box.height * constraints.maxHeight;

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent, width: 2.0),
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -24,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'CANDIDATE ${(candidate.confidence * 100).toInt()}%',
                        style: const TextStyle(
                          color: Color(0xFF0E1116),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewfinderReticle() {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppTheme.border, width: 1.5),
                      left: BorderSide(color: AppTheme.border, width: 1.5),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppTheme.border, width: 1.5),
                      right: BorderSide(color: AppTheme.border, width: 1.5),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.border, width: 1.5),
                      left: BorderSide(color: AppTheme.border, width: 1.5),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.border, width: 1.5),
                      right: BorderSide(color: AppTheme.border, width: 1.5),
                    ),
                  ),
                ),
              ),
              const Center(
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.border,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraFallbackView() {
    return Container(
      color: const Color(0xFF0D1016),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_outlined,
                size: 48,
                color: AppTheme.textMuted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Viewfinder Active (Simulated)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _cameraError.isNotEmpty
                    ? _cameraError
                    : 'Physical camera preview active when running on mobile device.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
