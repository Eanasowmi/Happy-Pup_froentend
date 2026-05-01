import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../app/app_routes.dart';
import '../../services/app_state.dart';
import '../../services/database_service.dart';
import '../home/dog_breed_scanner_screen.dart';

class DogProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> dog;

  const DogProfileDetailScreen({super.key, required this.dog});

  @override
  State<DogProfileDetailScreen> createState() => _DogProfileDetailScreenState();
}

class _DogProfileDetailScreenState extends State<DogProfileDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _appearanceController;
  Map<String, dynamic> _currentDog = {};

  @override
  void initState() {
    super.initState();
    _currentDog = widget.dog;
    // Set the selected dog context globally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppState().setSelectedDogId(widget.dog['id']);
      _refreshDogData();
    });

    _appearanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _appearanceController.forward();
  }

  Future<void> _refreshDogData() async {
    final dogs = await DatabaseService().getDogsByUser(widget.dog['user_id']);
    final updatedDog = dogs.firstWhere(
      (d) => d['id'] == widget.dog['id'], 
      orElse: () => widget.dog,
    );
    if (mounted) {
      setState(() {
        _currentDog = updatedDog;
      });
    }
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FF),
      appBar: AppBar(
        title: Text(
          _currentDog['name'] ?? 'Dog Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF7E7DFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDogData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _appearanceController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDogHeader(),
                const SizedBox(height: 30),
                Text(
                  "Latest Health Data",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 12),
                _buildHealthDataSection(),
                const SizedBox(height: 30),
                Text(
                  "Quick Actions",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 12),
                _buildOptionsGrid(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthDataSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                title: "Breed",
                value: _currentDog['breed'] ?? 'Unknown',
                icon: Icons.pets,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildHealthCard(
                title: "Age Range",
                value: _currentDog['age_range'] ?? 'Unknown',
                icon: Icons.cake,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildHealthCard(
                title: "Skin Disease",
                value: _currentDog['last_skin_disease'] ?? 'Not Analyzed',
                icon: Icons.search,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildHealthCard(
                title: "Emotion",
                value: _currentDog['last_emotion'] ?? 'Not Analyzed',
                icon: Icons.mood,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDogHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: const Color(0xFFF3F2FF),
            backgroundImage: _currentDog['image_path'] != null 
                ? FileImage(File(_currentDog['image_path']))
                : null,
            child: _currentDog['image_path'] == null 
                ? const Icon(Icons.pets, size: 50, color: Color(0xFF7E7DFF))
                : null,
          ),
          const SizedBox(height: 15),
          Text(
            _currentDog['name'] ?? 'Unknown Name',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childAspectRatio: 0.85,
      children: [
        _buildDashboardCard(
          index: 0,
          title: "Breed Detection",
          description: "Identify your dog's breed",
          icon: Icons.pets,
          color: const Color(0xFF7E7DFF),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DogBreedScannerScreen()),
            ).then((_) => _refreshDogData()); // Refresh when returning
          },
        ),
        _buildDashboardCard(
          index: 1,
          title: "Growth Monitoring",
          description: "Track growth and Age Range",
          icon: Icons.trending_up,
          color: const Color(0xFF8B8AFF),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.home)
                .then((_) => _refreshDogData()); // Refresh when returning
          },
        ),
        _buildDashboardCard(
          index: 2,
          title: "Emotion",
          description: "Check your dog's Emotion",
          icon: Icons.add_moderator,
          color: const Color(0xFF6B6AFF),
          onTap: () {},
        ),
        _buildDashboardCard(
          index: 3,
          title: "Skin Disease",
          description: "Detect skin issues",
          icon: Icons.search,
          color: const Color(0xFF5D5CFF),
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.skinDisease)
                .then((_) => _refreshDogData()); // Refresh when returning
          },
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required int index,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 150)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: InteractiveCard(
        title: title,
        description: description,
        icon: icon,
        color: color,
        onTap: onTap,
      ),
    );
  }
}

class InteractiveCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const InteractiveCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  late AnimationController _idleController;
  late Animation<double> _floatingAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => setState(() => _scale = 0.95);
  void _onTapUp(TapUpDetails details) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: AnimatedBuilder(
          animation: _idleController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, -_floatingAnimation.value),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.6),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(15),
                                topRight: Radius.circular(15),
                              ),
                            ),
                            child: Center(
                              child: Icon(widget.icon, color: Colors.white, size: 60),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF7F8C8D),
                                ),
                              ),
                              const Align(
                                alignment: Alignment.bottomRight,
                                child: Icon(Icons.chevron_right, color: Color(0xFFBDC3C7)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmerAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: [
                                  (_shimmerAnimation.value - 0.2).clamp(0.0, 1.0),
                                  _shimmerAnimation.value.clamp(0.0, 1.0),
                                  (_shimmerAnimation.value + 0.2).clamp(0.0, 1.0),
                                ],
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
