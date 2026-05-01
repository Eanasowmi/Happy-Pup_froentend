import 'package:flutter/material.dart';

class FusionResultList extends StatelessWidget {
  final String? predictedClass;
  final double? puppyConfidence;
  final double? adultConfidence;
  final double? seniorConfidence;

  const FusionResultList({
    Key? key,
    this.predictedClass,
    this.puppyConfidence,
    this.adultConfidence,
    this.seniorConfidence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildClassificationCard("Puppy", predictedClass == "Young", confidence: puppyConfidence),
        const SizedBox(height: 12),
        _buildClassificationCard("Adult", predictedClass == "Adult", confidence: adultConfidence),
        const SizedBox(height: 12),
        _buildClassificationCard("Senior", predictedClass == "Senior", confidence: seniorConfidence),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildClassificationCard(String label, bool isActive, {double? confidence}) {
    String confidenceText = confidence == null ? '0.0%' : "${(confidence * 100).toStringAsFixed(1)}%";
    
    return Stack(
      children: [
        FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: (confidence ?? 0.0).clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            height: 56,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isActive ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? Colors.greenAccent.withOpacity(0.6) : Colors.white10,
              width: isActive ? 2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                      color: isActive ? Colors.white : Colors.white60,
                    ),
                  ),
                  if (isActive)
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Text(
                        'Predicted!',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      confidenceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  if (isActive)
                    const Icon(Icons.check_circle, color: Colors.greenAccent)
                  else
                    const Icon(Icons.circle_outlined, color: Colors.white24),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
