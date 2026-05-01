import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/animated_background.dart';
import '../../services/app_state.dart';
import '../../services/database_service.dart';
import '../../utils/api_config.dart';

// ================= BUBBLE WIDGET =================
class BubbleWidget extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final Color color;
  final double left;
  final double top;

  const BubbleWidget({
    super.key,
    required this.controller,
    required this.size,
    required this.color,
    required this.left,
    required this.top,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animationValue = controller.value;
        return Positioned(
          left: left + (math.sin(animationValue * 2 * math.pi) * 30),
          top: top - (animationValue * 200),
          child: Transform.scale(
            scale: 0.8 + (math.sin(animationValue * 2 * math.pi) * 0.2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1 + (math.sin(animationValue * 2 * math.pi) * 0.05)),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class DogSkinDiseasePredictorPage extends StatefulWidget {
  const DogSkinDiseasePredictorPage({super.key});

  @override
  _DogSkinDiseasePredictorPageState createState() =>
      _DogSkinDiseasePredictorPageState();
}

class _DogSkinDiseasePredictorPageState
    extends State<DogSkinDiseasePredictorPage> with TickerProviderStateMixin {

  File? _selectedImage;
  Uint8List? _webImage;
  String? _fileName;

  String _predictedDisease = "";
  String _confidence = "";
  String _description = "";
  String _whenToSeeVet = "";

  List<dynamic> _symptoms = [];
  List<dynamic> _causes = [];
  List<dynamic> _treatment = [];

  bool _isLoading = false;
  String _errorText = "";

  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late List<AnimationController> _bubbleControllers;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _buttonPulseAnimation;

  // Camera support
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _showCamera = false;
  String? _cameraError;

  @override
  void initState() {
    super.initState();
    
    // Main fade and slide animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Button pulse animation
    _buttonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Bubble animations
    _bubbleControllers = List.generate(8, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 3000 + (index * 500)),
      );
    });
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );
    
    _buttonPulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _buttonAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward();
    _buttonAnimationController.repeat(reverse: true);
    
    // Start bubble animations
    for (var controller in _bubbleControllers) {
      controller.repeat();
    }
    
    if (kIsWeb) {
      _setupCameras();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    for (var controller in _bubbleControllers) {
      controller.dispose();
    }
    _cameraController?.dispose();
    super.dispose();
  }

  // ================= CAMERA SETUP =================
  Future<void> _setupCameras() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras.first,
          ResolutionPreset.high,
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
            _cameraError = "Camera access error: ${e.description}";
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
        _webImage = bytes;
        _fileName = file.name;
        _errorText = "";
        _predictedDisease = "";
        _showCamera = false;
      });
    } catch (e) {
      debugPrint("Error taking picture: $e");
    }
  }

  // ================= IMAGE PICKER =================
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _fileName = pickedFile.name;
          _errorText = "";
          _predictedDisease = "";
        });
      } else {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorText = "";
          _predictedDisease = "";
        });
      }
    }
  }

  // ================= API =================
  Future<void> _makePredictionRequest() async {
    setState(() {
      _isLoading = true;
      _errorText = "";
    });

    try {
      var uri = Uri.parse('${ApiConfig.getBaseUrl()}/predict/skin');

      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        if (_webImage != null) {
          request.files.add(http.MultipartFile.fromBytes(
            'image',
            _webImage!,
            filename: _fileName ?? 'upload.jpg',
          ));
        } else {
          throw Exception("No image selected");
        }
      } else {
        if (_selectedImage != null) {
          request.files.add(await http.MultipartFile.fromPath(
              'image', _selectedImage!.path));
        } else {
          throw Exception("No image selected");
        }
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseData);

        if (data['status'] == 'success') {
          List<dynamic> ensureList(dynamic val) {
            if (val == null) return [];
            if (val is List) return val;
            return [val.toString()];
          }
          
          final String predictedDiseaseStr = data['predicted_disease'] ?? "Unknown";

          setState(() {
            _predictedDisease = predictedDiseaseStr;
            _confidence = "${data['confidence'] ?? 0}%";
            _description = data['description'] ?? "";
            _symptoms = ensureList(data['symptoms']);
            _causes = ensureList(data['causes']);
            _treatment = ensureList(data['treatment']);
            _whenToSeeVet = data['when_to_see_vet'] ?? "";
          });
          
          // Persist the skin disease to the currently selected dog
          final selectedId = AppState().selectedDogId;
          if (selectedId != null) {
            await DatabaseService().updateDog({
              'id': selectedId,
              'last_skin_disease': predictedDiseaseStr,
            });
            debugPrint("SQLite: Updated skin disease for dog ID $selectedId to $predictedDiseaseStr");
          }

          _showResultModal();
        } else {
          setState(() => _errorText = data['message'] ?? "Prediction failed");
        }
      } else {
        setState(() => _errorText = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorText = "Connection error. Ensure server is running.");
      debugPrint("API Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ================= RESULT MODAL =================
  void _showResultModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F7FF), // Light purple for modal
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "Diagnosis Result",
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D2B55),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    
                    _buildResultCard(),
                    
                    if (_predictedDisease.isNotEmpty) ...[
                      const SizedBox(height: 25),
                      _buildSection(Icons.info_outline, "Details", _description),
                      _buildListSection(Icons.list_alt, "Symptoms", _symptoms),
                      _buildListSection(Icons.science_outlined, "Possible Causes", _causes),
                      _buildListSection(Icons.medical_services_outlined, "Treatment Plan", _treatment),
                      if (_whenToSeeVet.isNotEmpty)
                        _buildWarningBox(),
                    ],

                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E7DFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF7E7DFF).withOpacity(0.3),
                        ),
                        child: Text(
                          "Done",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthySkinMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF4CAF50),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Healthy Skin!",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4CAF50),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Your dog's skin appears to be healthy and normal. No skin diseases were detected in the image.",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF2D2B55),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Continue with regular grooming and monitoring to maintain your dog's skin health.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotDogSkinMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline,
                color: Color(0xFFFF9800),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Not a Dog Skin Image",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF9800),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "This doesn't appear to be a dog skin image. Please upload a clear photo of your dog's skin for accurate analysis.",
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF2D2B55),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "For best results, ensure the image shows the affected skin area clearly with good lighting.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E7DFF).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF7E7DFF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            _predictedDisease,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7E7DFF), // Purple for disease name
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 18),
                const SizedBox(width: 8),
                Text(
                  "Confidence: $_confidence",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      margin: const EdgeInsets.only(top: 25),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF5252).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Important Note",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF5252),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _whenToSeeVet,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2D2B55),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(IconData icon, String title, String content) {
    if (content.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7E7DFF).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7E7DFF), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2B55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(IconData icon, String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7E7DFF).withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF7E7DFF), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D2B55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF7E7DFF),
                )),
                Expanded(
                  child: Text(
                    item.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildImagePreviewContent() {
    if (_showCamera && _isCameraInitialized && _cameraError == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          Positioned(
            bottom: 15,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Color(0xFF7E7DFF)),
              ),
            ),
          ),
        ],
      );
    }

    if (_cameraError != null && _showCamera) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 10),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              TextButton(
                onPressed: _setupCameras,
                child: const Text("Retry Access"),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb) {
      if (_webImage != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_webImage!, fit: BoxFit.cover),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _webImage = null;
                  _showCamera = true;
                }),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
          ],
        );
      }
    } else {
      if (_selectedImage != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(_selectedImage!, fit: BoxFit.cover),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() {
                  _selectedImage = null;
                }),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
          ],
        );
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          child: Icon(
            Icons.image_search_rounded,
            size: 64,
            color: const Color(0xFF7E7DFF).withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Upload Skin Photo",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Dogs Skin Disease Detection Scanner",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF7E7DFF).withOpacity(0.8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Full screen background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8F7FF), // Very light purple
                  Color(0xFFF0EEFF), // Light purple
                  Color(0xFFE8E5FF), // Slightly deeper purple
                ],
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7E7DFF).withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF9B88FF).withOpacity(0.08),
              ),
            ),
          ),
          // Animated bubbles
          ...List.generate(8, (index) {
            final colors = [
              const Color(0xFF7E7DFF),
              const Color(0xFF9B88FF),
              const Color(0xFF6B5B95),
              const Color(0xFF8B7FD6),
            ];
            final sizes = [20.0, 30.0, 40.0, 25.0, 35.0, 45.0, 28.0, 38.0];
            final positions = [
              [50.0, 300.0],
              [150.0, 500.0],
              [250.0, 200.0],
              [100.0, 600.0],
              [300.0, 400.0],
              [200.0, 700.0],
              [80.0, 450.0],
              [320.0, 250.0],
            ];
            
            return BubbleWidget(
              controller: _bubbleControllers[index],
              size: sizes[index],
              color: colors[index % colors.length],
              left: positions[index][0],
              top: positions[index][1],
            );
          }),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.1),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                      )),
                      child: Column(
                        children: [
                          Text(
                            "Dermatology AI",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2D2B55),
                            ),
                          ),
                          const SizedBox(height: 8),
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Text(
                              "Identify common dog skin conditions instantly",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF6B5B95),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 35),
                          
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: _buildImagePickerCard(),
                          ),
                          
                          if (_errorText.isNotEmpty)
                            _buildErrorBanner(),

                          const SizedBox(height: 30),
                          
                          _buildDetectButton(),
                          
                          // Add extra spacing to ensure background covers entire screen
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95), // Light card background
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E7DFF).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF7E7DFF).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () {
                if (_showCamera) {
                  _takePicture();
                } else {
                  _pickImage(ImageSource.gallery);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FF), // Very light purple for image area
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF7E7DFF).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _buildImagePreviewContent(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              Expanded(
                child: _buildSourceButton(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  onPressed: () => _pickImage(ImageSource.gallery),
                  primary: false,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildSourceButton(
                  icon: _showCamera ? Icons.photo_library_rounded : Icons.camera_alt_rounded,
                  label: _showCamera ? "Gallery" : "Scanner",
                  onPressed: () {
                    if (_showCamera) {
                      setState(() => _showCamera = false);
                    } else {
                      if (_isCameraInitialized) {
                        setState(() => _showCamera = true);
                      } else {
                        _setupCameras().then((_) {
                          if (_isCameraInitialized) {
                            setState(() => _showCamera = true);
                          }
                        });
                      }
                    }
                  },
                  primary: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool primary,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? const Color(0xFF7E7DFF) : Colors.white,
          foregroundColor: primary ? Colors.white : const Color(0xFF2D2B55),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: primary ? 4 : 1,
          shadowColor: primary ? const Color(0xFF7E7DFF).withOpacity(0.3) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: primary ? BorderSide.none : BorderSide(
              color: const Color(0xFF7E7DFF).withOpacity(0.4),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectButton() {
    bool canDetect = (_selectedImage != null || _webImage != null) && !_isLoading;
    
    return AnimatedBuilder(
      animation: _buttonPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: canDetect ? _buttonPulseAnimation.value : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: canDetect ? [
                BoxShadow(
                  color: const Color(0xFF7E7DFF).withOpacity(0.4),
                  blurRadius: 25,
                  offset: const Offset(0, 12),
                ),
              ] : [],
            ),
            child: ElevatedButton(
              onPressed: canDetect ? _makePredictionRequest : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7E7DFF), // Light purple for button
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE0E0E0),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF7E7DFF).withOpacity(0.3),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      "Run Health Scan",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF5252).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorText,
              style: GoogleFonts.poppins(
                color: const Color(0xFFFF5252),
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
