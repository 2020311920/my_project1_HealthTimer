import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_timer_provider.dart';
import '../constants.dart';

class TimerCircleDisplay extends StatefulWidget {
  const TimerCircleDisplay({super.key});

  @override
  State<TimerCircleDisplay> createState() => _TimerCircleDisplayState();
}

class _TimerCircleDisplayState extends State<TimerCircleDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowOpacity;
  late Animation<double> _glowRadius;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(_glowController);
    _glowRadius = Tween<double>(begin: 20, end: 60).animate(_glowController);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutTimerProvider>(
      builder: (context, provider, child) {
        int theme = provider.timerTheme;

        Color glowColor1 = AppConstants.primaryBlue;
        Color glowColor2 = AppConstants.primaryPurple;
        
        double progress = 1.0;

        if (provider.isResting) {
          int remainingMs = provider.targetRestSeconds * 1000 - provider.milliseconds;
          progress = (remainingMs / (provider.targetRestSeconds * 1000)).clamp(0.0, 1.0);
          
          if (remainingMs <= 5000 && remainingMs > 0) {
            double t = (5000 - remainingMs) / 5000.0;
            glowColor1 = Color.lerp(AppConstants.primaryBlue, AppConstants.accentRed, t) ?? AppConstants.primaryBlue;
            glowColor2 = Color.lerp(AppConstants.primaryPurple, AppConstants.accentOrange, t) ?? AppConstants.primaryPurple;
          }
        }

        // Cyberpunk colors
        if (theme == 3) {
          glowColor1 = Colors.cyanAccent;
          glowColor2 = Colors.pinkAccent;
          if (provider.isResting) {
            int remainingMs = provider.targetRestSeconds * 1000 - provider.milliseconds;
            if (remainingMs <= 5000 && remainingMs > 0) {
               glowColor1 = Colors.redAccent;
               glowColor2 = Colors.yellowAccent;
            }
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            if (theme == 0 || theme == 1 || theme == 3)
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor1.withValues(alpha: theme == 3 ? _glowOpacity.value * 1.5 : _glowOpacity.value),
                          blurRadius: theme == 3 ? _glowRadius.value * 1.2 : _glowRadius.value,
                          spreadRadius: theme == 3 ? 15 : 10,
                        ),
                        BoxShadow(
                          color: glowColor2.withValues(alpha: theme == 3 ? _glowOpacity.value : _glowOpacity.value * 0.7),
                          blurRadius: theme == 3 ? _glowRadius.value * 2.0 : _glowRadius.value * 1.5,
                          spreadRadius: theme == 3 ? 25 : 20,
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (theme == 1 || theme == 3)
              CustomPaint(
                size: const Size(280, 280),
                painter: TimerPainter(
                  progress: progress,
                  glowColor1: glowColor1,
                  glowColor2: glowColor2,
                  isResting: provider.isResting,
                  isCyberpunk: theme == 3,
                ),
              ),
            if (theme == 2)
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppConstants.secondaryText.withValues(alpha: 0.3), width: 2),
                ),
              ),
            GestureDetector(
              onTap: provider.resetAndStartImmediately,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 280,
                height: 280,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        provider.formatTime(provider.milliseconds),
                        style: TextStyle(
                          fontSize: 70,
                          fontWeight: theme == 2 ? FontWeight.w300 : (theme == 3 ? FontWeight.w900 : FontWeight.bold),
                          color: theme == 3 ? Colors.white : AppConstants.primaryText,
                          letterSpacing: theme == 3 ? 2 : -2,
                          shadows: theme == 3 ? [Shadow(color: glowColor1, blurRadius: 10)] : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '중앙 터치 시 휴식/다음 세트',
                      style: TextStyle(
                        color: AppConstants.primaryText.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class TimerPainter extends CustomPainter {
  final double progress;
  final Color glowColor1;
  final Color glowColor2;
  final bool isResting;
  final bool isCyberpunk;

  TimerPainter({
    required this.progress,
    required this.glowColor1,
    required this.glowColor2,
    required this.isResting,
    this.isCyberpunk = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: isCyberpunk ? 0.1 : 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCyberpunk ? 8.0 : 14.0
      ..strokeCap = isCyberpunk ? StrokeCap.square : StrokeCap.round;

    Paint progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [glowColor1, glowColor2, glowColor1],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCyberpunk ? 8.0 : 14.0
      ..strokeCap = isCyberpunk ? StrokeCap.square : StrokeCap.round;

    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = (size.width - (isCyberpunk ? 8 : 14)) / 2;

    // Draw background track
    canvas.drawCircle(center, radius, backgroundPaint);

    double startAngle = -math.pi / 2;
    double sweepAngle = 2 * math.pi * progress;

    if (isResting) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, progressPaint);
    } else {
      // Draw full circle for active workout
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, 2 * math.pi, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TimerPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.glowColor1 != glowColor1 ||
           oldDelegate.glowColor2 != glowColor2 ||
           oldDelegate.isResting != isResting ||
           oldDelegate.isCyberpunk != isCyberpunk;
  }
}