import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/voice_input_service.dart';
import '../services/accessibility_service.dart';
import 'confirm_target_screen.dart';

class AddTargetScreen extends StatefulWidget {
  const AddTargetScreen({super.key});

  @override
  State<AddTargetScreen> createState() => _AddTargetScreenState();
}

class _AddTargetScreenState extends State<AddTargetScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descController = TextEditingController();

  XFile? _selectedImage;
  Uint8List? _selectedBytes;
  bool _isAnalyzing = false;
  String? _errorMessage;

  // Voice Typing state
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _announceScreen();
  }

  void _announceScreen() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        a11yService.announce(
          'Target Setup. You can tap the microphone button to voice type what you lost, or take a reference photo.',
        );
      }
    });
  }

  Future<void> _toggleVoiceTyping() async {
    a11yService.triggerHaptic(HapticType.selection);

    if (_isListening) {
      await voiceInputService.stopListening();
      setState(() => _isListening = false);
      a11yService.announce('Voice typing stopped.');
    } else {
      a11yService.announce('Listening. Please speak what you are looking for now.');
      await voiceInputService.startListening(
        onResult: (text) {
          setState(() {
            _descController.text = text;
            _descController.selection = TextSelection.fromPosition(
              TextPosition(offset: _descController.text.length),
            );
          });
        },
        onListeningStateChanged: (listening) {
          if (mounted) {
            setState(() => _isListening = listening);
          }
        },
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    a11yService.triggerHaptic(HapticType.selection);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImage = picked;
          _selectedBytes = bytes;
          _errorMessage = null;
        });
        a11yService.triggerHaptic(HapticType.success);
        a11yService.announce('Photo captured successfully.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to access image: $e';
      });
      a11yService.announce('Failed to access camera or gallery.');
    }
  }

  Future<void> _createTargetProfile() async {
    final textDesc = _descController.text.trim();
    if (_selectedImage == null && _selectedBytes == null && textDesc.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide a photo or speak a description using Voice Typing.';
      });
      a11yService.triggerHaptic(HapticType.alert);
      a11yService.announce('Please provide a photo or speak what you lost.');
      return;
    }

    if (_isListening) {
      await voiceInputService.stopListening();
      setState(() => _isListening = false);
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    a11yService.announce('Analyzing target features with Google Gemma. Please wait.');

    try {
      final response = await ApiService.analyzeTarget(
        imagePath: _selectedImage?.path,
        imageBytes: _selectedBytes,
        description: textDesc,
      );

      if (!mounted) return;

      a11yService.triggerHaptic(HapticType.success);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConfirmTargetScreen(
            targetProfile: response.targetProfile,
            imageBytes: _selectedBytes,
            imagePath: _selectedImage?.path,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        a11yService.triggerHaptic(HapticType.alert);
        a11yService.announce('Target analysis failed. ${_errorMessage ?? ''}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    voiceInputService.stopListening();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHC = a11yService.isHighContrastMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Lost Object'),
        actions: [
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
              // Accessibility voice typing prominent banner
              Semantics(
                label: 'Voice Typing Banner. Speak your item hands-free.',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppTheme.accent.withValues(alpha: 0.18)
                        : (isHC ? const Color(0xFF1E1E1E) : AppTheme.surfaceElevated),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isListening ? AppTheme.accent : (isHC ? Colors.white : AppTheme.border),
                      width: _isListening || isHC ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isListening ? AppTheme.accent : AppTheme.accentMuted,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.black : AppTheme.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isListening ? 'Listening to your voice...' : 'Hands-Free Voice Typing',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _isListening ? AppTheme.accent : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isListening
                                  ? 'Speak item name, color, and features now'
                                  : 'Ideal for visually impaired & quick search',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(88, 38),
                          backgroundColor: _isListening ? AppTheme.statusError : AppTheme.accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _toggleVoiceTyping,
                        child: Text(
                          _isListening ? 'Stop' : 'Speak',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Description and Voice Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Item Description',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: _isListening ? 'Stop recording voice' : 'Start voice typing',
                    child: TextButton.icon(
                      onPressed: _toggleVoiceTyping,
                      icon: Icon(
                        _isListening ? Icons.stop_circle : Icons.mic,
                        size: 18,
                        color: _isListening ? AppTheme.statusError : AppTheme.accent,
                      ),
                      label: Text(
                        _isListening ? 'Stop Mic' : 'Voice Type',
                        style: TextStyle(
                          color: _isListening ? AppTheme.statusError : AppTheme.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Type or speak what you lost (e.g., "Brown matchbox with red label" or "Black mosquito refill bottle").',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),

              // Text Field with accessibility hints
              Semantics(
                label: 'Description input field. Type or use voice typing.',
                textField: true,
                child: TextField(
                  controller: _descController,
                  maxLines: 3,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'e.g. Small rectangular matchbox with brown side striking strip and red front.',
                    suffixIcon: IconButton(
                      tooltip: _isListening ? 'Stop voice typing' : 'Voice type description',
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_outlined,
                        color: _isListening ? AppTheme.statusError : AppTheme.accent,
                        size: 24,
                      ),
                      onPressed: _toggleVoiceTyping,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Reference Photo Section
              const Text(
                'Reference Photo (Optional)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'If you have a photo, attach it. If not, Gemma will use your voice description above.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),

              // Image display or selection container
              if (_selectedBytes != null)
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(
                      color: isHC ? Colors.white : AppTheme.border,
                      width: isHC ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(7.0),
                        child: Center(
                          child: kIsWeb
                              ? Image.memory(
                                  _selectedBytes!,
                                  fit: BoxFit.contain,
                                )
                              : Image.file(
                                  File(_selectedImage!.path),
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Semantics(
                          label: 'Remove selected photo',
                          button: true,
                          child: InkWell(
                            onTap: () {
                              a11yService.triggerHaptic(HapticType.selection);
                              setState(() {
                                _selectedImage = null;
                                _selectedBytes = null;
                              });
                              a11yService.announce('Photo removed.');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isHC ? const Color(0xFF141414) : AppTheme.surface,
                    border: Border.all(
                      color: isHC ? Colors.white : AppTheme.border,
                      width: isHC ? 1.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 38,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Semantics(
                            label: 'Take reference photo with camera',
                            button: true,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(130, 46),
                              ),
                              onPressed: () => _pickImage(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Camera'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Semantics(
                            label: 'Pick reference photo from gallery',
                            button: true,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(130, 46),
                              ),
                              onPressed: () => _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Gallery'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.statusError, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 22, color: AppTheme.statusError),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.statusError,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Action button
              if (_isAnalyzing)
                Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.accent,
                        ),
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Analyzing target features with Gemma...',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Semantics(
                  label: 'Create search target button',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: _createTargetProfile,
                    icon: const Icon(Icons.check, size: 20),
                    label: const Text('Create Search Target'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
