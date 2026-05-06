import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/workout_record.dart';

class WorkoutTimerProvider extends ChangeNotifier {
  int _milliseconds = 0;
  Timer? _timer;
  bool _isRunning = false;
  DateTime? _lastTickTime; 
  int _lastNotificationSeconds = 0;

  int _currentSet = 1;        
  int _maxSets = AppConstants.defaultMaxSets;           
  int _targetRestSeconds = AppConstants.defaultRestSeconds; 
  bool _isResting = false;     
  bool _isBeepEnabled = AppConstants.defaultBeepEnabled;  
  
  int _currentExercise = 1;       
  bool _isWorkoutStarted = false; 
  int _totalMilliseconds = 0;     

  final AudioPlayer _audioPlayer = AudioPlayer();

  AppLifecycleState _appState = AppLifecycleState.resumed;

  // Getters
  int get milliseconds => _milliseconds;
  bool get isRunning => _isRunning;
  int get currentSet => _currentSet;
  int get maxSets => _maxSets;
  int get targetRestSeconds => _targetRestSeconds;
  bool get isResting => _isResting;
  bool get isBeepEnabled => _isBeepEnabled;
  int get currentExercise => _currentExercise;
  bool get isWorkoutStarted => _isWorkoutStarted;
  int get totalMilliseconds => _totalMilliseconds;
  AppLifecycleState get appState => _appState;

  WorkoutTimerProvider() {
    _loadSettings();
  }

  void setAppState(AppLifecycleState state) {
    _appState = state;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _maxSets = prefs.getInt(AppConstants.keyMaxSets) ?? AppConstants.defaultMaxSets;
    _targetRestSeconds = prefs.getInt(AppConstants.keyRestSeconds) ?? AppConstants.defaultRestSeconds;
    _isBeepEnabled = prefs.getBool(AppConstants.keyIsBeepEnabled) ?? AppConstants.defaultBeepEnabled;
    notifyListeners();
  }

  Future<void> saveSettings(int newMaxSets, int newRestSeconds, bool newIsBeepEnabled) async {
    _maxSets = newMaxSets;
    _targetRestSeconds = newRestSeconds;
    _isBeepEnabled = newIsBeepEnabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyMaxSets, _maxSets);
    await prefs.setInt(AppConstants.keyRestSeconds, _targetRestSeconds);
    await prefs.setBool(AppConstants.keyIsBeepEnabled, _isBeepEnabled);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTick(Timer timer) {
    if (_lastTickTime == null) return;
    
    final now = DateTime.now();
    final elapsedMs = now.difference(_lastTickTime!).inMilliseconds;
    _lastTickTime = now;

    _milliseconds += elapsedMs;
    _totalMilliseconds += elapsedMs; 

    if (_isResting) {
      int targetMs = _targetRestSeconds * 1000;
      if (_milliseconds >= targetMs) {
        if (_isBeepEnabled) {
          _audioPlayer.play(AssetSource('beep.mp3'));
        }
        _isResting = false; 
        if (_appState != AppLifecycleState.resumed) _updateNotification();
      }
    }

    int currentSeconds = _milliseconds ~/ 1000;
    if (currentSeconds != _lastNotificationSeconds && _appState != AppLifecycleState.resumed) {
      _lastNotificationSeconds = currentSeconds;
      _updateNotification();
    }
    
    notifyListeners();
  }

  void startTimer() {
    if (_isRunning) return;
    _isRunning = true; 
    _isWorkoutStarted = true;
    _lastTickTime = DateTime.now();

    if (_appState != AppLifecycleState.resumed) _updateNotification();

    _timer = Timer.periodic(const Duration(milliseconds: 10), _onTick);
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _isRunning = false; 
    _lastTickTime = null; 
    if (_appState != AppLifecycleState.resumed) _updateNotification();
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _milliseconds = 0;
    _totalMilliseconds = 0;
    _isRunning = false;
    _isWorkoutStarted = false;
    _currentSet = 1;
    _currentExercise = 1;
    _isResting = false;
    _lastTickTime = null;
    _lastNotificationSeconds = 0;
    
    if (_appState != AppLifecycleState.resumed) _updateNotification();
    notifyListeners();
  }

  void previousState() {
    HapticFeedback.lightImpact();
    if (_isResting) {
      if (_currentSet > 1) {
        _currentSet--;
        _isResting = false;
      } else {
        if (_currentExercise > 1) {
          _currentExercise--; 
          _currentSet = _maxSets; 
          _isResting = false;
        } else {
          _isResting = false; 
        }
      }
    } else {
      _isResting = true;
    }
    if (_appState != AppLifecycleState.resumed) _updateNotification();
    notifyListeners();
  }

