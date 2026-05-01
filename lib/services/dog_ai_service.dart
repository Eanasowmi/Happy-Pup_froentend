import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';

class DogAiService {
  static final DogAiService _instance = DogAiService._internal();
  factory DogAiService() => _instance;
  DogAiService._internal();

  /// Simulates background AI detection for a dog profile.
  /// Splits into two separate phases: Breed and Age Range.
  Future<void> processDogBackground(int dogId) async {
    final db = DatabaseService();

    // --- PHASE 1: Breed Detection ---
    debugPrint("Background AI: Starting Breed detection for dog ID $dogId...");
    await Future.delayed(const Duration(seconds: 4)); // Delay 1

    try {
      final String detectedBreed = "Siberian Husky"; // Mock Breed 1
      await db.updateDog({
        'id': dogId,
        'breed': detectedBreed,
      });
      debugPrint("Background AI: Breed detected for ID $dogId: $detectedBreed");
    } catch (e) {
      debugPrint("Background AI (Breed) Error: $e");
    }

    // --- PHASE 2: Age Range Detection ---
    // Simulating that Age is a completely separate process (different model/input)
    debugPrint("Background AI: Starting Age Range detection for dog ID $dogId...");
    await Future.delayed(const Duration(seconds: 5)); // Delay 2

    try {
      final String detectedAgeRange = "Puppy"; // Mock Age Range 2
      await db.updateDog({
        'id': dogId,
        'age_range': detectedAgeRange,
      });
      debugPrint("Background AI: Age Range detected for ID $dogId: $detectedAgeRange");
    } catch (e) {
      debugPrint("Background AI (Age) Error: $e");
    }
    
    debugPrint("Background AI: All detections complete for dog ID $dogId.");
  }
}
