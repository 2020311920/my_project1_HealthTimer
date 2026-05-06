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
        Color glowColor1 = AppConstants.primaryBlue;
        Color glowColor2 = AppConstants.primaryPurple;

        if (provider.isResting) {
          int remainingMs = provider.targetRestSeconds * 1000 - provider.milliseconds;
          if (remainingMs <= 5000 && remainingMs > 0) {
            double t = (5000 - remainingMs) / 5000.0;
            glowColor1 = Color.lerp(AppConstants.primaryBlue, AppConstants.accentRed, t) ?? AppConstants.primaryBlue;
            glowColor2 = Color.lerp(AppConstants.primaryPurple, AppConstants.accentOrange, t) ?? AppConstants.primaryPurple;
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: [
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
                        color: glowColor1.withValues(alpha: _glowOpacity.value),
                        blurRadius: _glowRadius.value,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: glowColor2.withValues(alpha: _glowOpacity.value * 0.7),
                        blurRadius: _glowRadius.value * 1.5,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                );
              },
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
                    Text(
                      provider.formatTime(provider.milliseconds),
                      style: const TextStyle(
                        fontSize: 70,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryText,
                        letterSpacing: -2,
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