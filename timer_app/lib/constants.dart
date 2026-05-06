import 'package:flutter/material.dart';

class AppConstants {
  // SharedPreferences Keys
  static const String keyMaxSets = 'maxSets';
  static const String keyRestSeconds = 'restSeconds';
  static const String keyIsBeepEnabled = 'isBeepEnabled';
  
  static String keyWorkoutRecords(String dateStr) => 'workout_records_$dateStr';

  // Colors
  static const Color scaffoldBackground = Color(0xFF000000); // Deep Black
  static const Color backgroundColor = Color(0xFF0A0A0A);
  static const Color dialogBackground = Color(0xFF151515); // Dark Gray
  static const Color surfaceColor = Color(0xFF1C1C1E);
  
  static const Color primaryBlue = Color(0xFF00E5FF); // Neon Aqua
  static const Color primaryPurple = Color(0xFFB388FF); // Neon Purple
  static const Color accentRed = Color(0xFFFF1744); // Neon Coral Red
  static const Color accentOrange = Color(0xFFFF9100); // Neon Orange
  static const Color neonGreen = Color(0xFF00E676); // Neon Green for Success
  
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFFA0A0A0);
  static const Color dividerColor = Color(0xFF2A2A2A);

  // Defaults
  static const int defaultMaxSets = 4;
  static const int defaultRestSeconds = 90;
  static const bool defaultBeepEnabled = true;
}