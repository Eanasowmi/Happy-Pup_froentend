import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  String? _lastPredictedAgeGroup;
  String? _lastBCSResult;
  String? _lastBMIResult;
  String? _lastPredictedBreed;
  int? _selectedDogId;

  String? get lastPredictedAgeGroup => _lastPredictedAgeGroup;
  String? get lastBCSResult => _lastBCSResult;
  String? get lastBMIResult => _lastBMIResult;
  String? get lastPredictedBreed => _lastPredictedBreed;
  int? get selectedDogId => _selectedDogId;

  void updateBreed(String? breed) {
    _lastPredictedBreed = breed;
    notifyListeners();
  }

  void setSelectedDogId(int? id) {
    _selectedDogId = id;
    notifyListeners();
  }

  void updateAgeGroup(String? ageGroup) {
    if (ageGroup == null) return;
    
    // Normalize to Junior/Adult/Senior
    String normalized = ageGroup.toLowerCase();
    if (normalized.contains('young') || normalized.contains('puppy')) {
      _lastPredictedAgeGroup = 'Junior';
    } else if (normalized.contains('adult')) {
      _lastPredictedAgeGroup = 'Adult';
    } else if (normalized.contains('senior')) {
      _lastPredictedAgeGroup = 'Senior';
    } else {
      _lastPredictedAgeGroup = ageGroup;
    }
    
    notifyListeners();
  }

  void updateBCSResult(String? result) {
    // Normalize BCS (Healthy/Normal -> Healthy)
    if (result == 'Healthy' || result == 'Normal') {
      _lastBCSResult = 'Healthy';
    } else {
      _lastBCSResult = result;
    }
    notifyListeners();
  }

  void updateBMIResult(String? result) {
    // Normalize BMI (Normal -> Healthy)
    if (result == 'Normal' || result == 'Healthy') {
      _lastBMIResult = 'Healthy';
    } else {
      _lastBMIResult = result;
    }
    notifyListeners();
  }

  bool checkAgreement() {
    if (_lastBCSResult == null || _lastBMIResult == null) return false;
    return _lastBCSResult == _lastBMIResult;
  }

  bool hasMismatch() {
    if (_lastBCSResult == null || _lastBMIResult == null) return false;
    return _lastBCSResult != _lastBMIResult;
  }
}
