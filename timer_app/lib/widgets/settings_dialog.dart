import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  final int initialMaxSets;
  final int initialRestSeconds;

  const SettingsDialog({
    super.key,
    required this.initialMaxSets,
    required this.initialRestSeconds,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int tempMaxSets;
  late int tempRestSeconds;

  @override
  void initState() {
    super.initState();
    tempMaxSets = widget.initialMaxSets;
    tempRestSeconds = widget.initialRestSeconds;
  }

  @override
  Widget build(BuildContext context) {
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
                    onPressed: () => setState(() { if (tempMaxSets > 1) tempMaxSets--; }),
                  ),
                  Text('$tempMaxSets', style: const TextStyle(color: Colors.white, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
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
              const Text('휴식 시간(초):', style: TextStyle(color: Colors.white, fontSize: 16)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                    onPressed: () => setState(() { if (tempRestSeconds > 10) tempRestSeconds -= 10; }),
                  ),
                  Text('$tempRestSeconds', style: const TextStyle(color: Colors.white, fontSize: 18)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    onPressed: () => setState(() { tempRestSeconds += 10; }),
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
            Navigator.pop(context, {'maxSets': tempMaxSets, 'restSeconds': tempRestSeconds});
          },
          child: const Text('저장', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }
}