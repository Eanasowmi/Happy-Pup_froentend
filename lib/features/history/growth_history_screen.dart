import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/database_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../bcs/widgets/bcs_comparison_widget.dart';
import 'dart:ui' show ImageFilter;
import 'dart:convert';
import '../../services/app_state.dart';

class GrowthHistoryScreen extends StatefulWidget {
  const GrowthHistoryScreen({super.key});

  @override
  State<GrowthHistoryScreen> createState() => _GrowthHistoryScreenState();
}

class _GrowthHistoryScreenState extends State<GrowthHistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final selectedDogId = AppState().selectedDogId;
    if (selectedDogId == null) {
      debugPrint("No dog selected. Cannot load history.");
      setState(() => _isLoading = false);
      return;
    }
    
    debugPrint("Loading SQLite history isolated for dog_id: $selectedDogId...");
    try {
      final String dogIdStr = selectedDogId.toString();
      final records = await _dbService.getAllRecords(dogIdStr);
      debugPrint("Found ${records.length} records in SQLite for this dog.");
      
      setState(() {
        _history = records;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading isolated local history: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          "Growth History",
          style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6366F1)),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final record = _history[index];
                    return _buildHistoryCard(record, index);
                  },
                ),
    );
  }

  Future<void> _deleteRecord(int id, int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Record"),
        content: const Text("Are you sure you want to delete this record?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // Delete from local SQLite only (source of truth is now local)
        await _dbService.deleteRecord(id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Record deleted successfully")),
          );
          _loadHistory();
        }
      } catch (e) {
        debugPrint("Error deleting record: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to delete record")),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No records found yet",
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Run a prediction from this dog's profile to see history here!",
            style: TextStyle(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record, int index) {
    final bool isBcs = (record['health_status'] ?? 'Unknown') != 'Unknown';
    final int? id = record['id'];
    // SQLite records use 'image_path', backend records use 'image_data'
    final String? imagePath = record['image_path'] as String?;
    final String? imageData = record['image_data'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _showComparisonDialog(record, index),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(imageData ?? imagePath),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          record['date'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            _buildTypeTag(isBcs ? "BCS" : "Age"),
                            if (id != null)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteRecord(id, index),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBcs
                          ? "Health: ${record['health_status']}"
                          : "Age: ${record['predicted_agerange']}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Confidence: ${(record['size_score'] ?? 0).toStringAsFixed(1)}%",
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if ((record['weight'] ?? 0) > 0)
                      Text(
                        "Weight: ${record['weight']} kg",
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComparisonDialog(Map<String, dynamic> record, int index) {
    // If it's not a BCS record, we don't have comparison logic for it yet
    if (record['health_status'] == 'Unknown') return;

    // Find previous record (next in the list since it's ordered by ID DESC)
    Map<String, dynamic>? previousRecord;
    for (int i = index + 1; i < _history.length; i++) {
        if (_history[i]['health_status'] != 'Unknown') {
            previousRecord = _history[i];
            break;
        }
    }

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Growth Comparison",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BcsComparisonWidget(
                  previousRecord: previousRecord,
                  currentRecord: record,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        width: 80,
        height: 80,
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      );
    }

    // Robust Base64 detection
    // Image Base64 strings are very long, file paths are not.
    bool isBase64 = path.length > 500;

    if (isBase64) {
      try {
        final bytes = base64Decode(path);
        return Image.memory(
          bytes,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } catch (e) {
        return _buildPlaceholder();
      }
    }

    try {
      if (path.startsWith('http') || kIsWeb) {
        // Fallback for legacy web paths or URLs
        return _buildPlaceholder();
      }
      return Image.file(
        File(path),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } catch (e) {
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }

  Widget _buildTypeTag(String text) {
    final color = text == "BCS" ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
