import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../app/app_routes.dart';

class DogListScreen extends StatefulWidget {
  const DogListScreen({super.key});

  @override
  State<DogListScreen> createState() => _DogListScreenState();
}

class _DogListScreenState extends State<DogListScreen> {
  List<Map<String, dynamic>> _dogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDogs();
  }

  Future<void> _loadDogs() async {
    setState(() {
      _isLoading = true;
    });

    final userId = await AuthService.getUserId();
    debugPrint("DogListScreen: Loading dogs for userId=$userId");

    if (userId != null) {
      List<Map<String, dynamic>> dogs = await DatabaseService().getDogsByUser(userId);
      debugPrint("DogListScreen: Found ${dogs.length} dogs locally.");

      // If local list is empty, try fetching from backend
      if (dogs.isEmpty) {
        debugPrint("DogListScreen: Local list empty, fetching from backend...");
        try {
          final backendDogs = await AuthService.fetchDogs(userId);
          if (backendDogs.isNotEmpty) {
            debugPrint("DogListScreen: Found ${backendDogs.length} dogs on backend. Restoring...");
            for (var dog in backendDogs) {
              // Sanitize: remove the backend ID to avoid conflicts and let local SQLite handle it
              final dogToInsert = Map<String, dynamic>.from(dog);
              dogToInsert.remove('id');
              
              // Ensure user_id is correct
              dogToInsert['user_id'] = userId;
              
              await DatabaseService().insertDog(dogToInsert);
            }
            // Reload from local after restore
            dogs = await DatabaseService().getDogsByUser(userId);
            debugPrint("DogListScreen: Reloaded ${dogs.length} dogs after restoration.");
          } else {
            debugPrint("DogListScreen: No dogs found on backend for userId $userId.");
          }
        } catch (e) {
          debugPrint("DogListScreen: Error during backend restoration: $e");
        }
      }

      if (mounted) {
        setState(() {
          _dogs = dogs;
          _isLoading = false;
        });
      }
    } else {
      debugPrint("DogListScreen: userId is null! User session might be lost.");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Dog Profiles",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF7E7DFF),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _dogs.isEmpty
              ? _buildEmptyState()
              : _buildDogList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, AppRoutes.addEditDog);
          // Always refresh after returning, since pushReplacement inside
          // AddEditDog won't return a result here.
          _loadDogs();
        },
        backgroundColor: const Color(0xFF7E7DFF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text("Add Dog", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "No dog profiles yet",
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          Text(
            "Add your first dog to start tracking",
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDog(int dogId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Profile"),
        content: Text("Are you sure you want to delete $name?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService().deleteDog(dogId);
      // Sync delete to backend
      await AuthService.syncDeleteDog(dogId);
      
      _loadDogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile deleted")),
        );
      }
    }
  }

  Widget _buildDogList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dogs.length,
      itemBuilder: (context, index) {
        final dog = _dogs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFF3F2FF),
              backgroundImage: dog['image_path'] != null && dog['image_path'].isNotEmpty
                  ? FileImage(File(dog['image_path']))
                  : null,
              child: dog['image_path'] == null || dog['image_path'].isEmpty
                  ? const Icon(Icons.pets, color: Color(0xFF7E7DFF), size: 30)
                  : null,
            ),
            title: Text(
              dog['name'] ?? "Unknown",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${dog['breed'] ?? 'Unknown'} • ${dog['age'] ?? '0'} years"),
                Text("${dog['weight'] ?? '0'} kg", style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF7E7DFF)),
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context, 
                      AppRoutes.addEditDog, 
                      arguments: dog
                    );
                    if (result == true) _loadDogs();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteDog(dog['id'], dog['name'] ?? "this dog"),
                ),
              ],
            ),
            onTap: () async {
              final result = await Navigator.pushNamed(
                context, 
                AppRoutes.addEditDog, 
                arguments: dog
              );
              if (result == true) {
                _loadDogs();
              }
            },
          ),
        );
      },
    );
  }
}
