import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../../services/app_state.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../utils/api_config.dart';

class DogBreedScannerScreen extends StatefulWidget {
  const DogBreedScannerScreen({super.key});

  @override
  State<DogBreedScannerScreen> createState() => _DogBreedScannerScreenState();
}

class _DogBreedScannerScreenState extends State<DogBreedScannerScreen> with SingleTickerProviderStateMixin {
  XFile? _image;
  final picker = ImagePicker();
  
  String _result = "";
  String _confidence = "";
  String? _mixedBreeds;
  String? _gradCamBase64;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<Alignment> _topAlignmentAnimation;
  late Animation<Alignment> _bottomAlignmentAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _topAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topRight, end: Alignment.bottomRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
    ]).animate(_controller);

    _bottomAlignmentAnimation = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topLeft, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<Alignment>(begin: Alignment.topRight, end: Alignment.bottomRight),
        weight: 1,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future getImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        _resetApp();
        setState(() {
          _image = pickedFile;
        });
        _identifyBreed(pickedFile);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _identifyBreed(XFile image) async {
    setState(() {
      _isLoading = true;
    });

    String apiUrl = "${ApiConfig.getBaseUrl()}/predict/breed";

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'file', 
          bytes,
          filename: image.name
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', image.path));
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);

        setState(() {
          _result = jsonResponse['breed'] ?? "Unknown Breed";
          _confidence = jsonResponse['confidence'] != null 
              ? "${(jsonResponse['confidence'] * 100).toStringAsFixed(1)}%" 
              : "N/A";
          _mixedBreeds = jsonResponse['mixed_breeds'];
          _gradCamBase64 = jsonResponse['grad_cam'];
        });

        // Update global AppState with the predicted breed
        AppState().updateBreed(_result);

        // PERSIST to SQLite if a dog is selected
        final selectedId = AppState().selectedDogId;
        if (selectedId != null) {
          final updateData = {
            'id': selectedId,
            'breed': _result,
          };
          await DatabaseService().updateDog(updateData);
          debugPrint("SQLite: Updated breed for dog ID $selectedId to $_result");
          
          // Sync to backend
          await AuthService.syncUpdateDog(selectedId, updateData);
        }
      } else {
        setState(() {
          _result = "Server Error (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Connection Failed";
        _confidence = "Is backend running?";
      });
      debugPrint("Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _resetApp() {
    setState(() {
      _image = null;
      _result = "";
      _confidence = "";
      _mixedBreeds = null;
      _gradCamBase64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Dog Breed Scanner',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_image != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _resetApp,
            )
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _topAlignmentAnimation.value,
                end: _bottomAlignmentAnimation.value,
                colors: const [
                  Color(0xFF6C63FF),
                  Color(0xFF9fa8da),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.45,
                        constraints: const BoxConstraints(minHeight: 300),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 25,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: _image == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 80,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      "Upload a photo to start",
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  color: Colors.black12, 
                                  child: kIsWeb 
                                      ? Image.network(_image!.path, fit: BoxFit.contain) 
                                      : Image.file(File(_image!.path), fit: BoxFit.contain),
                                ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      if (_isLoading)
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text("Analyzing image..."),
                              ],
                            ),
                          ),
                        )
                      else if (_result.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "It looks like a...",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _result,
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              
                              if (_confidence.isNotEmpty && _confidence != "Is backend running?") ...[
                                LinearProgressIndicator(
                                  value: double.tryParse(_confidence.replaceAll('%', '')) != null 
                                      ? double.parse(_confidence.replaceAll('%', '')) / 100 
                                      : 0,
                                  backgroundColor: Colors.grey[200],
                                  color: Theme.of(context).colorScheme.primary,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Confidence: $_confidence",
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],

                              if (_mixedBreeds != null && _mixedBreeds!.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  "Mixed Breed Analysis",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14, 
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _mixedBreeds!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.orange[800],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],

                              if (_gradCamBase64 != null && _gradCamBase64!.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Divider(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  "AI Attention Map",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14, 
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                
                                Container(
                                  height: MediaQuery.of(context).size.height * 0.4, 
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(
                                      base64Decode(_gradCamBase64!),
                                      fit: BoxFit.contain, 
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      const SizedBox(height: 30),

                      Row(
                        children: [
                          Expanded(
                            child: FloatingActionButton.extended(
                              heroTag: "gallery",
                              onPressed: () => getImage(ImageSource.gallery),
                              label: const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
                              icon: const Icon(Icons.photo_library),
                              backgroundColor: Colors.white,
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              elevation: 4,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: FloatingActionButton.extended(
                              heroTag: "camera",
                              onPressed: () => getImage(ImageSource.camera),
                              label: const Text("Camera", style: TextStyle(fontWeight: FontWeight.bold)),
                              icon: const Icon(Icons.camera_alt),
                              backgroundColor: const Color(0xFF2D2B55),
                              foregroundColor: Colors.white,
                              elevation: 4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
