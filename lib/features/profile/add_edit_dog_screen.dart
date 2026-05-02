import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/dog_ai_service.dart';
import '../../app/app_routes.dart';
import 'dog_profile_detail_screen.dart';

class AddEditDogScreen extends StatefulWidget {
  const AddEditDogScreen({super.key});

  @override
  State<AddEditDogScreen> createState() => _AddEditDogScreenState();
}

class _AddEditDogScreenState extends State<AddEditDogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  
  bool _isLoading = false;
  Map<String, dynamic>? _existingDog;
  bool _isEditMode = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _existingDog = args;
      _isEditMode = true;
      _nameController.text = _existingDog!['name'] ?? "";
      _breedController.text = _existingDog!['breed'] ?? "";
      _ageController.text = (_existingDog!['age'] ?? "").toString();
      _weightController.text = (_existingDog!['weight'] ?? "").toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = await AuthService.getUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User session error. Please login again.")),
          );
        }
        return;
      }

      final dogData = Map<String, dynamic>.from(_existingDog ?? {});
      dogData['user_id'] = userId;
      dogData['name'] = _nameController.text;
      dogData['breed'] = _breedController.text.isEmpty ? 'Unknown' : _breedController.text;
      dogData['age'] = int.tryParse(_ageController.text) ?? 0;
      dogData['weight'] = double.tryParse(_weightController.text) ?? 0.0;
      
      if (!_isEditMode) {
        dogData['created_at'] = DateTime.now().toIso8601String();
      }

      int result;
      if (_isEditMode) {
        result = await DatabaseService().updateDog(dogData);
        debugPrint("AddEditDogScreen: Updated dog result=$result");
        // Use specific update sync
        await AuthService.syncUpdateDog(dogData['id'], dogData);
      } else {
        result = await DatabaseService().insertDog(dogData);
        debugPrint("AddEditDogScreen: Inserted dog result=$result");
        if (result != -1) {
          dogData['id'] = result;
          // Sync new dog
          await AuthService.syncDog(dogData);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? "Profile updated successfully!" : "Profile created successfully!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving profile: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProfile() async {
    final dogId = _existingDog?['id'];
    if (dogId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Profile"),
        content: Text("Are you sure you want to delete ${_nameController.text}'s profile?"),
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
      setState(() => _isLoading = true);
      try {
        await DatabaseService().deleteDog(dogId);
        // Sync delete to backend
        await AuthService.syncDeleteDog(dogId);
        
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile deleted successfully")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting profile: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? "Edit Dog Profile" : "Create Dog Profile",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF7E7DFF),
        foregroundColor: Colors.white,
        actions: _isEditMode ? [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _isLoading ? null : _deleteProfile,
          )
        ] : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                _isEditMode ? "Update Details" : "Tell us about your dog",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              _buildTextField(_nameController, "Dog Name", Icons.pets),
              const SizedBox(height: 20),
              _buildTextField(_breedController, "Breed (e.g. Golden Retriever)", Icons.category_outlined, isRequired: false),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _ageController, 
                      "Age (Years)", 
                      Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      isRequired: false,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildTextField(
                      _weightController, 
                      "Weight (kg)", 
                      Icons.monitor_weight_outlined,
                      keyboardType: TextInputType.number,
                      isRequired: false,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E7DFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isEditMode ? "Update Profile" : "Create Profile",
                      style: GoogleFonts.poppins(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white
                      ),
                    ),
              ),
              
              if (_isEditMode) ...[
                const SizedBox(height: 15),
                TextButton(
                  onPressed: _isLoading ? null : _deleteProfile,
                  child: Text(
                    "Remove Profile", 
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {TextInputType keyboardType = TextInputType.text,
     bool isRequired = true}
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF7E7DFF)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF7E7DFF), width: 2),
        ),
      ),
      validator: isRequired ? (value) {
        if (value == null || value.trim().isEmpty) {
          return "Required";
        }
        return null;
      } : null,
    );
  }
}
