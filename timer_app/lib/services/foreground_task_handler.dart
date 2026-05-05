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