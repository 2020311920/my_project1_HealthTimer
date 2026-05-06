import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_timer_provider.dart';
import '../constants.dart';

class TotalTimeDisplay extends StatelessWidget {
  const TotalTimeDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutTimerProvider>(
      builder: (context, provider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('전체 운동 시간', style: TextStyle(color: AppConstants.secondaryText, fontSize: 14)),
            const SizedBox(height: 5),
            Text(
              provider.formatTotalTime(provider.totalMilliseconds),
              style: const TextStyle(color: AppConstants.primaryText, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }
}