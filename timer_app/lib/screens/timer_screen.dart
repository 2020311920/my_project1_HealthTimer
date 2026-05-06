import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/workout_timer_provider.dart';
import '../services/foreground_task_handler.dart';
import '../widgets/control_buttons.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/timer_circle_display.dart';
import '../widgets/total_time_display.dart';
import '../widgets/workout_status_info.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  late WorkoutTimerProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<WorkoutTimerProvider>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _initForegroundTask();

    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSettingsDialog();
    });
  }

  Future<void> _showSettingsDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return SettingsDialog(
          initialMaxSets: _provider.maxSets,
          initialRestSeconds: _provider.targetRestSeconds,
          initialBeepEnabled: _provider.isBeepEnabled,
        );
      },
    );

    if (result != null) {
      _provider.saveSettings(
        result['maxSets'] as int,
        result['restSeconds'] as int,
        result['isBeepEnabled'] as bool,
      );
    }
  }

  Future<void> _requestPermissions() async {
    final NotificationPermission status = await FlutterForegroundTask.checkNotificationPermission();
    if (status != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
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
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _provider.setAppState(state);
    if (state == AppLifecycleState.paused) {
      if (_provider.isRunning || _provider.milliseconds > 0) {
        _startForegroundServiceForCurrentState();
      }
    } else if (state == AppLifecycleState.resumed) {
      FlutterForegroundTask.stopService();
    }
  }

  Future<void> _startForegroundServiceForCurrentState() async {
    if (await FlutterForegroundTask.isRunningService == false) {
      await FlutterForegroundTask.startService(
        serviceId: 100,
        serviceTypes: [ForegroundServiceTypes.specialUse],
        notificationTitle: _provider.getNotificationTitle(),
        notificationText: _provider.formatTimeForNotification(_provider.milliseconds),
        callback: startCallback,
        notificationButtons: _provider.getNotificationButtons(),
      );
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is String) {
      if (data == 'pause') {
        _provider.pauseTimer();
      } else if (data == 'resume') {
        _provider.startTimer();
      } else if (data == 'reset') {
        _provider.resetTimer();
      } else if (data == 'restart') {
        _provider.resetAndStartImmediately();
      } else if (data == 'close') {
        FlutterForegroundTask.stopService();
      }
    }
  }

  Widget _buildRoutineSelector(BuildContext context, WorkoutTimerProvider provider) {
    final hasRoutine = provider.routines.isNotEmpty;
    final currentRoutineName = hasRoutine
        ? (provider.selectedRoutineIndex >= 0 && provider.selectedRoutineIndex < provider.routines.length
            ? provider.routines[provider.selectedRoutineIndex]['part']
            : '루틴 선택')
        : '루틴 없음 (설정에서 추가)';

    return OutlinedButton.icon(
      onPressed: provider.isWorkoutStarted || !hasRoutine ? null : () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppConstants.surfaceColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('오늘의 운동 루틴 선택', style: TextStyle(color: AppConstants.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(color: AppConstants.dividerColor, height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: provider.routines.length,
                      itemBuilder: (context, index) {
                        final isSelected = provider.selectedRoutineIndex == index;
                        return ListTile(
                          title: Text(provider.routines[index]['part'], style: TextStyle(color: isSelected ? AppConstants.primaryBlue : AppConstants.primaryText, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text('${(provider.routines[index]['exercises'] as List).length}개 종목', style: const TextStyle(color: AppConstants.secondaryText, fontSize: 12)),
                          trailing: isSelected ? const Icon(Icons.check_circle, color: AppConstants.primaryBlue) : null,
                          onTap: () {
                            provider.selectRoutine(index);
                            Navigator.pop(context);
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
      icon: const Icon(Icons.folder, size: 18),
      label: Text(currentRoutineName),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppConstants.primaryBlue,
        side: const BorderSide(color: AppConstants.primaryBlue, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.person, color: AppConstants.primaryText),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.calendar_month, color: AppConstants.primaryText),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: AppConstants.primaryText),
              onPressed: _showSettingsDialog,
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Consumer<WorkoutTimerProvider>(
          builder: (context, provider, child) {
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 2),
                  const TotalTimeDisplay(),
                  const SizedBox(height: 2),
                  _buildRoutineSelector(context, provider),
                  const Spacer(flex: 1),
                  const WorkoutStatusInfo(),
                  const SizedBox(height: 40),
                  const TimerCircleDisplay(),
                  const Spacer(flex: 40),
                  ControlButtons(
                    isRunning: provider.isRunning,
                    onStartPause: provider.isRunning ? provider.pauseTimer : provider.startTimer,
                    onReset: provider.resetTimer,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50, // 버튼 높이 고정 또는 SizedBox.shrink() 처리
                    child: provider.isWorkoutStarted
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.accentRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 8,
                            ),
                            icon: const Icon(Icons.stop_circle_outlined, size: 24),
                            label: const Text('운동 종료 및 기록 저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final shouldEnd = await showDialog<bool>(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    backgroundColor: AppConstants.dialogBackground,
                                    title: const Text('운동 종료', style: TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
                                    content: const Text('운동을 종료하고 기록을 저장하시겠습니까?', style: TextStyle(color: AppConstants.secondaryText)),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('취소', style: TextStyle(color: AppConstants.secondaryText)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('종료 및 저장', style: TextStyle(color: AppConstants.primaryBlue, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (shouldEnd == true) {
                                await provider.endWorkout();
                                provider.resetTimer();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('운동 기록이 저장되었습니다!')));
                                }
                              }
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 50), // 하단 여백 추가
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}