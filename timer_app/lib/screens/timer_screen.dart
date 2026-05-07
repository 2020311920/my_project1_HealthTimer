import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../models/workout_record.dart';
import '../providers/workout_timer_provider.dart';
import '../services/foreground_task_handler.dart';
import '../widgets/control_buttons.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/timer_circle_display.dart';
import '../widgets/total_time_display.dart';
import '../widgets/workout_status_info.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'share_screen.dart';

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
      if (!_provider.hasShownInitialSettings) {
        _provider.markInitialSettingsShown();
        _showSettingsDialog();
      }
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

  void _showMemoDialog() {
    final controller = TextEditingController(text: _provider.workoutMemo);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.dialogBackground,
        title: const Text('실시간 운동 메모', style: TextStyle(color: AppConstants.primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: AppConstants.primaryText),
          decoration: const InputDecoration(hintText: '오늘의 컨디션, 특이사항을 적어보세요.', hintStyle: TextStyle(color: AppConstants.secondaryText)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: AppConstants.secondaryText))),
          TextButton(onPressed: () {
            _provider.updateMemo(controller.text);
            Navigator.pop(ctx);
          }, child: const Text('저장', style: TextStyle(color: AppConstants.primaryBlue, fontWeight: FontWeight.bold))),
        ],
      )
    );
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
          builder: (sheetContext) {
            return Consumer<WorkoutTimerProvider>(
              builder: (ctx, prov, child) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('루틴 선택', style: TextStyle(color: AppConstants.primaryText, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const Divider(color: AppConstants.dividerColor, height: 1),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: prov.routines.length,
                          itemBuilder: (context, index) {
                            final isSelected = prov.selectedRoutineIndex == index;
                            final exercises = prov.routines[index]['exercises'] as List;
                            return ListTile(
                              title: Text(prov.routines[index]['part'], style: TextStyle(color: isSelected ? AppConstants.primaryBlue : AppConstants.primaryText, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              subtitle: Text('${exercises.length}개 종목\n${exercises.join(", ")}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.secondaryText, fontSize: 12)),
                              leading: isSelected ? const Icon(Icons.check_circle, color: AppConstants.primaryBlue) : const Icon(Icons.circle_outlined, color: AppConstants.secondaryText),
                              onTap: () {
                                prov.selectRoutine(index);
                                Navigator.pop(sheetContext);
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

  void _showWorkoutCompleteSheet(BuildContext parentContext, WorkoutRecord record, String routineName, List<Map<String, dynamic>> setDetails, String memo) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: AppConstants.surfaceColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text('오늘의 오운완 달성!', style: GoogleFonts.notoSansKr(fontSize: 26, fontWeight: FontWeight.bold, color: AppConstants.primaryText)),
                const SizedBox(height: 8),
                Text('총 ${_provider.formatTotalTime(record.totalTimeMs)} 동안\n$routineName 루틴을 완수하셨습니다.', 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansKr(fontSize: 16, color: AppConstants.secondaryText, height: 1.4)
                ),
                const SizedBox(height: 32),
                
                // 1. 카메라로 바로 찍기
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.camera_alt),
                  label: Text('카메라로 오운완 사진 찍기', style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                    if (pickedFile != null && parentContext.mounted) {
                      Navigator.pop(sheetContext); // 사진 선택 후 팝업 닫기
                      Navigator.push(parentContext, MaterialPageRoute(
                        builder: (_) => ShareScreen(record: record, routineName: routineName, initialImage: File(pickedFile.path), setDetails: setDetails, memo: memo),
                      ));
                    }
                  },
                ),
                const SizedBox(height: 12),
                
                // 2. 갤러리/기본 공유하기
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primaryBlue,
                    side: const BorderSide(color: AppConstants.primaryBlue, width: 1.5),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.share),
                  label: Text('갤러리 사진으로 공유하기', style: GoogleFonts.notoSansKr(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(parentContext, MaterialPageRoute(builder: (_) => ShareScreen(record: record, routineName: routineName, setDetails: setDetails, memo: memo)));
                  },
                ),
                const SizedBox(height: 12),
                
                // 3. 기록 열람
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppConstants.secondaryText,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  },
                  child: Text('기록 자세히 보기', style: GoogleFonts.notoSansKr(fontSize: 15, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        );
      }
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildRoutineSelector(context, provider),
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: AppConstants.primaryText),
                        onPressed: _showMemoDialog,
                        tooltip: '실시간 운동 메모',
                      ),
                    ],
                  ),
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
                              bool includeCurrentSet = false;
                              final result = await showDialog<bool?>(
                                context: context,
                                builder: (context) {
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return AlertDialog(
                                        backgroundColor: AppConstants.dialogBackground,
                                        title: const Text('운동 종료', style: TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('운동을 종료하고 기록을 저장하시겠습니까?', style: TextStyle(color: AppConstants.secondaryText)),
                                            if (!provider.isResting) ...[
                                              const SizedBox(height: 16),
                                              CheckboxListTile(
                                                contentPadding: EdgeInsets.zero,
                                                activeColor: AppConstants.primaryBlue,
                                                title: Text('진행 중인 ${provider.currentSet}세트를 완료 기록에 포함', style: const TextStyle(color: AppConstants.primaryText, fontSize: 13)),
                                                value: includeCurrentSet,
                                                onChanged: (v) => setState(() => includeCurrentSet = v ?? false),
                                              )
                                            ]
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, null),
                                            child: const Text('취소', style: TextStyle(color: AppConstants.secondaryText)),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, includeCurrentSet), // true/false 반환
                                            child: const Text('종료 및 저장', style: TextStyle(color: AppConstants.primaryBlue, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      );
                                    }
                                  );
                                },
                              );

                              if (result != null) {
                                final resultData = await provider.endWorkout(includeCurrentSet: result);
                                final routineName = provider.routines.isNotEmpty ? provider.routines[provider.selectedRoutineIndex]['part'] : '기본 운동';
                                provider.resetTimer();
                                if (context.mounted && resultData != null) {
                                  _showWorkoutCompleteSheet(context, resultData.record, routineName, resultData.setDetails, resultData.memo);
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