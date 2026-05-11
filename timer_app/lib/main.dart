import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';

import 'constants.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_timer_provider.dart';
import 'screens/login_screen.dart';
import 'screens/timer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Kakao SDK Init
  KakaoSdk.init(
    nativeAppKey: '23b57005abe75c68eea324644ab609db',
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FlutterForegroundTask.initCommunicationPort(); 
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutTimerProvider()),
      ],
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
        scaffoldBackgroundColor: AppConstants.scaffoldBackground,
        textTheme: GoogleFonts.notoSansKrTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: AppConstants.primaryText,
          displayColor: AppConstants.primaryText,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return Scaffold(
            backgroundColor: AppConstants.scaffoldBackground,
            body: Center(
              child: CircularProgressIndicator(color: AppConstants.primaryBlue),
            ),
          );
        }
        
        if (authProvider.user != null) {
          return const TimerScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}