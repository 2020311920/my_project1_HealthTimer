import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

class TimerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
  @override
  void onNotificationPressed() {}
  //알림창의 버튼이 눌렸을 때 실행되는 함수
  @override
  void onNotificationButtonPressed(String id) {
    // 눌린 버튼의 ID('pause', 'resume', 'reset')를 메인 앱 화면으로 쏴줍니다.
    FlutterForegroundTask.sendDataToMain(id);
  }
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

class _TimerScreenState extends State<TimerScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _milliseconds = 0;
  Timer? _timer;
  bool _isRunning = false;

  //현재 앱이 화면에 있는지 판별하는 변수 추가
  AppLifecycleState _appState = AppLifecycleState.resumed;

  late AnimationController _glowController;
  late Animation<double> _glowOpacity;
  late Animation<double> _glowRadius;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); //감지기 부착
    _requestPermissions();
    _initForegroundTask();

    //알림창에서 보낸 버튼 신호를 듣는 리스너 등록
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(_glowController);
    _glowRadius = Tween<double>(begin: 20, end: 60).animate(_glowController);
  }

  Future<void> _requestPermissions() async {
    // 1. 알림 권한 요청
    final NotificationPermission status = await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // 2.배터리 최적화 예외 요청 팝업 띄우기
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
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
    //리스너 해제 (메모리 누수 방지)
    WidgetsBinding.instance.removeObserver(this);//감지기 해제
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  //5. 핵심: 사용자가 홈으로 나가거나 앱으로 돌아올 때 실행되는 함수!
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appState = state;
    if (state == AppLifecycleState.paused) {
      // 폰의 홈 버튼을 눌러 백그라운드로 나갔을 때 -> 타이머가 0초 이상이면 알림창 띄우기
      if (_isRunning || _milliseconds > 0) {
        _startForegroundServiceForCurrentState();
      }
    } else if (state == AppLifecycleState.resumed) {
      // 다시 우리 앱 화면으로 들어왔을 때 -> 알림창 바로 지워버리기! (렉 해소)
      FlutterForegroundTask.stopService();
    }
  }

  String _formatTime(int ms) {
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    int hundredths = (ms % 1000) ~/ 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  String _formatTimeForNotification(int ms) {
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    return '${minutes.toString().padLeft(2, '0')}분 ${seconds.toString().padLeft(2, '0')}초';
  }

  void _updateNotification() {
    FlutterForegroundTask.updateService(
      notificationTitle: _getNotificationTitle(),
      notificationText: _formatTimeForNotification(_milliseconds),
      notificationButtons: _getNotificationButtons(),
    );
  }

  String _getNotificationTitle() {
    if (_isRunning) return '타이머 작동 중 ⏳';
    if (_milliseconds > 0) return '타이머 일시정지 ⏸️';
    return '타이머 대기 중 ⏱️';
  }

  List<NotificationButton> _getNotificationButtons() {
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

  Future<void> _startForegroundServiceForCurrentState() async {
    if (await FlutterForegroundTask.isRunningService == false) {
      await FlutterForegroundTask.startService(
        serviceId: 100,
        serviceTypes: [ForegroundServiceTypes.specialUse],
        notificationTitle: _getNotificationTitle(),
        notificationText: _formatTimeForNotification(_milliseconds),
        callback: startCallback,
        notificationButtons: _getNotificationButtons(),
      );
    }
  }

  // 알림창에서 온 신호(id)에 따라 함수를 실행
  void _onReceiveTaskData(Object data) {
    if (data is String) {
      if (data == 'pause') {
        _pauseTimer();
      } else if (data == 'resume') {
        _startTimer();
      } else if (data == 'reset') {
        _resetTimer();
      } else if (data == 'restart') {
        _resetAndStartImmediately();
      } else if (data == 'close') {
        FlutterForegroundTask.stopService();
      }
    }
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    // 앱이 백그라운드일 때 버튼을 눌렀다면 즉시 알림창 업데이트
    if (_appState != AppLifecycleState.resumed) {
      _updateNotification();
    }

    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _milliseconds += 10;
      });

      // 🌟 핵심: 폰 화면에 앱이 켜져 있을 땐 알림창 업데이트 안 함 (렉 완벽 제거)
      if (_milliseconds % 1000 == 0 && _appState != AppLifecycleState.resumed) {
        _updateNotification();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    
    if (_appState != AppLifecycleState.resumed) {
      _updateNotification();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _milliseconds = 0;
      _isRunning = false;
    });
    
    // 🌟 핵심: 초기화 시 알림창을 끄지 않고 00분 00초 상태로 업데이트
    if (_appState != AppLifecycleState.resumed) {
      _updateNotification();
    }
  }

  void _resetAndStartImmediately() {
    _timer?.cancel();
    
    setState(() {
      _milliseconds = 0;
      _isRunning = true;
    });

    if (_appState != AppLifecycleState.resumed) {
      _updateNotification();
    }

    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _milliseconds += 10;
      });

      if (_milliseconds % 1000 == 0 && _appState != AppLifecycleState.resumed) {
        _updateNotification();
      }
    });
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