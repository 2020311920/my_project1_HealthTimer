import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/workout_timer_provider.dart';

class WorkoutStatusInfo extends StatelessWidget {
  const WorkoutStatusInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutTimerProvider>(
      builder: (context, provider, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: AppConstants.secondaryText),
              onPressed: provider.previousState,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                provider.getStatusText(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConstants.secondaryText),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: AppConstants.secondaryText),
              onPressed: provider.nextState,
            ),
          ],
        );
      },
    );
  }
}