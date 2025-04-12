import 'package:flutter/material.dart';

class XPLevelWidget extends StatelessWidget {
  final int xp;
  final int level;

  const XPLevelWidget({super.key, required this.xp, required this.level});

  @override
  Widget build(BuildContext context) {
    double progress = (xp % 500) / 500.0;

    return Card(
      margin: EdgeInsets.all(16),
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Level $level",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.indigo.shade100,
              color: Colors.indigo,
              minHeight: 10,
            ),
            const SizedBox(height: 6),
            Text("XP: ${xp % 500} / 500",
                style: TextStyle(fontSize: 14, color: Colors.indigo.shade700))
          ],
        ),
      ),
    );
  }
}
