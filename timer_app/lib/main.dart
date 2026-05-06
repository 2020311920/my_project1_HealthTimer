import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'screens/timer_screen.dart';
import 'providers/workout_timer_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort(); 
  runApp(
    ChangeNotifierProvider(
      create: (_) => WorkoutTimerProvider(),
      child: const AmbientTimerApp(),
    ),
  );
}

class AmbientTimerApp extends StatelessWidget {
  const AmbientTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF00050A),
      ),
      home: const TimerScreen(),
    );
  }
}