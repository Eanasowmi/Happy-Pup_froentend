import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../app/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/app_state.dart';
import '../../services/app_state.dart';
import '../../widgets/animated_background.dart';
import '../profile/dog_profile_detail_screen.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> with SingleTickerProviderStateMixin {
  String _userName = "User";
  List<Map<String, dynamic>> _dogs = [];
  bool _isLoadingDogs = true;
  Timer? _refreshTimer;
  late AnimationController _appearanceController;

  @override
  void initState() {
    super.initState();
    _appearanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadUser();
    _loadDogs();
    _appearanceController.forward();

    // Set up a periodic timer to refresh dogs (useful for background AI updates)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) _loadDogs(silent: true);
    });
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final name = await AuthService.getUserName();
    if (name != null && mounted) {
      setState(() => _userName = name);
    }
  }

  Future<void> _loadDogs({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingDogs = true);
    }
    
    final userId = await AuthService.getUserId();
    if (userId != null) {
      List<Map<String, dynamic>> dogs = await DatabaseService().getDogsByUser(userId);
      
      // RESTORE FROM BACKEND IF LOCAL IS EMPTY
      if (dogs.isEmpty) {
        debugPrint("MainDashboardScreen: Local dogs empty, trying backend restoration...");
        try {
          final backendDogs = await AuthService.fetchDogs(userId);
          if (backendDogs.isNotEmpty) {
            debugPrint("MainDashboardScreen: Found ${backendDogs.length} dogs on backend. Restoring...");
            for (var dog in backendDogs) {
              final dogToInsert = Map<String, dynamic>.from(dog);
              dogToInsert.remove('id'); // Local SQLite handles ID
              dogToInsert['user_id'] = userId;
              await DatabaseService().insertDog(dogToInsert);
            }
            // Reload after restoration
            dogs = await DatabaseService().getDogsByUser(userId);
          }
        } catch (e) {
          debugPrint("MainDashboardScreen: Restore error: $e");
        }
      }

      if (mounted) {
        setState(() {
          _dogs = dogs;
          _isLoadingDogs = false;
        });
        
        // Auto-select first dog if none is selected
        if (AppState().selectedDogId == null && dogs.isNotEmpty) {
          AppState().setSelectedDogId(dogs[0]['id']);
        }
      }
    } else {
      if (mounted) setState(() => _isLoadingDogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2FF),
      body: SafeArea(
        child: Stack(
          children: [
            const AnimatedBackground(),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: FadeTransition(
                      opacity: _appearanceController,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _appearanceController,
                          curve: Curves.easeOut,
                        )),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildWelcomeSection(),
                            const SizedBox(height: 30),
                            _buildDogsSection(),
                            const SizedBox(height: 30),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.white),
                              ),
                              child: Center(
                                child: Text(
                                  "Tap a dog profile above to run AI detections and track growth!",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: const Color(0xFF7F8C8D),
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
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addEditDog),
        backgroundColor: const Color(0xFF7E7DFF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "My Dogs",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2C3E50),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.dogList),
              child: const Text("See All"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _isLoadingDogs
            ? const Center(child: CircularProgressIndicator())
            : _dogs.isEmpty
                ? _buildEmptyDogsPlaceholder()
                : _buildDogsList(),
      ],
    );
  }

  Widget _buildEmptyDogsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.pets, size: 40, color: Color(0xFFBDC3C7)),
          const SizedBox(height: 10),
          Text(
            "No dog profiles yet.",
            style: GoogleFonts.poppins(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            "Tap + to create one!",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildDogsList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _dogs.length,
        itemBuilder: (context, index) {
          final dog = _dogs[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DogProfileDetailScreen(dog: dog),
                ),
              ).then((_) {
                if (mounted) {
                  _loadDogs(silent: true);
                }
              });
            },
            child: Container(
              width: 200,
            margin: const EdgeInsets.only(right: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFFF3F2FF),
                  backgroundImage: dog['image_path'] != null 
                    ? FileImage(File(dog['image_path']))
                    : null,
                  child: dog['image_path'] == null 
                    ? const Icon(Icons.pets, color: Color(0xFF7E7DFF))
                    : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dog['name'] ?? "Unknown",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dog['breed'] ?? "Checking...",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF7E7DFF),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        dog['age_range'] ?? "Pending...",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      color: const Color(0xFF7E7DFF),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.pets, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                "Understanding Domestic Dogs",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Colors.white),
            onPressed: () async {
              await AuthService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      children: [
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _appearanceController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _appearanceController,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            )),
            child: Text(
              "Welcome, $_userName!",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        FadeTransition(
          opacity: CurvedAnimation(
            parent: _appearanceController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _appearanceController,
              curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
            )),
            child: const Text(
              "Choose an option below to get started.",
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF7E7DFF),
      unselectedItemColor: const Color(0xFFBDC3C7),
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) {
          Navigator.pushNamed(context, AppRoutes.profile);
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      ],
    );
  }
}
