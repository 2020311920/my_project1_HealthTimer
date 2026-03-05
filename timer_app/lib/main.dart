import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const AmbientTimerApp());
}

class AmbientTimerApp extends StatelessWidget {
  const AmbientTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF00050A), // 아주 어두운 남색 배경
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

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(begin: 0.2, end: 0.6).animate(_glowController);
    _glowRadius = Tween<double>(begin: 20, end: 60).animate(_glowController);
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

  // 기본 기능 1: 시작
  void _startTimer() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _milliseconds += 10;
      });
    });
  }

  // 기본 기능 2: 일시정지
  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  // 기본 기능 3: 초기화
  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _milliseconds = 0;
      _isRunning = false;
    });
  }

  // 특별 기능: 중앙 터치 시 즉시 재시작
  void _resetAndStartImmediately() {
    _timer?.cancel();
    setState(() {
      _milliseconds = 0;
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        _milliseconds += 10;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. 앰비언트 라이트 및 터치 영역 (위쪽)
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
                        color: const Color.fromARGB(0, 202, 193, 193),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(_glowOpacity.value),
                            blurRadius: _glowRadius.value,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: Colors.purple.withOpacity(_glowOpacity.value * 0.7), // 다크 테마에 어울리게 보라색 추가
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
                            fontSize: 70, // 텍스트 크기를 원에 맞게 살짝 조절
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '중앙 터치 시 재시작',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 70), // 원과 버튼 사이의 여백

            // 2. 기본 타이머 조작 버튼들 (아래쪽)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 시작 & 일시정지 버튼 (상태에 따라 색상과 텍스트 변경)
                SizedBox(
                  width: 120,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.redAccent : Colors.green, // 실행 중엔 빨간색, 멈추면 초록색
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25), // 버튼을 둥글게
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
                
                // 초기화 버튼
                SizedBox(
                  width: 120,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800], // 다크 테마에 어울리는 짙은 회색
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
    );
  }
}