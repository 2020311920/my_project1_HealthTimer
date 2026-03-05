import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(EmptyTaskHandler());
}

class EmptyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
  @override
  void onNotificationPressed() {}
  @override
  void onNotificationButtonPressed(String id) {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort(); 
  runApp(const AmbientTimerApp());
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

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with SingleTickerProviderStateMixin {
  int _milliseconds = 0;
  Timer? _timer;
  bool _isRunning = false;

  late AnimationController _glowController;
  late Animation<double> _glowOpacity;
  late Animation<double> _glowRadius;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initForegroundTask();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(_glowController);
    _glowRadius = Tween<double>(begin: 20, end: 60).animate(_glowController);
  }

  Future<void> _requestPermissions() async {
    final NotificationPermission status = await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'timer_app_channel',
        channelName: '타이머 알림',
        channelDescription: '타이머가 작동 중일 때 띄워주는 알림입니다.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  String _formatTime(int ms) {
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    int hundredths = (ms % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  // 🌟 핵심 수정 1: 타이머 시작 (유령 타이머 방지)
  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    // 1. 대기(await) 없이 즉시 타이머 객체부터 생성해서 꽉 쥐고 있음
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _milliseconds += 10;
      });

      if (_milliseconds % 1000 == 0) {
        int minutes = (_milliseconds ~/ 60000);
        int seconds = (_milliseconds % 60000) ~/ 1000;
        FlutterForegroundTask.updateService(
          notificationTitle: '내 맘대로 타이머 작동 중',
          notificationText: '${minutes.toString().padLeft(2, '0')}분 ${seconds.toString().padLeft(2, '0')}초 경과',
        );
      }
    });

    // 2. 알림창 서비스는 타이머 흐름을 끊지 않게 비동기 함수로 따로 던져놓음
    _startForegroundService();
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService == false) {
      await FlutterForegroundTask.startService(
        notificationTitle: '내 맘대로 타이머',
        notificationText: '시작됨...',
        callback: startCallback,
      );
    }
  }

  // 🌟 핵심 수정 2: 일시정지 (즉각 취소)
  void _pauseTimer() {
    _timer?.cancel(); // 누르자마자 즉시 타이머 파괴
    setState(() {
      _isRunning = false;
    });
    FlutterForegroundTask.stopService(); // await 제거 (기다리지 않고 끄기 명령만 툭 던짐)
  }

  // 🌟 핵심 수정 3: 초기화 (즉각 취소 및 0초 고정)
  void _resetTimer() {
    _timer?.cancel(); // 즉시 파괴
    setState(() {
      _milliseconds = 0; // 0으로 리셋
      _isRunning = false;
    });
    FlutterForegroundTask.stopService(); // await 제거
  }

  // 🌟 핵심 수정 4: 초기화 후 바로 시작
  void _resetAndStartImmediately() {
    _timer?.cancel();
    
    setState(() {
      _milliseconds = 0;
      _isRunning = true;
    });

    // 여기서도 await 없이 즉시 새 타이머 가동
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _milliseconds += 10;
      });

      if (_milliseconds % 1000 == 0) {
        int minutes = (_milliseconds ~/ 60000);
        int seconds = (_milliseconds % 60000) ~/ 1000;
        FlutterForegroundTask.updateService(
          notificationTitle: '내 맘대로 타이머 작동 중',
          notificationText: '${minutes.toString().padLeft(2, '0')}분 ${seconds.toString().padLeft(2, '0')}초 경과',
        );
      }
    });

    _restartForegroundService();
  }

  Future<void> _restartForegroundService() async {
    await FlutterForegroundTask.stopService();
    await FlutterForegroundTask.startService(
      notificationTitle: '내 맘대로 타이머',
      notificationText: '00분 00초 경과',
      callback: startCallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
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
                              color: Colors.blue.withValues(alpha: _glowOpacity.value),
                              blurRadius: _glowRadius.value,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: Colors.purple.withValues(alpha: _glowOpacity.value * 0.7),
                              blurRadius: _glowRadius.value * 1.5,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: _resetAndStartImmediately,
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
                            _formatTime(_milliseconds),
                            style: const TextStyle(
                              fontSize: 70,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '중앙 터치 시 재시작',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 70),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning ? Colors.redAccent : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onPressed: _isRunning ? _pauseTimer : _startTimer,
                      child: Text(
                        _isRunning ? '일시정지' : '시작',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 120,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onPressed: _resetTimer,
                      child: const Text(
                        '초기화',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}