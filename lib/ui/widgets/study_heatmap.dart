import 'package:flutter/material.dart';
import '../../models/app_models.dart';

class StudyHeatmapGrid extends StatelessWidget {
  final List<StudySession> studySessions;

  const StudyHeatmapGrid({super.key, required this.studySessions});

  Map<String, int> _aggregateDailyMinutes() {
    final Map<String, int> dailyMins = {};
    for (var session in studySessions) {
      if (session.startTs.length >= 10) {
        final dateKey = session.startTs.substring(0, 10);
        dailyMins[dateKey] = (dailyMins[dateKey] ?? 0) + session.actualMinutes;
      }
    }
    return dailyMins;
  }

  Color _getColorForMinutes(int minutes, bool isDarkMode) {
    if (minutes <= 0) {
      return isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200;
    }
    if (minutes < 30) {
      return Colors.green.shade200;
    }
    if (minutes < 60) {
      return Colors.green.shade400;
    }
    if (minutes < 120) {
      return Colors.green.shade600;
    }
    return Colors.green.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final dailyMins = _aggregateDailyMinutes();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Generate 12 weeks of days ending today
    final daysCount = 12 * 7;
    final startDate = now.subtract(Duration(days: daysCount - 1));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Study Activity Heatmap (12 Weeks)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    const Text('Less ', style: TextStyle(fontSize: 10)),
                    Container(width: 8, height: 8, color: _getColorForMinutes(0, isDarkMode)),
                    const SizedBox(width: 2),
                    Container(width: 8, height: 8, color: Colors.green.shade200),
                    const SizedBox(width: 2),
                    Container(width: 8, height: 8, color: Colors.green.shade400),
                    const SizedBox(width: 2),
                    Container(width: 8, height: 8, color: Colors.green.shade600),
                    const SizedBox(width: 2),
                    Container(width: 8, height: 8, color: Colors.green.shade800),
                    const Text(' More', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, // 7 days a week
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: daysCount,
                itemBuilder: (context, index) {
                  final day = startDate.add(Duration(days: index));
                  final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  final mins = dailyMins[dateKey] ?? 0;
                  final cellColor = _getColorForMinutes(mins, isDarkMode);

                  return Tooltip(
                    message: '$dateKey: $mins mins studied',
                    child: Container(
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
