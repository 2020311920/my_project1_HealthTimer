import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
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

  //[추가] 세트 및 휴식 관리 변수
  int _currentSet = 1;        // 현재 세트 수
  int _maxSets = 4;           // 목표 최대 세트 수
  int _targetRestSeconds = 90; // 목표 휴식 시간 (기본 90초 = 1분 30초)
  bool _isResting = false;     // 현재 휴식 중인지 여부

  // 🌟 오디오 플레이어 장착!
  final AudioPlayer _audioPlayer = AudioPlayer();

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

  // 🌟 [추가] 톱니바퀴 설정창 띄우기 함수
  void _showSettingsDialog() {
    int tempMaxSets = _maxSets;
    int tempRestSeconds = _targetRestSeconds;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('타이머 설정', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('목표 세트 수:', style: TextStyle(color: Colors.white, fontSize: 16)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                            onPressed: () => setDialogState(() { if (tempMaxSets > 1) tempMaxSets--; }),
                          ),
                          Text('$tempMaxSets', style: const TextStyle(color: Colors.white, fontSize: 18)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                            onPressed: () => setDialogState(() { tempMaxSets++; }),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('휴식 시간(초):', style: TextStyle(color: Colors.white, fontSize: 16)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                            onPressed: () => setDialogState(() { if (tempRestSeconds > 10) tempRestSeconds -= 10; }),
                          ),
                          Text('$tempRestSeconds', style: const TextStyle(color: Colors.white, fontSize: 18)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                            onPressed: () => setDialogState(() { tempRestSeconds += 10; }),
                          ),
                        ],
                      )
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _maxSets = tempMaxSets;
                      _targetRestSeconds = tempRestSeconds;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('저장', style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      },
    );
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

  // 🌟 현재 상태에 맞는 텍스트를 반환하는 전용 함수
  String _getStatusText() {
    if (_isResting) {
      if (_currentSet == 1) return '새로운 1세트를 위한 휴식 중';
      return '$_currentSet세트를 위한 휴식 중';
    } else {
      return '$_currentSet세트 진행 중';
    }
  }

  void _updateNotification() {
    FlutterForegroundTask.updateService(
      notificationTitle: _getNotificationTitle(),
      notificationText: _formatTimeForNotification(_milliseconds),
      notificationButtons: _getNotificationButtons(),
    );
  }

  String _getNotificationTitle() {
    if (!_isRunning && _milliseconds == 0) return '타이머 대기 중 ⏱️';
    if (!_isRunning) return '일시정지 ⏸️';
    return _getStatusText(); // 알림창 제목도 앱 상태와 똑같이 연동!
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

  // 🌟 (핵심) 매 0.01초마다 실행되는 틱(Tick) 함수 (경고음 로직 포함)
  void _onTick(Timer timer) {
    setState(() {
      _milliseconds += 10;
    });

    if (_isResting) {
      int targetMs = _targetRestSeconds * 1000;
      // 🌟 목표 휴식 시간 정각 도달 시!
      if (_milliseconds == targetMs) {
        _audioPlayer.play(AssetSource('beep.mp3')); // 🌟 우리가 넣은 MP3 파일 재생!
        setState(() {
          _isResting = false; // 휴식 종료 -> 세트 진행 모드로 자동 전환 (시간은 계속 흘러감)
        });
        if (_appState != AppLifecycleState.resumed) _updateNotification();
      }
    }

    if (_milliseconds % 1000 == 0 && _appState != AppLifecycleState.resumed) {
      _updateNotification();
    }
  }

  void _startTimer() {
    if (_isRunning) return;
    setState(() { _isRunning = true; });

    if (_appState != AppLifecycleState.resumed) _updateNotification();

    // 새롭게 만든 _onTick 함수를 연결
    _timer = Timer.periodic(const Duration(milliseconds: 10), _onTick);
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() { _isRunning = false; });
    if (_appState != AppLifecycleState.resumed) _updateNotification();
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _milliseconds = 0;
      _isRunning = false;
      _currentSet = 1;      // 🌟 초기화 누르면 완전 처음(1세트)으로 복귀
      _isResting = false;   // 🌟 휴식 상태도 초기화
    });
    
    if (_appState != AppLifecycleState.resumed) _updateNotification();
  }

  void _resetAndStartImmediately() {
    _timer?.cancel();
    
    setState(() {
      _milliseconds = 0;
      _isRunning = true;

      // 🌟 루틴 핵심 로직: 터치 시 세트 증가 및 휴식 돌입
      if (!_isResting) {
        if (_currentSet >= _maxSets) {
          _currentSet = 1; // 최대 세트 도달 시 새로운 1세트로 순환
        } else {
          _currentSet++;
        }
        _isResting = true; // 휴식 모드 ON
      }
      else {
        // 🌟 [추가된 로직] 휴식 중에 터치했다면? -> 휴식을 즉시 종료하고 세트 진행으로 변환!
        _isResting = false; 
      }
    });

    if (_appState != AppLifecycleState.resumed) _updateNotification();

    _timer = Timer.periodic(const Duration(milliseconds: 10), _onTick);
  }

  @override
  Widget build(BuildContext context) {
    // 🌟 기본 네온사인 색상 (파랑/보라)
    Color glowColor1 = Colors.blue;
    Color glowColor2 = Colors.purple;

    // 🌟 휴식 중이고 남은 시간이 5초(5000ms) 이하일 때 색상 서서히 변경
    if (_isResting) {
      int remainingMs = _targetRestSeconds * 1000 - _milliseconds;
      if (remainingMs <= 5000 && remainingMs > 0) {
        // 남은 시간에 따라 0.0 ~ 1.0 사이의 비율(t) 계산 (5초 남았을 때 0.0, 0초일 때 1.0)
        double t = (5000 - remainingMs) / 5000.0;
        
        // Color.lerp 함수가 비율(t)에 맞춰 두 색상을 자연스럽게 섞어줍니다!
        glowColor1 = Color.lerp(Colors.blue, Colors.red, t) ?? Colors.blue;
        glowColor2 = Color.lerp(Colors.purple, Colors.deepOrange, t) ?? Colors.purple;
      }
    }

    return WithForegroundTask(
      child: Scaffold(
        extendBodyBehindAppBar: true, // 🌟 상단 바가 레이아웃을 밀어내지 않게 함
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: _showSettingsDialog,
            ),
            const SizedBox(width: 10),
          ],
        ),
        // 🌟 Column 대신 Stack을 사용하여 위치를 절대값으로 고정!
        body: Stack(
          alignment: Alignment.center,
          children: [
            // 1. 타이머 원형 (화면 100% 정중앙에 고정)
            Align(
              alignment: Alignment.center,
              child: Stack(
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
                              color: glowColor1.withValues(alpha: _glowOpacity.value),
                              blurRadius: _glowRadius.value,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: glowColor2.withValues(alpha: _glowOpacity.value * 0.7),
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
                            '중앙 터치 시 휴식/다음 세트',
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
            ),

            // 2. 상태 텍스트 (정중앙에서 살짝 위쪽으로 띄움)
            Align(
              alignment: const Alignment(0, -0.6),
              child: Text(
                _getStatusText(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ),

            // 3. 하단 컨트롤 버튼들 (정중앙에서 아래쪽으로 띄움)
            Align(
              alignment: const Alignment(0, 0.75),
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
}