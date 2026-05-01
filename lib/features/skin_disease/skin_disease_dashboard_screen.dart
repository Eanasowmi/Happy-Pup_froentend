import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/app_routes.dart';
import '../../widgets/animated_background.dart';

class SkinDiseaseDashboardScreen extends StatefulWidget {
  const SkinDiseaseDashboardScreen({super.key});

  @override
  State<SkinDiseaseDashboardScreen> createState() => _SkinDiseaseDashboardScreenState();
}

class _SkinDiseaseDashboardScreenState extends State<SkinDiseaseDashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          "Skin Health Dashboard",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600, 
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF7E7DFF).withOpacity(0.8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const AnimatedBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 30),
                    Text(
                      "Common Skin Conditions",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildDiseaseGrid(),
                    const SizedBox(height: 40),
                    _buildActionCard(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7E7DFF).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7E7DFF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.health_and_safety, color: Color(0xFF7E7DFF), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  "Understand Your Dog's Skin",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Skin issues are among the most common reasons for vet visits. Early detection and understanding can help your dog live a more comfortable life.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF7F8C8D),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                title: "Ringworm",
                icon: Icons.loop,
                color: Colors.redAccent,
                description: "Ringworm is a highly contagious fungal skin infection that can be transmitted between dogs and even to humans. It typically appears as circular patches of hair loss, often with a red, crusty, or scaly appearance at the edges. Despite its name, it is not caused by a worm but by a fungus that feeds on keratin in the hair and skin. Early detection is crucial to prevent the infection from spreading into other pets.",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                title: "Hypersensitivity",
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
                description: "Skin hypersensitivity often occurs when a dog's immune system overreacts to environmental allergens like pollen, dust, or certain foods. This condition manifests as intense itching, redness, and frequent licking or chewing of the paws and other affected areas. Chronic hypersensitivity can lead to secondary skin infections if the underlying cause is not identified and properly managed. Treatment usually involves identifying the allergen.",
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                title: "Dermatitis",
                icon: Icons.spa_outlined,
                color: Colors.brown,
                description: "Dermatitis is a general term for skin inflammation that can be caused by various factors, including irritants, parasites, or underlying health issues. Common signs include red, swollen skin, localized heat, and sometimes the presence of small bumps or pustules on the dog's body. It often makes the dog feel extremely uncomfortable and restless due to the persistent itching and burning sensations. Management requires a thorough veterinary exam.",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                title: "Fungal Infections",
                icon: Icons.science_outlined,
                color: Colors.blueGrey,
                description: "Fungal infections in dogs, such as yeast dermatitis, are often opportunistic and thrive in warm, moist areas like ears or skin folds. These infections typically cause a distinct musty odor, greasy skin, and significant redness or thickening of the affected tissue. They often occur as a secondary complication to other issues like allergies or a weakened immune system. Keeping your dog's skin dry and clean is a key preventive measure.",
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                title: "Demodicosis",
                icon: Icons.bug_report_outlined,
                color: Colors.deepOrange,
                description: "Demodicosis, also known as demodectic mange, is caused by microscopic Demodex mites that naturally reside in the hair follicles of most dogs. When a dog's immune system is compromised, these mites can multiply rapidly, leading to hair loss and skin lesions. The condition often starts with small, hairless patches around the eyes but can spread across the entire body in severe cases. it is necessary to control the mite population and heal.",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                title: "Healthy Dogs",
                icon: Icons.check_circle_outline,
                color: Colors.green,
                description: "A healthy dog typically has skin that is supple, clear, and free of any lumps, redness, or unusual discolorations or odors. Their coat should be shiny and thick, without excessive hair loss or the presence of dandruff or parasitic inhabitants like fleas. Healthy dogs do not exhibit signs of constant itching, biting, or scratching that would otherwise indicate a hidden problem. Maintaining a balanced diet is the best way to ensure skin peak condition.",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
      height: 210, // Added fixed height to prevent layout crash and ensure uniformity
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF7F8C8D),
              height: 1.4,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.camera_alt, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          Text(
            "Ready for a Scan?",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Use our AI tech to analyze your dog's skin symptoms instantly.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.skinDiseaseScanner);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                "Start Health Scan",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