  void nextState() {
    HapticFeedback.lightImpact();
    if (!_isResting) {
      if (_currentSet >= _maxSets) {
        _currentExercise++; 
        _currentSet = 1;
      } else {
        _currentSet++;
      }
      _isResting = true;
    } else {
      _isResting = false;
    }
    if (_appState != AppLifecycleState.resumed) _updateNotification();
    notifyListeners();
  }

  void resetAndStartImmediately() {
    if (!_isWorkoutStarted) {
      startTimer();
      return;
    }

    _timer?.cancel();
    
    _milliseconds = 0;
    _isRunning = true;
    _isWorkoutStarted = true; 

    if (!_isResting) {
      if (_currentSet >= _maxSets) {
        _currentExercise++; 
        _currentSet = 1;
      } else {
        _currentSet++;
      }
      _isResting = true; 
    } else {
      _isResting = false; 
    }

    if (_appState != AppLifecycleState.resumed) _updateNotification();
    _lastTickTime = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 10), _onTick);
    notifyListeners();
  }

  Future<void> endWorkout() async {
    if (!_isWorkoutStarted) return;
    
    _timer?.cancel();
    _isRunning = false; 

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0]; 
    final String key = AppConstants.keyWorkoutRecords(today);
    List<String> records = prefs.getStringList(key) ?? [];

    List<ExerciseSet> exercisesList = [];
    for (int i = 1; i < _currentExercise; i++) {
      exercisesList.add(ExerciseSet(exerciseNum: i, completed: _maxSets, target: _maxSets));
    }
    exercisesList.add(ExerciseSet(exerciseNum: _currentExercise, completed: _currentSet, target: _maxSets));

    WorkoutRecord newRecord = WorkoutRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      date: DateTime.now().toIso8601String(),
      totalTimeMs: _totalMilliseconds,
      exercises: exercisesList,
    );

    records.add(jsonEncode(newRecord.toJson()));
    await prefs.setStringList(key, records);

    _milliseconds = 0;
    _totalMilliseconds = 0;
    _currentSet = 1;
    _currentExercise = 1;
    _isResting = false;
    _isWorkoutStarted = false;
    _lastTickTime = null;

    if (_appState != AppLifecycleState.resumed) _updateNotification();
    notifyListeners();
  }

  String formatTime(int ms) {
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    int hundredths = (ms % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  String formatTotalTime(int ms) {
    int hours = (ms ~/ 3600000);
    int minutes = (ms % 3600000) ~/ 60000;
    int seconds = (ms % 60000) ~/ 1000;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String formatTimeForNotification(int ms) {
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    return '${minutes.toString().padLeft(2, '0')}분 ${seconds.toString().padLeft(2, '0')}초';
  }

  String getStatusText() {
    if (_isResting) {
      if (!_isWorkoutStarted) return '운동 준비 중';
      if (_currentSet == 1) return '종목 $_currentExercise - 새로운 1세트 대기 중';
      return '종목 $_currentExercise - $_currentSet세트 휴식 중';
    } else {
      if (!_isWorkoutStarted) return '운동 준비 중';
      return '종목 $_currentExercise - $_currentSet세트 진행 중';
    }
  }

  void _updateNotification() {
    FlutterForegroundTask.updateService(
      notificationTitle: getNotificationTitle(),
      notificationText: formatTimeForNotification(_milliseconds),
      notificationButtons: getNotificationButtons(),
    );
  }

  String getNotificationTitle() {
    if (!_isRunning && _milliseconds == 0) return '타이머 대기 중 ⏱️';
    if (!_isRunning) return '일시정지 ⏸️';
    return getStatusText();
  }

  List<NotificationButton> getNotificationButtons() {
    if (_isRunning || _milliseconds > 0) {
      return [
        NotificationButton(id: _isRunning ? 'pause' : 'resume', text: _isRunning ? '⏸️ 일시정지' : '▶️ 시작'),
        const NotificationButton(id: 'restart', text: '⏮️ 재시작'),
        const NotificationButton(id: 'reset', text: '🔄 초기화'),
      ];
    } else {
      return [
        const NotificationButton(id: 'resume', text: '▶️ 시작'),
        const NotificationButton(id: 'close', text: '❌ 닫기'),
      ];
    }
  }
}