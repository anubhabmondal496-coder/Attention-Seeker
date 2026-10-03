import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/target_profile.dart';
import '../models/candidate.dart';
import '../models/verification.dart';
import '../models/guidance.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import 'found_screen.dart';

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

  // Phase 6 Search Session tracking
  String _sessionId = 'seek_${DateTime.now().millisecondsSinceEpoch}';
  int _candidatesEvaluated = 0;

  // Phase 8 Voice Guidance state
  bool _voiceEnabled = true;

  // Periodic sampling state
  Timer? _samplingTimer;
  bool _isProcessingFrame = false;
  bool _isVerifying = false;
  bool _isDisposed = false;
  int _attemptsCount = 0;

  // Runtime search state
  SearchState _currentState = SearchState.searching;
  String _guidanceText = 'Scanning... Hold steady while scanning.';
  GuidanceAction _currentAction = GuidanceAction.continueScanning;
  Candidate? _currentCandidate;

  // Device orientation tracking via sensors_plus
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  double _pitch = 0.0;
  double _roll = 0.0;

  @override
  void initState() {
    super.initState();
    _initSensors();
    _initVoice();
    _initSession();
    _initCamera();
  }

  Future<void> _initVoice() async {
    await voiceGuidance.init();
    _voiceEnabled = voiceGuidance.isEnabled;
  }

  Future<void> _initSession() async {
    try {
      final res = await ApiService.startSession(
        targetProfile: widget.targetProfile,
        sessionId: _sessionId,
      );
      if (res.success && mounted) {
        setState(() {
          _sessionId = res.session.sessionId;
        });
      }
    } catch (_) {}
  }

  Future<void> _syncState(SearchState nextState, String reason) async {
    if (_currentState == nextState) return;
    try {
      await ApiService.transitionState(
        sessionId: _sessionId,
        toState: nextState,
        reason: reason,
      );
    } catch (_) {}
  }

  void _initSensors() {
    try {
      _accelSubscription = accelerometerEventStream().listen(
        (event) {
          if (_isDisposed) return;
          // Calculate pitch & roll from gravity vector
          _pitch = event.z;
          _roll = event.x;
        },
        onError: (_) {},
      );
    } catch (_) {}
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
    _samplingTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      _sampleAndDetectFrame();
    });
  }

  Future<void> _sampleAndDetectFrame() async {
    if (_isProcessingFrame || _isVerifying || _isDisposed) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _isProcessingFrame = true;
    _attemptsCount++;

    try {
      final XFile picture = await _cameraController!.takePicture();
      final bytes = await picture.readAsBytes();

      if (_isDisposed || !mounted) return;

      final response = await ApiService.detectCandidate(
        frameBytes: bytes,
        targetProfile: widget.targetProfile,
      );

      if (_isDisposed || !mounted) return;

      if (response.candidateFound && response.bestCandidate != null) {
        final candidate = response.bestCandidate!;
        _currentCandidate = candidate;

        // Transition: SEARCHING -> CANDIDATE_DETECTED
        _syncState(SearchState.candidateDetected, 'Fast CV detected region of interest');

        // Query directional decision agent for optimal centering guidance
        await _fetchGuidanceDecision(
          candidate: candidate,
          state: SearchState.candidateDetected,
        );

        // Trigger Phase 4: Gemma Multimodal Verification
        await _verifyCandidate(candidate);
      } else {
        _currentCandidate = null;
        if (_currentState != SearchState.searching) {
          _syncState(SearchState.searching, 'No candidate in view, continuing sweep');
        }
        await _fetchGuidanceDecision(
          candidate: null,
          state: SearchState.searching,
        );
      }
    } catch (_) {
      // Keep search active on transient frame errors
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _fetchGuidanceDecision({
    Candidate? candidate,
    required SearchState state,
    VerificationStatus? verificationStatus,
  }) async {
    try {
      final decision = await ApiService.getSearchDecision(
        SearchDecisionRequest(
          sessionId: _sessionId,
          currentState: state,
          candidate: candidate,
          verificationStatus: verificationStatus,
          orientation: DeviceOrientationData(
            pitch: _pitch,
            roll: _roll,
          ),
          attemptsCount: _attemptsCount,
        ),
      );

      if (_isDisposed || !mounted) return;

      // Phase 7: Record observation into spatial memory
      ApiService.recordObservation(
        sessionId: _sessionId,
        pitch: _pitch,
        roll: _roll,
        guidance: decision.guidanceText,
      );

      if (_currentState != decision.nextState) {
        _syncState(decision.nextState, decision.reason);
      }

      setState(() {
        _currentState = decision.nextState;
        _currentAction = decision.action;
        _guidanceText = decision.guidanceText;
      });

      // Phase 8: Emit spoken voice guidance
      voiceGuidance.speak(decision.guidanceText);
    } catch (_) {}
  }

  Future<void> _verifyCandidate(Candidate candidate) async {
    if (_isVerifying || _isDisposed) return;
    if (candidate.cropBase64 == null || candidate.cropBase64!.isEmpty) return;

    _isVerifying = true;
    _candidatesEvaluated++;
    _syncState(SearchState.verifying, 'Centering candidate crop for Gemma forensic reasoning');

    setState(() {
      _currentState = SearchState.verifying;
      _guidanceText = 'Checking candidate with Gemma...';
      _currentAction = GuidanceAction.holdSteady;
    });

    try {
      final cropBytes = base64Decode(candidate.cropBase64!);
      final verifyResponse = await ApiService.verifyCandidate(
        candidateCropBytes: cropBytes,
        targetProfile: widget.targetProfile,
      );

      if (_isDisposed || !mounted) return;

      if (verifyResponse.status == VerificationStatus.found) {
        _samplingTimer?.cancel();
        _syncState(SearchState.found, 'Gemma verified target identity');

        setState(() {
          _currentState = SearchState.found;
          _currentAction = GuidanceAction.objectFound;
          _guidanceText = 'Object found!';
        });

        voiceGuidance.speak('Object found!');

        // Navigate to Found Screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => FoundScreen(
              sessionId: _sessionId,
              targetProfile: widget.targetProfile,
              verificationResult: verifyResponse.result,
              candidateCropBase64: candidate.cropBase64,
            ),
          ),
        );
      } else if (verifyResponse.status == VerificationStatus.likelyMatch ||
          verifyResponse.status == VerificationStatus.possibleMatch) {
        _syncState(SearchState.guiding, 'Candidate match plausible, guiding user closer');
        setState(() {
          _currentState = SearchState.guiding;
          _guidanceText = verifyResponse.result.guidance.isNotEmpty
              ? verifyResponse.result.guidance
              : 'Move closer to verify.';
          _currentAction = GuidanceAction.moveCloser;
        });
      } else {
        // Not a match: reject candidate, record in search memory, and resume sweep
        _syncState(SearchState.searching, 'Candidate rejected by Gemma, resuming sweep');
        ApiService.recordRejection(
          sessionId: _sessionId,
          candidateId: candidate.id,
          reason: verifyResponse.result.reason,
          similarityScore: verifyResponse.result.confidence,
        );

        setState(() {
          _currentState = SearchState.searching;
          _currentCandidate = null;
        });
        await _fetchGuidanceDecision(
          candidate: null,
          state: SearchState.searching,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentState = SearchState.candidateDetected;
          _guidanceText = 'Possible match. Move closer.';
          _currentAction = GuidanceAction.moveCloser;
        });
      }
    } finally {
      _isVerifying = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _accelSubscription?.cancel();
    _samplingTimer?.cancel();
    _cameraController?.dispose();
    if (_currentState != SearchState.found) {
      ApiService.completeSession(
        sessionId: _sessionId,
        reason: 'User stopped search session',
      ).then((_) {}).catchError((_) => null, test: (_) => true);
    }
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

          // 2. Viewfinder Reticle with Directional Cue
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
                        border: Border.all(color: _getStateColor()),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _getStateColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _currentState.code,
                            style: TextStyle(
                              color: _getStateColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (_candidatesEvaluated > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($_candidatesEvaluated)',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Voice Guidance Toggle Button
                    InkWell(
                      onTap: () {
                        voiceGuidance.toggleVoice();
                        setState(() {
                          _voiceEnabled = voiceGuidance.isEnabled;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.background.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _voiceEnabled ? AppTheme.accent : AppTheme.border,
                          ),
                        ),
                        child: Icon(
                          _voiceEnabled ? Icons.volume_up : Icons.volume_off,
                          size: 18,
                          color: _voiceEnabled ? AppTheme.accent : AppTheme.textMuted,
                        ),
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
                          color: _currentState == SearchState.found
                              ? AppTheme.statusFound
                              : (_currentState == SearchState.candidateDetected ||
                                      _currentState == SearchState.verifying ||
                                      _currentState == SearchState.guiding
                                  ? AppTheme.statusCandidate
                                  : AppTheme.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildGuidanceIcon(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _guidanceText,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isVerifying
                                      ? 'Forensic reasoning in progress with Gemma...'
                                      : (_currentState == SearchState.candidateDetected
                                          ? 'Candidate locked. Centering target...'
                                          : 'Scan surroundings smoothly.'),
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildGuidanceIcon() {
    IconData icon;
    Color color = AppTheme.accent;

    switch (_currentAction) {
      case GuidanceAction.panLeft:
        icon = Icons.arrow_back;
        break;
      case GuidanceAction.panRight:
        icon = Icons.arrow_forward;
        break;
      case GuidanceAction.tiltUp:
        icon = Icons.arrow_upward;
        break;
      case GuidanceAction.tiltDown:
        icon = Icons.arrow_downward;
        break;
      case GuidanceAction.moveCloser:
        icon = Icons.zoom_in;
        break;
      case GuidanceAction.holdSteady:
        icon = Icons.crop_free;
        color = AppTheme.statusCandidate;
        break;
      case GuidanceAction.objectFound:
        icon = Icons.check_circle;
        color = AppTheme.statusFound;
        break;
      case GuidanceAction.continueScanning:
        icon = Icons.search;
        color = AppTheme.statusSearching;
        break;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Color _getStateColor() {
    switch (_currentState) {
      case SearchState.found:
        return AppTheme.statusFound;
      case SearchState.verifying:
      case SearchState.candidateDetected:
      case SearchState.guiding:
        return AppTheme.statusCandidate;
      case SearchState.searching:
      default:
        return AppTheme.statusSearching;
    }
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
                border: Border.all(
                  color: _isVerifying ? AppTheme.statusCandidate : AppTheme.accent,
                  width: 2.0,
                ),
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
                        color: _isVerifying ? AppTheme.statusCandidate : AppTheme.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        _isVerifying
                            ? 'VERIFYING...'
                            : 'CANDIDATE ${(candidate.confidence * 100).toInt()}%',
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
