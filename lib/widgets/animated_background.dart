import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PremiumBackgroundPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PremiumBackgroundPainter extends CustomPainter {
  final double progress;

  _PremiumBackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);

    // Light periwinkle background base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF3F2FF),
    );

    // Draw floating bubbles
    _drawBubbles(canvas, size, random);
  }

  void _drawBubbles(Canvas canvas, Size size, Random random) {
    final bubbleColors = [
      const Color(0xFF7E7DFF), // Periwinkle (Primary)
      const Color(0xFF8B8AFF), // Lighter Periwinkle
      const Color(0xFF6B6AFF), // Darker Periwinkle
      const Color(0xFFA1A0FF), // Very Light Periwinkle
    ];

    // Reduced bubble count for performance on web
    const int bubbleCount = 12;

    for (int i = 0; i < bubbleCount; i++) {
      final double seed = i.toDouble();
      
      // Vertical movement (floating up)
      final double speed = 0.04 + (random.nextDouble() * 0.08);
      final double initialY = random.nextDouble() * size.height;
      final double y = (initialY - (progress * size.height * speed)) % size.height;
      
      // Horizontal swaying
      final double xOffset = sin(progress * 2 * pi + (seed * 0.7)) * 30;
      final double initialX = random.nextDouble() * size.width;
      final double x = (initialX + xOffset) % size.width;
      
      final double radius = 15 + random.nextDouble() * 45;
      final Color color = bubbleColors[i % bubbleColors.length];
      
      // Bubble with radial gradient for depth - NO BLUR FILTER for performance
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(0.28),
            color.withOpacity(0.08),
            color.withOpacity(0.0),
          ],
          stops: const [0.3, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius));

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Subtle gloss reflection - NO BLUR FILTER
      final glossPaint = Paint()
        ..color = Colors.white.withOpacity(0.15);
      
      canvas.drawCircle(
        Offset(x - radius * 0.35, y - radius * 0.35),
        radius * 0.18,
        glossPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumBackgroundPainter oldDelegate) => 
    oldDelegate.progress != progress;
}
