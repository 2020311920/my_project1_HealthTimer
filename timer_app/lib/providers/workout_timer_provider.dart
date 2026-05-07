import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/workout_record.dart';

class WorkoutResult {
  final WorkoutRecord record;
  final List<Map<String, dynamic>> setDetails;
  final String memo;
  WorkoutResult({required this.record, required this.setDetails, required this.memo});
}

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
  List<Map<String, dynamic>> _routines = [{'part': '기본 운동', 'exercises': <String>[]}]; // 기본 운동은 항상 존재
  int _selectedRoutineIndex = 0;  // 현재 선택된 운동 부위 인덱스
  bool _isWorkoutStarted = false; 
  int _totalMilliseconds = 0;     
  bool _hasShownInitialSettings = false; // 앱 초기 실행 시 설정 창 표시 여부
  int _currentSetActiveMs = 0; // 현재 세트의 순수 운동 시간 (밀리초)
  List<Map<String, dynamic>> _setDetails = []; // 각 세트별 초정밀 데이터 기록
  String _workoutMemo = ''; // 실시간 운동 메모

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
  List<Map<String, dynamic>> get routines => _routines;
  int get selectedRoutineIndex => _selectedRoutineIndex;
  bool get isWorkoutStarted => _isWorkoutStarted;
  int get totalMilliseconds => _totalMilliseconds;
  AppLifecycleState get appState => _appState;
  bool get hasShownInitialSettings => _hasShownInitialSettings;
  int get currentSetActiveMs => _currentSetActiveMs;
  List<Map<String, dynamic>> get setDetails => _setDetails;
  String get workoutMemo => _workoutMemo;

  WorkoutTimerProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _loadSettings();
    });
    _loadSettings();
  }

  void setAppState(AppLifecycleState state) {
    _appState = state;
  }

  void markInitialSettingsShown() {
    _hasShownInitialSettings = true;
  }

  void updateMemo(String memo) {
    _workoutMemo = memo;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    
    _maxSets = prefs.getInt('${uid}_${AppConstants.keyMaxSets}') ?? AppConstants.defaultMaxSets;
    _targetRestSeconds = prefs.getInt('${uid}_${AppConstants.keyRestSeconds}') ?? AppConstants.defaultRestSeconds;
    _isBeepEnabled = prefs.getBool('${uid}_${AppConstants.keyIsBeepEnabled}') ?? AppConstants.defaultBeepEnabled;
    _selectedRoutineIndex = prefs.getInt('${uid}_selectedRoutineIndex') ?? 0;
    
    final routinesString = prefs.getString('${uid}_routines');
    if (routinesString != null) {
      final loadedRoutines = List<Map<String, dynamic>>.from(jsonDecode(routinesString));
      if (loadedRoutines.isNotEmpty) {
        _routines = loadedRoutines;
      }
    }

    notifyListeners();

    // Firestore에서 유저 설정을 가져와 덮어씌움 (기기 간 동기화)
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          if (data.containsKey('settings')) {
            final settings = data['settings'];
            _maxSets = settings['maxSets'] ?? _maxSets;
            _targetRestSeconds = settings['restSeconds'] ?? _targetRestSeconds;
            _isBeepEnabled = settings['isBeepEnabled'] ?? _isBeepEnabled;

            await prefs.setInt('${uid}_${AppConstants.keyMaxSets}', _maxSets);
            await prefs.setInt('${uid}_${AppConstants.keyRestSeconds}', _targetRestSeconds);
            await prefs.setBool('${uid}_${AppConstants.keyIsBeepEnabled}', _isBeepEnabled);
          }
          if (data.containsKey('routines')) {
            final loadedRoutines = List<Map<String, dynamic>>.from(data['routines']);
            if (loadedRoutines.isNotEmpty) {
              _routines = loadedRoutines;
            }
            await prefs.setString('${uid}_routines', jsonEncode(_routines));
          } else if (data.containsKey('customExercises')) {
            // 기존 데이터 마이그레이션
            _routines = [{'part': '기본 운동', 'exercises': List<String>.from(data['customExercises'])}];
            await prefs.setString('${uid}_routines', jsonEncode(_routines));
            await FirebaseFirestore.instance.collection('users').doc(uid).set({'routines': _routines}, SetOptions(merge: true));
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Failed to load settings from Firestore: $e');
      }
    }
  }

  Future<void> saveSettings(int newMaxSets, int newRestSeconds, bool newIsBeepEnabled) async {
    _maxSets = newMaxSets;
    _targetRestSeconds = newRestSeconds;
    _isBeepEnabled = newIsBeepEnabled;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('${uid}_${AppConstants.keyMaxSets}', _maxSets);
    await prefs.setInt('${uid}_${AppConstants.keyRestSeconds}', _targetRestSeconds);
    await prefs.setBool('${uid}_${AppConstants.keyIsBeepEnabled}', _isBeepEnabled);

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'settings': {
            'maxSets': _maxSets,
            'restSeconds': _targetRestSeconds,
            'isBeepEnabled': _isBeepEnabled,
          }
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to save settings to Firestore: $e');
      }
    }
  }

  Future<void> saveRoutines(List<Map<String, dynamic>> newRoutines) async {
    _routines = newRoutines;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'guest';
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('${uid}_routines', jsonEncode(_routines));

    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'routines': _routines,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to save routines to Firestore: $e');
      }
    }
  }

  void selectRoutine(int index) async {
    if (index >= 0 && index < _routines.length) {
      _selectedRoutineIndex = index;
      notifyListeners();
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? 'guest';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${uid}_selectedRoutineIndex', _selectedRoutineIndex);
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'settings': {'selectedRoutineIndex': _selectedRoutineIndex}
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Failed to save selected routine: $e');
        }
      }
    }
  }

  Future<void> renameExercise(int routineIndex, int exerciseIndex, String newName) async {
    if (routineIndex >= 0 && routineIndex < _routines.length) {
      List<String> exercises = List<String>.from(_routines[routineIndex]['exercises'] ?? []);
      if (exerciseIndex >= 0 && exerciseIndex < exercises.length) {
        exercises[exerciseIndex] = newName.trim();
        _routines[routineIndex]['exercises'] = exercises;
        notifyListeners();
        await saveRoutines(_routines);
      }
    }
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

    if (!_isResting) {
      _currentSetActiveMs += elapsedMs; // 순수 운동 시간 누적
    }

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
    _currentSetActiveMs = 0;
    _setDetails.clear();
    _workoutMemo = '';
    
    if (_appState != AppLifecycleState.resumed) _updateNotification();
    notifyListeners();
  }

  void previousState() {
    HapticFeedback.lightImpact();
    if (_isResting) {
      if (_setDetails.isNotEmpty) {
        _setDetails.removeLast(); // 쉬는 시간에 이전으로 갈 경우 직전 세트 기록 무조건 파기 방지(중복 방지)
      }
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
      _setDetails.add({
        'exercise': _getExerciseNameForIndex(_currentExercise),
        'set': _currentSet,
        'timeMs': _currentSetActiveMs,
        'weight': null, // 추후 사용자가 입력할 무게
      });
      _currentSetActiveMs = 0; // 초기화
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
      _setDetails.add({
        'exercise': _getExerciseNameForIndex(_currentExercise),
        'set': _currentSet,
        'timeMs': _currentSetActiveMs,
        'weight': null,
      });
      _currentSetActiveMs = 0;
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

  Future<WorkoutResult?> endWorkout({bool includeCurrentSet = false}) async {
    if (!_isWorkoutStarted) return null;
    
    _timer?.cancel();
    _isRunning = false; 

    final user = FirebaseAuth.instance.currentUser;
    final String uid = user?.uid ?? 'guest';

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0]; 
    final String key = '${uid}_${AppConstants.keyWorkoutRecords(today)}';
    List<String> records = prefs.getStringList(key) ?? [];

    List<Map<String, dynamic>> finalSetDetails = List.from(_setDetails);
    String finalMemo = _workoutMemo;

    // 실제 완수한 세트 계산 (쉬는 시간 중이면 방금 넘어온 것이므로 1을 뺌)
    int actualCompletedSets = _currentSet - 1;
    if (!_isResting && includeCurrentSet) {
      actualCompletedSets += 1;
      finalSetDetails.add({
        'exercise': _getExerciseNameForIndex(_currentExercise),
        'set': _currentSet,
        'timeMs': _currentSetActiveMs,
        'weight': null,
      });
    }

    List<ExerciseSet> exercisesList = [];
    for (int i = 1; i < _currentExercise; i++) {
      exercisesList.add(ExerciseSet(exerciseNum: i, exerciseName: _getExerciseNameForIndex(i), completed: _maxSets, target: _maxSets));
    }
    
    // 현재 진행 중이던 종목의 완료 세트가 0보다 크거나 첫 번째 종목일 경우 추가
    if (actualCompletedSets > 0 || _currentExercise == 1) {
      exercisesList.add(ExerciseSet(exerciseNum: _currentExercise, exerciseName: _getExerciseNameForIndex(_currentExercise), completed: actualCompletedSets, target: _maxSets));
    }

    WorkoutRecord newRecord = WorkoutRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      date: DateTime.now().toIso8601String(),
      totalTimeMs: _totalMilliseconds,
      exercises: exercisesList,
    );

    final Map<String, dynamic> recordJson = newRecord.toJson();
    recordJson['routineName'] = _routines.isNotEmpty ? _routines[_selectedRoutineIndex]['part'] : '기본 운동';
    recordJson['setDetails'] = finalSetDetails; 
    recordJson['memo'] = finalMemo;

    records.add(jsonEncode(recordJson));
    await prefs.setStringList(key, records);

    // Save to Firestore if user is logged in
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('workouts')
            .doc(newRecord.id)
            .set(recordJson);
      } catch (e) {
        debugPrint('Failed to save to Firestore: $e');
      }
    }

    _milliseconds = 0;
    _totalMilliseconds = 0;
    _currentSet = 1;
    _currentExercise = 1;
    _isResting = false;
    _isWorkoutStarted = false;
    _lastTickTime = null;
    _currentSetActiveMs = 0;
    _setDetails.clear();
    _workoutMemo = '';

    if (_appState != AppLifecycleState.resumed) _updateNotification();
    notifyListeners();

    return WorkoutResult(record: newRecord, setDetails: finalSetDetails, memo: finalMemo);
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

  String _getExerciseNameForIndex(int idx) {
    if (_routines.isEmpty || _selectedRoutineIndex < 0 || _selectedRoutineIndex >= _routines.length) {
      return '종목 $idx';
    }
    final exercises = List<String>.from(_routines[_selectedRoutineIndex]['exercises'] ?? []);
    if (idx - 1 < exercises.length) {
      return exercises[idx - 1];
    }
    return '종목 $idx';
  }

  String getStatusText() {
    String exName = _getExerciseNameForIndex(_currentExercise);
    if (_isResting) {
      if (!_isWorkoutStarted) return '운동 준비 중';
      if (_currentSet == 1) return '$exName - 새로운 1세트 대기 중';
      return '$exName - $_currentSet세트 휴식 중';
    } else {
      if (!_isWorkoutStarted) return '운동 준비 중';
      return '$exName - $_currentSet세트 진행 중';
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