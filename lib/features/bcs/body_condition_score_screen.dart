import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../services/api_service.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/growth_history_service.dart';
import '../../services/app_state.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'widgets/bcs_comparison_widget.dart';
import '../../widgets/optimized_particle_background.dart';

class BodyConditionScoreScreen extends StatefulWidget {
  const BodyConditionScoreScreen({Key? key}) : super(key: key);

  @override
  State<BodyConditionScoreScreen> createState() => _BodyConditionScoreScreenState();
}

class _BodyConditionScoreScreenState extends State<BodyConditionScoreScreen> with TickerProviderStateMixin {
  Uint8List? _webImageBytes;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _imageFile = null;
        });
      } else {
        setState(() {
          _imageFile = File(picked.path);
          _webImageBytes = null;
        });
      }
    }
  }

  Widget _buildImagePreview() {
    if (kIsWeb && _webImageBytes != null) {
      return Image.memory(_webImageBytes!, fit: BoxFit.contain);
    } else if (!kIsWeb && _imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.contain);
    } else {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 48,
                  color: Color.lerp(
                    const Color(0xFFFF8EBD),
                    Colors.white,
                    _pulseController.value,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Upload Photo",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF8EBD),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _onResultsPressed() async {
    if (_imageFile == null && _webImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a photo first.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.uploadImage(
        _imageFile,
        webImageBytes: _webImageBytes,
        webImageName: 'upload.png',
      );

      // Save to local SQLite immediately (dog-isolated)
      final selectedId = AppState().selectedDogId;
      Map<String, dynamic>? lastRecord;

      if (selectedId != null) {
        // Fetch the PREVIOUS record for this dog BEFORE saving the new one
        lastRecord = await DatabaseService().getLastRecord(selectedId.toString());

        // Now save the new record to local SQLite for this specific dog
        String base64Image = '';
        if (kIsWeb && _webImageBytes != null) {
          base64Image = base64Encode(_webImageBytes!);
        } else if (!kIsWeb && _imageFile != null) {
          base64Image = base64Encode(await _imageFile!.readAsBytes());
        }

        await DatabaseService().saveDogRecord({
          'dog_id': selectedId.toString(),
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'predicted_agerange': 'Adult',
          'health_status': result['condition'] ?? 'Unknown',
          'size_score': (result['confidence'] ?? 0).toDouble(),
          'weight': 0.0,
          'image_path': '',
          'image_data': base64Image,
        });
        
        final comparisonStatus = (lastRecord == null) 
            ? "None (New)" 
            : (lastRecord['health_status'] == 'Unknown' ? "Unknown (Age Record)" : lastRecord['health_status']);
        debugPrint("SQLite: Saved BCS record for dog ID $selectedId. Comparing with: $comparisonStatus");
      }

      // Prepare new record map for display/comparison
      final newRecord = {
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'health_status': result['condition'] ?? 'Unknown',
        'size_score': (result['confidence'] ?? 0).toDouble(),
        'weight': 0.0,
      };

      // Also try to save to backend (best-effort, won't block the result dialog)
      final userId = await AuthService.getUserId();
      if (userId != null) {
        try {
          await ApiService.savePredictionRecord({
            'user_id': userId,
            'dog_id': selectedId?.toString() ?? 'default_dog',
            'date': newRecord['date'],
            'predicted_agerange': 'Adult',
            'health_status': newRecord['health_status'],
            'size_score': newRecord['size_score'],
            'weight': 0.0,
            'image_data': kIsWeb
                ? (_webImageBytes != null ? base64Encode(_webImageBytes!) : '')
                : (_imageFile != null ? base64Encode(await _imageFile!.readAsBytes()) : ''),
          });
        } catch (e) {
          debugPrint("Backend save failed (non-critical): $e");
        }
      }

      // Compare with the PREVIOUS record of the SAME dog
      final trendMessage = GrowthHistoryService().compareHealth(lastRecord, newRecord);

      _showResultDialog(
        condition: result['condition'],
        confidence: result['confidence'],
        trendMessage: trendMessage,
        recommendations: result['recommendations'],
      );
    } catch (e) {
      _showResultDialog(error: e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showResultDialog({
    String? condition,
    int? confidence,
    String? error,
    String? trendMessage,
    String? recommendations,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        if (error != null) {
          return AlertDialog(
            title: const Text('Error', style: TextStyle(color: Colors.black)),
            content: Text(error, style: const TextStyle(color: Colors.black87)),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        }

        IconData icon;
        Color color;
        String label;
        List<String> details;

        if (condition == 'Underweight') {
          icon = Icons.pets;
          color = Colors.redAccent;
          label = 'Underweight';
          details = [
            'Low body fat',
            'Ribs clearly visible',
            'Needs nutrition improvement',
          ];
        } else if (condition == 'Healthy') {
          icon = Icons.check_circle_rounded;
          color = Colors.green;
          label = 'Healthy';
          details = [
            'Ideal body condition',
            'Balanced weight',
            'No health risk',
          ];
        } else if (condition == 'Overweight') {
          icon = Icons.pets;
          color = Colors.orange;
          label = 'Overweight';
          details = [
            'Excess fat detected',
            'Reduced activity level',
            'Diet adjustment needed',
          ];
        } else {
          icon = Icons.help_outline;
          color = Colors.grey;
          label = condition ?? 'Unknown';
          details = ['No details available.'];
        }

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Icon(icon, color: color, size: 48),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (recommendations != null && recommendations.isNotEmpty)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: SingleChildScrollView(
                        child: _buildRecommendationsView(recommendations, color),
                      ),
                    )
                  else
                    ...details.map((d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 16, color: Color(0xFF22223B)),
                            textAlign: TextAlign.center,
                          ),
                        )),
                  const SizedBox(height: 20),
                  if (confidence != null)
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Confidence: $confidence%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF22223B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: confidence / 100.0,
                            minHeight: 10,
                            backgroundColor: color.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  if (trendMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              trendMessage,
                              style: const TextStyle(color: Colors.blue, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        elevation: 2,
                      ),
                      child: const Text('Close'),
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

  Widget _buildRecommendationsView(String text, Color primaryColor) {
    final lines = text.split('\n');
    List<Widget> widgets = [];
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      bool isBullet = line.trim().startsWith('-') || line.trim().startsWith('*');
      bool isNumbered = RegExp(r'^\d+\.\s').hasMatch(line.trim());
      
      String cleanLine = line.trim();
      if (isBullet) {
        cleanLine = cleanLine.replaceFirst(RegExp(r'^[-*]\s*'), '');
      }
      
      // Parse markdown bold
      List<TextSpan> spans = [];
      final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*|\*(.*?)\*');
      int lastIndex = 0;
      
      for (final match in boldRegex.allMatches(cleanLine)) {
        if (match.start > lastIndex) {
          spans.add(TextSpan(text: cleanLine.substring(lastIndex, match.start)));
        }
        String boldText = match.group(1) ?? match.group(2) ?? '';
        spans.add(TextSpan(
          text: boldText,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ));
        lastIndex = match.end;
      }
      
      if (lastIndex < cleanLine.length) {
        spans.add(TextSpan(text: cleanLine.substring(lastIndex)));
      }

      if (isBullet) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7.0, right: 10.0),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14, color: Color(0xFF4A4A4A), height: 1.5),
                      children: spans,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (isNumbered) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 15, color: primaryColor, height: 1.5, fontWeight: FontWeight.bold),
                children: spans,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, color: Color(0xFF22223B), height: 1.5, fontWeight: FontWeight.w600),
                children: spans,
              ),
            ),
          ),
        );
      }
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8E2DE2),
                  Color(0xFF4A00E0),
                  Color(0xFF00c6ff),
                ],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          // Particle System in background
          const OptimizedParticleBackground(particleCount: 20),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Body Condition\nPrediction",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Glass Container for Upload
                  JumpWidget(
                    onTap: _pickImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          width: double.infinity,
                          height: 240,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Center(child: _buildImagePreview()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_imageFile != null || _webImageBytes != null)
                    JumpWidget(
                      onTap: _onResultsPressed,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 15,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _onResultsPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  "Analyze Condition",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
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
}

// --- Animation Components ---

class JumpWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const JumpWidget({Key? key, required this.child, required this.onTap}) : super(key: key);

  @override
  State<JumpWidget> createState() => _JumpWidgetState();
}

class _JumpWidgetState extends State<JumpWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}



