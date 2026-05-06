import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/workout_timer_provider.dart';

class SettingsDialog extends StatefulWidget {
  final int initialMaxSets;
  final int initialRestSeconds;
  final bool initialBeepEnabled;

  const SettingsDialog({
    super.key,
    required this.initialMaxSets,
    required this.initialRestSeconds,
    required this.initialBeepEnabled,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int tempMaxSets;
  late int tempRestSeconds;
  late bool tempBeepEnabled;

  @override
  void initState() {
    super.initState();
    tempMaxSets = widget.initialMaxSets;
    tempRestSeconds = widget.initialRestSeconds;
    tempBeepEnabled = widget.initialBeepEnabled;
  }

  void _openRoutineManager(BuildContext context) {
    final provider = Provider.of<WorkoutTimerProvider>(context, listen: false);
    // 원본 데이터 보호를 위한 깊은 복사 (Deep Copy)
    List<Map<String, dynamic>> tempRoutines = provider.routines.map((r) {
      return {
        'part': r['part'],
        'exercises': List<String>.from(r['exercises'] ?? []),
      };
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: AppConstants.dialogBackground,
              title: const Text('운동 루틴 관리', style: TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold, fontSize: 18)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: tempRoutines.isEmpty
                          ? const Center(child: Text('설정된 루틴이 없습니다.\n새 루틴(부위)을 추가해주세요.', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.secondaryText)))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: tempRoutines.length,
                              itemBuilder: (context, index) {
                                final routine = tempRoutines[index];
                                return Card(
                                  color: AppConstants.surfaceColor,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const Icon(Icons.folder, color: AppConstants.primaryBlue),
                                    title: Text(routine['part'], style: const TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
                                    subtitle: Text('${(routine['exercises'] as List).length}개 종목', style: const TextStyle(color: AppConstants.secondaryText)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: AppConstants.primaryBlue),
                                          onPressed: () {
                                            _showInputDialog(context, '루틴 이름 변경', '새로운 이름을 입력하세요', (newName) {
                                              setModalState(() {
                                                tempRoutines[index]['part'] = newName;
                                              });
                                            }, initialText: routine['part']);
                                          },
                                        ),
                                        if (routine['part'] != '기본 운동')
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: AppConstants.accentRed),
                                            onPressed: () {
                                              setModalState(() {
                                                tempRoutines.removeAt(index);
                                              });
                                            },
                                          ),
                                      ],
                                    ),
                                    onTap: () {
                                      _openRoutineDetailManager(context, routine, (updatedRoutine) {
                                        setModalState(() {
                                          tempRoutines[index] = updatedRoutine;
                                        });
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.surfaceColor, foregroundColor: AppConstants.primaryBlue),
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('새 루틴(부위) 추가'),
                      onPressed: () {
                        _showInputDialog(context, '루틴 추가', '예: 가슴, 등, 하체', (newName) {
                          setModalState(() {
                            tempRoutines.add({'part': newName, 'exercises': <String>[]});
                          });
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    provider.saveRoutines(tempRoutines);
                    Navigator.pop(context);
                  },
                  child: const Text('저장', style: TextStyle(color: AppConstants.primaryBlue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openRoutineDetailManager(BuildContext context, Map<String, dynamic> routine, Function(Map<String, dynamic>) onSave) {
    List<String> tempExercises = List<String>.from(routine['exercises']);
    String partName = routine['part'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDetailState) {
            return AlertDialog(
              backgroundColor: AppConstants.dialogBackground,
              title: Text('$partName 종목 관리', style: const TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: tempExercises.isEmpty
                          ? const Center(child: Text('설정된 종목이 없습니다.\n추가해주세요.', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.secondaryText)))
                          : ReorderableListView.builder(
                              shrinkWrap: true,
                              itemCount: tempExercises.length,
                              onReorder: (oldIndex, newIndex) {
                                setDetailState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = tempExercises.removeAt(oldIndex);
                                  tempExercises.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                return ListTile(
                                  key: ValueKey('${tempExercises[index]}_$index'),
                                  leading: const Icon(Icons.drag_handle, color: AppConstants.secondaryText),
                                  title: Text(tempExercises[index], style: const TextStyle(color: AppConstants.primaryText)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: AppConstants.accentRed, size: 20),
                                    onPressed: () {
                                      setDetailState(() {
                                        tempExercises.removeAt(index);
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.surfaceColor, foregroundColor: AppConstants.primaryBlue),
                      icon: const Icon(Icons.add),
                      label: const Text('새 종목 추가'),
                      onPressed: () {
                        _showInputDialog(context, '종목 추가', '예: 벤치프레스', (newName) {
                          setDetailState(() {
                            tempExercises.add(newName);
                          });
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () {
                    onSave({'part': partName, 'exercises': tempExercises});
                    Navigator.pop(context);
                  },
                  child: const Text('적용', style: TextStyle(color: AppConstants.primaryBlue)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInputDialog(BuildContext context, String title, String hint, Function(String) onAdd, {String? initialText}) {
    final controller = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppConstants.dialogBackground,
          title: Text(title, style: const TextStyle(color: AppConstants.primaryText)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppConstants.primaryText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppConstants.secondaryText),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.secondaryText)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppConstants.primaryBlue)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  onAdd(controller.text.trim());
                }
                Navigator.pop(context);
              },
              child: const Text('추가', style: TextStyle(color: AppConstants.primaryBlue)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppConstants.dialogBackground,
      title: const Text('타이머 설정', style: TextStyle(color: AppConstants.primaryText, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('목표 세트 수:', style: TextStyle(color: AppConstants.primaryText, fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppConstants.primaryText),
                      onPressed: () => setState(() { if (tempMaxSets > 1) tempMaxSets--; }),
                    ),
                    Text('$tempMaxSets', style: const TextStyle(color: AppConstants.primaryText, fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppConstants.primaryText),
                      onPressed: () => setState(() { tempMaxSets++; }),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('휴식 시간(초):', style: TextStyle(color: AppConstants.primaryText, fontSize: 16)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: AppConstants.primaryText),
                      onPressed: () => setState(() { if (tempRestSeconds > 10) tempRestSeconds -= 10; }),
                    ),
                    Text('$tempRestSeconds', style: const TextStyle(color: AppConstants.primaryText, fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppConstants.primaryText),
                      onPressed: () => setState(() { tempRestSeconds += 10; }),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('비프음 알림:', style: TextStyle(color: AppConstants.primaryText, fontSize: 16)),
                Switch(
                  value: tempBeepEnabled,
                  onChanged: (value) => setState(() { tempBeepEnabled = value; }),
                  activeThumbColor: AppConstants.primaryBlue,
                )
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: AppConstants.dividerColor),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('운동 루틴 및 종목 관리', style: TextStyle(color: AppConstants.primaryText)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppConstants.secondaryText),
              onTap: () => _openRoutineManager(context),
            )
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'maxSets': tempMaxSets,
              'restSeconds': tempRestSeconds,
              'isBeepEnabled': tempBeepEnabled,
            });
          },
          child: const Text('저장', style: TextStyle(color: AppConstants.primaryBlue)),
        ),
      ],
    );
  }
}