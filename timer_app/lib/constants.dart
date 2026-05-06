import 'package:flutter/material.dart';

class AppConstants {
  // SharedPreferences Keys
  static const String keyMaxSets = 'maxSets';
  static const String keyRestSeconds = 'restSeconds';
  static const String keyIsBeepEnabled = 'isBeepEnabled';
  
  static String keyWorkoutRecords(String dateStr) => 'workout_records_$dateStr';

  // Colors
  static const Color scaffoldBackground = Color(0xFF00050A);
  static const Color dialogBackground = Color(0xFF1E1E1E);
  
  static const Color primaryBlue = Colors.blue;
  static const Color primaryPurple = Colors.purple;
  static const Color accentRed = Colors.red;
  static const Color accentOrange = Colors.deepOrange;
  static const Color primaryText = Colors.white;
  static const Color secondaryText = Colors.white70;

  // Defaults
  static const int defaultMaxSets = 4;
  static const int defaultRestSeconds = 90;
  static const bool defaultBeepEnabled = true;
}