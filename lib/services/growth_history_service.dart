class GrowthHistoryService {
  static final GrowthHistoryService _instance = GrowthHistoryService._internal();
  factory GrowthHistoryService() => _instance;
  GrowthHistoryService._internal();

  String compareHealth(Map<String, dynamic>? oldRecord, Map<String, dynamic> newRecord) {
    if (oldRecord == null || oldRecord['health_status'] == 'Unknown') {
      return "First body condition record. Keep tracking!";
    }

    String oldStatus = oldRecord['health_status'] ?? 'Unknown';
    String newStatus = newRecord['health_status'] ?? 'Unknown';

    String healthTrend = _getHealthTrend(oldStatus, newStatus);
    String growthTrend = _getGrowthTrend(oldRecord, newRecord);

    return "Health: $healthTrend. $growthTrend";
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  String _getHealthTrend(String oldStatus, String newStatus) {
    if (oldStatus == newStatus) return "Steady (No change)";

    // Improved scenarios
    if ((oldStatus == 'Underweight' && newStatus == 'Healthy') ||
        (oldStatus == 'Overweight' && newStatus == 'Healthy')) {
      return "Improved (Back to Healthy)";
    }

    // Worsened scenarios
    if ((oldStatus == 'Healthy' && (newStatus == 'Underweight' || newStatus == 'Overweight')) ||
        (oldStatus == 'Underweight' && newStatus == 'Overweight') ||
        (oldStatus == 'Overweight' && newStatus == 'Underweight')) {
      return "Worsened (Deviation from Healthy)";
    }

    return "Changed";
  }

  String _getGrowthTrend(Map<String, dynamic> oldRecord, Map<String, dynamic> newRecord) {
    double oldWeight = _toDouble(oldRecord['weight']);
    double newWeight = _toDouble(newRecord['weight']);
    double oldSize = _toDouble(oldRecord['size_score']);
    double newSize = _toDouble(newRecord['size_score']);

    // Handle no-growth-data case (from Age records or otherwise)
    if (oldWeight == 0.0 && oldSize == 0.0) {
      return "Collecting growth data...";
    }

    if (newWeight > oldWeight || newSize > oldSize) {
      return "Detected growth in size/weight.";
    } else if (newWeight < oldWeight || newSize < oldSize) {
      return "Detected decrease in size/weight.";
    } else {
      return "Size/weight remains stable.";
    }
  }

  int getHealthStatusValue(String? status) {
    switch (status) {
      case 'Underweight':
        return 1;
      case 'Healthy':
        return 2;
      case 'Overweight':
        return 3;
      default:
        return 0;
    }
  }

  String getHealthStatusLabel(int value) {
    switch (value) {
      case 1:
        return 'Underweight';
      case 2:
        return 'Healthy';
      case 3:
        return 'Overweight';
      default:
        return 'Unknown';
    }
  }
}
