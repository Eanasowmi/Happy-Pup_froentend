import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/app_state.dart';
import '../../widgets/optimized_particle_background.dart';

class BMICalculatorScreen extends StatefulWidget {
  const BMICalculatorScreen({super.key});

  @override
  State<BMICalculatorScreen> createState() => _BMICalculatorScreenState();
}

class _BMICalculatorScreenState extends State<BMICalculatorScreen> with TickerProviderStateMixin {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  
  String? _selectedBreed;
  String _selectedAgeGroup = "Adult";
  
  final List<String> _breeds = [
    "Golden Retriever",
    "Labrador",
    "German Shepherd",
    "French Bulldog",
    "Beagle",
    "Poodle",
    "Rottweiler",
    "Bulldog",
    "Great Dane",
    "Husky"
  ];

  final Map<String, Map<String, double>> _breedFactors = {
    "Golden Retriever": {"Junior": 1.1, "Adult": 1.0, "Senior": 0.9},
    "Labrador": {"Junior": 1.15, "Adult": 1.0, "Senior": 0.95},
    "German Shepherd": {"Junior": 1.1, "Adult": 1.0, "Senior": 0.9},
    "French Bulldog": {"Junior": 1.2, "Adult": 1.0, "Senior": 0.85},
    "Beagle": {"Junior": 1.1, "Adult": 1.0, "Senior": 0.9},
    "Poodle": {"Junior": 1.05, "Adult": 1.0, "Senior": 0.95},
    "Rottweiler": {"Junior": 1.2, "Adult": 1.0, "Senior": 0.9},
    "Bulldog": {"Junior": 1.1, "Adult": 1.0, "Senior": 0.8},
    "Great Dane": {"Junior": 1.3, "Adult": 1.0, "Senior": 0.9},
    "Husky": {"Junior": 1.1, "Adult": 1.0, "Senior": 0.95},
  };

  @override
  void initState() {
    super.initState();
    // Check for saved age group
    if (AppState().lastPredictedAgeGroup != null) {
      _selectedAgeGroup = AppState().lastPredictedAgeGroup!;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _calculateBMI() {
    if (_selectedBreed == null || _weightController.text.isEmpty || _heightController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    double weight = double.tryParse(_weightController.text) ?? 0;
    double heightCm = double.tryParse(_heightController.text) ?? 0;
    double heightM = heightCm / 100;

    if (weight <= 0 || heightM <= 0) return;

    double baseBMI = weight / (heightM * heightM);
    double factor = _breedFactors[_selectedBreed!]?[_selectedAgeGroup] ?? 1.0;
    double adjustedBMI = baseBMI * factor;

    String status;
    String recommendation;
    Color statusColor;

    if (adjustedBMI < 70) {
      status = "Underweight";
      recommendation = "Consider increasing food portions or consult a vet.";
      statusColor = Colors.orangeAccent;
    } else if (adjustedBMI <= 90) {
      status = "Normal";
      recommendation = "Great! Maintain current diet and exercise routine.";
      statusColor = Colors.greenAccent;
    } else {
      status = "Overweight";
      recommendation = "Consider reducing portions and increasing exercise.";
      statusColor = Colors.redAccent;
    }

    // Save result to AppState
    AppState().updateBMIResult(status);

    _showResultDialog(status, adjustedBMI, recommendation, statusColor);
  }

  void _showResultDialog(String status, double bmi, String recommendation, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  "BMI Index: ${bmi.toStringAsFixed(1)}",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                Text(
                  recommendation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                if (AppState().hasMismatch())
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Analysis results show a slight difference. Please meet a veterinary doctor for a more accurate clarification.",
                            style: TextStyle(color: Colors.orange[900], fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (AppState().checkAgreement())
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Your dog's condition is confidently verified by both AI analysis and BMI calculation!",
                            style: TextStyle(color: Colors.green[800], fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Done"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFF818CF8), Color(0xFFC7D2FE)],
              ),
            ),
          ),
          
          // Particles
          const OptimizedParticleBackground(particleCount: 20),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text("v1.0", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.assessment_outlined, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 15),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Canine BMI Calculator",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            "Precision weight assessment for dogs",
                            style: TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Breed Selector
                  _buildSectionCard(
                    title: "Breed",
                    icon: Icons.pets_outlined,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text("Select breed...", style: TextStyle(color: Colors.white60)),
                          value: _selectedBreed,
                          dropdownColor: const Color(0xFF6366F1),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          items: _breeds.map((String breed) {
                            return DropdownMenuItem<String>(
                              value: breed,
                              child: Text(breed),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedBreed = val),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Weight and Height
                  Row(
                    children: [
                      Expanded(
                        child: _buildSectionCard(
                          title: "Weight",
                          icon: Icons.fitness_center,
                          child: _buildTextField(_weightController, "0.00", "kg"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSectionCard(
                          title: "Height (Shoulder)",
                          icon: Icons.straighten,
                          child: _buildTextField(_heightController, "0", "cm"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Age Group
                  const Text(
                    "Patient Age Group",
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildAgeToggle("Junior", "< 1 year"),
                      _buildAgeToggle("Adult", "1 - 7 years"),
                      _buildAgeToggle("Senior", "7+ years"),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Calculate Button
                  AntiGravityWrapper(
                    child: GestureDetector(
                      onTap: _calculateBMI,
                      child: Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Calculate BMI Index",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF6366F1)),
                          ],
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

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white24),
                border: InputBorder.none,
              ),
            ),
          ),
          Text(unit, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAgeToggle(String label, String sub) {
    bool isSelected = _selectedAgeGroup == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedAgeGroup = label),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.white38 : Colors.white12),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: isSelected ? Colors.white70 : Colors.white30, fontSize: 10)),
            if (isSelected) ...[
               const SizedBox(height: 8),
               const Icon(Icons.check, color: Colors.white, size: 16),
            ]
          ],
        ),
      ),
    );
  }
}


// Reuse Particle system and AntiGravity components

class AntiGravityWrapper extends StatefulWidget {
  final Widget child;
  const AntiGravityWrapper({super.key, required this.child});

  @override
  State<AntiGravityWrapper> createState() => _AntiGravityWrapperState();
}

class _AntiGravityWrapperState extends State<AntiGravityWrapper> {
  double _jumpOffset = 0;
  void _triggerJump() {
    setState(() => _jumpOffset = -15.0);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _jumpOffset = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _triggerJump(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        transform: Matrix4.identity()..translate(0.0, _jumpOffset),
        child: widget.child,
      ),
    );
  }
}
