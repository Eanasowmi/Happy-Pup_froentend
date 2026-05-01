import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import '../../widgets/fusion_result_list.dart';
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/app_state.dart';
import 'package:intl/intl.dart';
import '../../utils/api_config.dart';

/// --- PARTICLE SYSTEM ---
class Particle {
  double x, y, size, velocity, opacity;
  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.velocity,
    required this.opacity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var particle in particles) {
      // Update Y based on velocity and animation
      double currentY = particle.y - (animationValue * 500 * particle.velocity);
      if (currentY < -20) currentY = size.height + 20;
      
      paint.color = Colors.white.withOpacity(particle.opacity * (1 - (currentY / size.height).clamp(0, 1)));
      
      // Draw small circles (bubbles) or dog paws
      canvas.drawCircle(Offset(particle.x, currentY), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AntiGravityWrapper extends StatefulWidget {
  final Widget child;
  final double? delay;
  const AntiGravityWrapper({super.key, required this.child, this.delay});

  @override
  State<AntiGravityWrapper> createState() => _AntiGravityWrapperState();
}

class _AntiGravityWrapperState extends State<AntiGravityWrapper> {
  // For the "Jump" effect
  double _jumpOffset = 0;

  void _triggerJump() {
    setState(() => _jumpOffset = -20.0);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _jumpOffset = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _triggerJump(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        transform: Matrix4.identity()..translate(0.0, _jumpOffset),
        child: widget.child,
      ),
    );
  }
}

/// --- MAIN SCREEN ---
class AgePredictionScreen extends StatefulWidget {
  const AgePredictionScreen({super.key});

  @override
  State<AgePredictionScreen> createState() => _AgePredictionScreenState();
}

class _AgePredictionScreenState extends State<AgePredictionScreen> with TickerProviderStateMixin {
  final FlutterTts _tts = FlutterTts();
  double? _puppyConfidence;
  double? _adultConfidence;
  double? _seniorConfidence;
  String? _predictedClass;
  Uint8List? _lastUsedImageBytes; // Track bytes for saving

  Future<void> _updateConfidencesFromPrediction(Map<String, dynamic> decoded) async {
    if (decoded["fusion_result"] != null) {
      final fusion = decoded["fusion_result"];
      final probs = fusion["probabilities"] ?? {};
      setState(() {
        _puppyConfidence = (probs["Young"] ?? 0.0).toDouble();
        _adultConfidence = (probs["Adult"] ?? 0.0).toDouble();
        _seniorConfidence = (probs["Senior"] ?? 0.0).toDouble();
        _predictedClass = fusion["age_group"];
      });

      // PERSIST to SQLite if a dog is selected
      final selectedId = AppState().selectedDogId;
      if (selectedId != null && _predictedClass != null) {
        // 1. Update age_range summary on the dog profile
        final updateData = {'id': selectedId, 'age_range': _predictedClass!};
        await DatabaseService().updateDog(updateData);
        debugPrint("SQLite: Updated age_range for dog ID $selectedId to $_predictedClass");
        
        // Sync update to backend
        await AuthService.syncUpdateDog(selectedId, updateData);
        
        // 2. Save to local growth history for this specific dog
        await DatabaseService().saveDogRecord({
          'dog_id': selectedId.toString(),
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'predicted_agerange': _predictedClass!,
          'health_status': 'Unknown',
          'size_score': (fusion["confidence"] ?? 0).toDouble() * 100.0,
          'weight': 0.0,
          'image_path': '',
          'image_data': _lastUsedImageBytes != null ? base64Encode(_lastUsedImageBytes!) : '',
        });
        debugPrint("SQLite: Saved growth history for dog ID $selectedId");
      }

      // Also save record to backend (best-effort)
      final userId = await AuthService.getUserId();
      if (userId != null) {
        try {
          await ApiService.savePredictionRecord({
            'user_id': userId,
            'dog_id': AppState().selectedDogId?.toString() ?? 'default_dog',
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'predicted_agerange': _predictedClass ?? 'Unknown',
            'health_status': 'Unknown',
            'size_score': (fusion["confidence"] ?? 0).toDouble() * 100.0,
            'weight': 0.0,
            'image_data': _lastUsedImageBytes != null ? base64Encode(_lastUsedImageBytes!) : '',
          });
        } catch (e) {
          debugPrint("Failed to save record to backend: $e");
        }
      }
    }
  }

  Future<void> _pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // Required for Web and ensures bytes on Mobile
    );
    
    if (result != null) {
      final file = result.files.single;
      Uint8List? bytes = file.bytes;
      
      // Fallback for mobile if withData didn't populate bytes for some reason
      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes != null) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
          _lastUsedImageBytes = bytes;
        });
      }
    }
  }

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    
    if (result != null) {
      final file = result.files.single;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null && !kIsWeb) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes != null) {
        setState(() {
          _selectedAudioBytes = bytes;
          _selectedAudioName = file.name;
        });
      }
    }
  }

  String? _predictionResult;
  bool _loading = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  Uint8List? _selectedAudioBytes;
  String? _selectedAudioName;
  late AnimationController _particleController;
  final List<Particle> _particles = [];
  bool _isTipsExpanded = false;
  int _selectedIndex = 2; // Stats active
  
  String get _baseUrl {
    return ApiConfig.getBaseUrl();
  }

  // Camera variables
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _showCamera = true; 
  String? _cameraError; // New: Track permission errors

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Initialize random particles
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(Particle(
        x: random.nextDouble() * 400,
        y: random.nextDouble() * 800,
        size: random.nextDouble() * 4 + 2,
        velocity: random.nextDouble() * 0.5 + 0.2,
        opacity: random.nextDouble() * 0.3 + 0.1,
      ));
    }
    _setupCameras();
  }

  Future<void> _setupCameras() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high, // Upgraded from medium for better input quality
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _cameraError = null;
          });
        }
      } else {
        setState(() => _cameraError = "No cameras found.");
      }
    } catch (e) {
      debugPrint("Camera error: $e");
      if (mounted) {
        setState(() {
          if (e is CameraException) {
            switch (e.code) {
              case 'CameraAccessDenied':
                _cameraError = "Camera access denied. Please enable it in browser settings.";
                break;
              case 'CameraAccessDeniedWithoutPrompt':
                _cameraError = "Permission previously denied. Please enable manually in settings.";
                break;
              case 'CameraAccessRestricted':
                _cameraError = "Camera access restricted by system.";
                break;
              default:
                _cameraError = "Error initializing camera: ${e.code}";
                break;
            }
          } else {
            _cameraError = "Unexpected camera error occurred.";
          }
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
    try {
      final XFile file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();
      
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
        _lastUsedImageBytes = bytes;
        _showCamera = false;
      });
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  void _resetPredictionUI() {
    if (mounted) {
      setState(() {
        _puppyConfidence = null;
        _adultConfidence = null;
        _seniorConfidence = null;
        _predictedClass = null;
      });
    }
  }


  @override
  void dispose() {
    _particleController.dispose();
    _cameraController?.dispose();
    _tts.stop();
    super.dispose();
  }

  String _formatPrediction(dynamic decoded) {
    if (decoded == null) return 'No prediction result.';
    StringBuffer buf = StringBuffer();
    if (decoded["image_prediction"] != null) {
      buf.writeln("Image Prediction:");
      buf.writeln("  Age Group: ${decoded["image_prediction"]["age_group"]}");
      buf.writeln("  Confidence: ${(decoded["image_prediction"]["confidence"] * 100).toStringAsFixed(1)}%");
      buf.writeln("");
    }
    if (decoded["audio_prediction"] != null) {
      buf.writeln("Audio Prediction:");
      buf.writeln("  Age Group: ${decoded["audio_prediction"]["age_group"]}");
      buf.writeln("  Confidence: ${(decoded["audio_prediction"]["confidence"] * 100).toStringAsFixed(1)}%");
      buf.writeln("");
    }
    if (decoded["fusion_result"] != null) {
      buf.writeln("Fusion Result:");
      buf.writeln("  Age Group: ${decoded["fusion_result"]["age_group"]}");
      buf.writeln("  Confidence: ${(decoded["fusion_result"]["confidence"] * 100).toStringAsFixed(1)}%");
    }
    return buf.toString();
  }

  Future<void> _sendFusionRequest() async {
    Future<void> _speakConfidence(Map<String, dynamic>? decoded) async {
      if (decoded == null || decoded["fusion_result"] == null) return;
      final fusion = decoded["fusion_result"];
      final probs = fusion["probabilities"] ?? {};
      final puppy = probs["Young"] ?? 0.0;
      final adult = probs["Adult"] ?? 0.0;
      final senior = probs["Senior"] ?? 0.0;
      final ageGroup = fusion["age_group"] ?? "unknown";
      String speech = "Prediction: $ageGroup. Puppy confidence: ${(puppy * 100).toStringAsFixed(1)} percent. Adult confidence: ${(adult * 100).toStringAsFixed(1)} percent. Senior confidence: ${(senior * 100).toStringAsFixed(1)} percent.";
      await _tts.speak(speech);
    }
    if (_selectedImageBytes == null || _selectedAudioBytes == null) return;
    setState(() { _loading = true; _predictionResult = null; });

    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/predict'));
    request.files.add(http.MultipartFile.fromBytes('image', _selectedImageBytes!, filename: _selectedImageName ?? 'image.jpg'));
    request.files.add(http.MultipartFile.fromBytes('audio', _selectedAudioBytes!, filename: _selectedAudioName ?? 'audio.wav'));
    var response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      try {
        final decoded = respStr.isNotEmpty ? jsonDecode(respStr) : null;
        final formatted = _formatPrediction(decoded);
        setState(() { _predictionResult = formatted; });
        if (decoded != null) _updateConfidencesFromPrediction(decoded);
        await _speakConfidence(decoded);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Colors.purpleAccent, Colors.blueAccent, Colors.cyanAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.yellowAccent, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Prediction Result',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      formatted,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellowAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } catch (e) {
        setState(() { _predictionResult = respStr; });
      }
    } else {
      setState(() { _predictionResult = 'Error: ${response.statusCode}'; });
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple[400]!,
                  Colors.blue[300]!,
                  Colors.blue[900]!,
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: ParticlePainter(_particles, _particleController.value),
                size: Size.infinite,
              );
            },
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text(
                    "Age Range Detection",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 24),
                  _buildGlassCard(
                    height: 250,
                    child: _showCamera && _isCameraInitialized && _cameraError == null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              CameraPreview(_cameraController!),
                              // Overlay for Camera UI
                                // Gallery switch in Manual Mode
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: IconButton(
                                    icon: const Icon(Icons.photo_library, color: Colors.white),
                                    onPressed: () {
                                      setState(() => _showCamera = false);
                                    },
                                    tooltip: "Gallery Mode",
                                  ),
                                ),
                                Positioned(
                                  bottom: 16,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Only show capture button in manual mode
                                      GestureDetector(
                                        onTap: _takePicture,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
                                            ],
                                          ),
                                          child: const Icon(Icons.camera_alt, color: Colors.blueAccent, size: 30),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_cameraError != null)
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 40),
                                      const SizedBox(height: 12),
                                      Text(
                                        _cameraError!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: _setupCameras,
                                        child: const Text("Retry Access"),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_selectedImageBytes != null)
                                Expanded(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () => setState(() {
                                            _selectedImageBytes = null;
                                            _selectedImageName = null;
                                            _showCamera = true;
                                          }),
                                          style: IconButton.styleFrom(backgroundColor: Colors.black45),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    const Icon(Icons.photo_library_outlined, color: Colors.white, size: 48),
                                    const SizedBox(height: 10),
                                    const Text("Gallery Mode", style: TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton(
                                          onPressed: _pickImage,
                                          child: const Text("Pick Image"),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton(
                                          onPressed: () => setState(() => _showCamera = true),
                                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
                                          child: const Text("Camera", style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    height: 120,
                    child: InkWell(
                      onTap: _pickAudio,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PulseIcon(icon: Icons.mic, color: Colors.blue[200]!, size: 48),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _selectedAudioName != null ? "Selected: $_selectedAudioName" : "Upload Bark (Optional)",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.blue[100]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  
                  // Results shown in both modes
                  if (_puppyConfidence != null || _adultConfidence != null || _seniorConfidence != null)
                    FusionResultList(
                      predictedClass: _predictedClass,
                      puppyConfidence: _puppyConfidence,
                      adultConfidence: _adultConfidence,
                      seniorConfidence: _seniorConfidence,
                    ),

                  _buildExpandableTips(),
                  const SizedBox(height: 40),
                  AntiGravityWrapper(
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: (_selectedImageBytes != null && !_loading)
                            ? _sendFusionRequest
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Text("Predict Now", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        label: const Icon(Icons.auto_awesome),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  const SizedBox(height: 40),
                  if (_predictionResult != null && _predictionResult!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [Colors.purpleAccent.withOpacity(0.18), Colors.blueAccent.withOpacity(0.18)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _predictionResult!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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

  Widget _buildGlassCard({required double height, required Widget child}) {
    return AntiGravityWrapper(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableTips() {
    return _buildGlassCard(
      height: _isTipsExpanded ? 240 : 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Tips for Best Results", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              trailing: Icon(
                _isTipsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white60,
              ),
              onTap: () => setState(() => _isTipsExpanded = !_isTipsExpanded),
            ),
            if (_isTipsExpanded) ...[
              const Divider(color: Colors.white12),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _TipItem("Use clear images with good lighting"),
                    _TipItem("Ensure the dog is facing the camera"),
                    _TipItem("Record bark in a quiet environment"),
                    _TipItem("Include full muzzle in frame"),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final String text;
  const _TipItem(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.star, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.white70))),
        ],
      ),
    );
  }
}

class _PulseIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _PulseIcon({required this.icon, required this.color, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color);
  }
}
