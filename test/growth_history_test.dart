import 'package:flutter_test/flutter_test.dart';
import 'package:dog_tracker/services/growth_history_service.dart';

void main() {
  group('GrowthHistoryService Tests', () {
    final service = GrowthHistoryService();

    test('should return first record message when oldRecord is null', () {
      final newRecord = {'health_status': 'Healthy', 'weight': 10.0, 'size_score': 50.0};
      final result = service.compareHealth(null, newRecord);
      expect(result, "First body condition record. Keep tracking!");
    });

    test('should return first record message when oldRecord has Unknown status', () {
      final oldRecord = {'health_status': 'Unknown', 'weight': 0.0, 'size_score': 0.0};
      final newRecord = {'health_status': 'Healthy', 'weight': 10.0, 'size_score': 50.0};
      final result = service.compareHealth(oldRecord, newRecord);
      expect(result, "First body condition record. Keep tracking!");
    });

    test('should detect health improvement (Underweight to Healthy)', () {
      final oldRecord = {'health_status': 'Underweight', 'weight': 10.0, 'size_score': 50.0};
      final newRecord = {'health_status': 'Healthy', 'weight': 10.5, 'size_score': 51.0};
      final result = service.compareHealth(oldRecord, newRecord);
      expect(result, contains("Improved (Back to Healthy)"));
      expect(result, contains("Detected growth"));
    });

    test('should detect health worsening (Healthy to Overweight)', () {
      final oldRecord = {'health_status': 'Healthy', 'weight': 10.0, 'size_score': 50.0};
      final newRecord = {'health_status': 'Overweight', 'weight': 12.0, 'size_score': 50.0};
      final result = service.compareHealth(oldRecord, newRecord);
      expect(result, contains("Worsened (Deviation from Healthy)"));
      expect(result, contains("Detected growth"));
    });

    test('should detect no change in health but growth in weight', () {
      final oldRecord = {'health_status': 'Healthy', 'weight': 10.0, 'size_score': 50.0};
      final newRecord = {'health_status': 'Healthy', 'weight': 11.0, 'size_score': 50.0};
      final result = service.compareHealth(oldRecord, newRecord);
      expect(result, contains("Steady (No change)"));
      expect(result, contains("Detected growth"));
    });
  });
}
