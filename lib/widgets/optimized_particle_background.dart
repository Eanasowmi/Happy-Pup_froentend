import 'dart:math' as math;
import 'package:flutter/material.dart';

class OptimizedParticleBackground extends StatefulWidget {
  final Color baseColor;
  final int particleCount;

  const OptimizedParticleBackground({
    super.key,
    this.baseColor = Colors.white,
    this.particleCount = 15,
  });

  @override
  State<OptimizedParticleBackground> createState() => _OptimizedParticleBackgroundState();
}

class _OptimizedParticleBackgroundState extends State<OptimizedParticleBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    final random = math.Random();
    _particles = List.generate(widget.particleCount, (index) {
      return _ParticleData(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 1.5,
        speed: random.nextDouble() * 0.04 + 0.01,
        opacity: random.nextDouble() * 0.2 + 0.1,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
              baseColor: widget.baseColor,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _ParticleData {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  _ParticleData({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_ParticleData> particles;
  final double progress;
  final Color baseColor;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      // Calculate current vertical position with wrap-around
      double currentY = ((p.y - (progress * p.speed)) % 1.0) * size.height;
      
      // Horizontal swaying based on progress
      double sway = math.sin(progress * 2 * math.pi + (p.x * 10)) * 10;
      double currentX = (p.x * size.width) + sway;

      paint.color = baseColor.withOpacity(p.opacity);
      canvas.drawCircle(Offset(currentX, currentY), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => 
    oldDelegate.progress != progress;
}
