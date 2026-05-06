import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../providers/workout_timer_provider.dart';
import '../services/foreground_task_handler.dart';
import '../widgets/control_buttons.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/timer_circle_display.dart';
import '../widgets/total_time_display.dart';
import '../widgets/workout_status_info.dart';

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

  Future<void> _showCalendar() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppConstants.primaryBlue, onPrimary: AppConstants.primaryText,
              surface: AppConstants.dialogBackground, onSurface: AppConstants.primaryText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final String dateKey = selectedDate.toIso8601String().split('T')[0];
      List<String> recordsStr = prefs.getStringList(AppConstants.keyWorkoutRecords(dateKey)) ?? [];

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppConstants.dialogBackground,
            title: Text('${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일 기록', 
                        style: const TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
            content: recordsStr.isEmpty
                ? const Text('이 날의 운동 기록이 없습니다.', style: TextStyle(color: AppConstants.secondaryText))
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: recordsStr.length,
                      itemBuilder: (context, index) {
                        final record = jsonDecode(recordsStr[index]);
                        return ListTile(
                          leading: const Icon(Icons.fitness_center, color: AppConstants.primaryBlue),
                          title: Text('총 운동 시간: ${_provider.formatTotalTime(record['totalTimeMs'])}', style: const TextStyle(color: AppConstants.primaryText)),
                          subtitle: Text(
                            record['exercises'] != null
                                ? (record['exercises'] as List).map((e) => '종목 ${e['exerciseNum']}: ${e['completed']}/${e['target']}세트').join(', ')
                                : '수행 세트: ${record['setsCompleted'] ?? 0} / ${record['targetSets'] ?? 0}',
                            style: const TextStyle(color: AppConstants.secondaryText),
                          ),
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기', style: TextStyle(color: AppConstants.primaryBlue)),
              )
            ],
          );
        },
      );
    }
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
              icon: const Icon(Icons.calendar_month, color: AppConstants.primaryText),
              onPressed: _showCalendar,
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
            return Stack(
              alignment: Alignment.center,
              children: [
                const Align(
                  alignment: Alignment(0, -0.85),
                  child: TotalTimeDisplay(),
                ),

                const Align(
                  alignment: Alignment.center,
                  child: TimerCircleDisplay(),
                ),

                Align(
                  alignment: const Alignment(0, 0.95),
                  child: provider.isWorkoutStarted
                      ? TextButton.icon(
                          icon: const Icon(Icons.stop_circle_outlined, color: AppConstants.accentRed),
                          label: const Text('운동 종료 및 기록 저장', style: TextStyle(color: AppConstants.accentRed, fontSize: 16)),
                          onPressed: () async {
                            await provider.endWorkout();
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: AppConstants.dialogBackground,
                                  title: const Text('수고하셨습니다! 🎉', style: TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
                                  content: const Text(
                                    '기록이 성공적으로 달력에 저장되었습니다.',
                                    style: TextStyle(color: AppConstants.secondaryText, fontSize: 16),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('확인', style: TextStyle(color: AppConstants.primaryBlue)),
                                    )
                                  ],
                                ),
                              );
                            }
                          },
                        )
                      : const SizedBox.shrink(),
                ),

                const Align(
                  alignment: Alignment(0, -0.6),
                  child: WorkoutStatusInfo(),
                ),

                Align(
                  alignment: const Alignment(0, 0.75),
                  child: ControlButtons(
                    isRunning: provider.isRunning,
                    onStartPause: provider.isRunning ? provider.pauseTimer : provider.startTimer,
                    onReset: provider.resetTimer,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}