import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../services/growth_history_service.dart';

class BcsComparisonWidget extends StatelessWidget {
  final Map<String, dynamic>? previousRecord;
  final Map<String, dynamic> currentRecord;

  const BcsComparisonWidget({
    Key? key,
    required this.previousRecord,
    required this.currentRecord,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildImageComparison(),
        const SizedBox(height: 24),
        _buildTrendGraph(),
      ],
    );
  }

  Widget _buildImageComparison() {
    return Row(
      children: [
        Expanded(child: _buildImageCard("Previous", previousRecord)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
        ),
        Expanded(child: _buildImageCard("Current", currentRecord)),
      ],
    );
  }

  Widget _buildImageCard(String title, Map<String, dynamic>? record) {
    if (record == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Text("No Data")),
      );
    }

    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _buildImage(record['image_data'] ?? record['image_path']),
        ),
        const SizedBox(height: 8),
        Text(
          record['health_status'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildImage(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        height: 100,
        width: double.infinity,
        color: Colors.grey[300],
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
          height: 100,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      } catch (e) {
        return _buildPlaceholder();
      }
    }

    if (kIsWeb) {
      return _buildPlaceholder();
    }

    return Image.file(
      File(path),
      height: 100,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 100,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }

  Color _getStatusColor(double value) {
    switch (value.toInt()) {
      case 1:
        return Colors.amber; // Underweight - Yellowish
      case 2:
        return Colors.green; // Healthy - Green
      case 3:
        return Colors.red; // Overweight - Red
      default:
        return const Color(0xFF6366F1);
    }
  }

  Widget _buildTrendGraph() {
    final service = GrowthHistoryService();
    final List<FlSpot> spots = [];

    if (previousRecord != null) {
      spots.add(FlSpot(0, service.getHealthStatusValue(previousRecord!['health_status']).toDouble()));
    }
    spots.add(FlSpot(1, service.getHealthStatusValue(currentRecord['health_status']).toDouble()));

    final Color currColor = _getStatusColor(spots.last.y);
    final Color prevColor = spots.length > 1 ? _getStatusColor(spots.first.y) : currColor;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Growth Comparison Graph",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            value == 0 ? "Prev" : "Curr",
                            style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value == 1) return const Text("Poor", style: TextStyle(fontSize: 10));
                        if (value == 2) return const Text("Ideal", style: TextStyle(fontSize: 10));
                        if (value == 3) return const Text("Over", style: TextStyle(fontSize: 10));
                        return const Text("");
                      },
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 1,
                minY: 0,
                maxY: 4,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [prevColor, currColor],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: _getStatusColor(spot.y),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          currColor.withOpacity(0.2),
                          currColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
