import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/app_provider.dart';
import '../widgets/study_heatmap.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/animated_entry.dart';
import '../widgets/universal_reschedule_dialog.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final report = provider.getWeeklyReport();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Weekly Review & Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Reschedule Anything',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Glass Card
            AnimatedEntry(
              index: 0,
              child: GlassCard(
                accentColor: colorScheme.primary,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.analytics_rounded, size: 36, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.summaryRating,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Planned: ${report.totalPlannedMinutes}m  •  Actual: ${report.totalActualMinutes}m',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Study Heatmap Grid in Glass Card
            AnimatedEntry(
              index: 1,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Study Heatmap Activity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        GlassPillBadge(label: 'Last 12 Weeks', color: colorScheme.secondary),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StudyHeatmapGrid(studySessions: provider.studySessions),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Grid Cards
            AnimatedEntry(
              index: 2,
              child: Row(
                children: [
                  _buildStatBox(
                    context,
                    title: 'Tasks Done',
                    value: '${report.totalTasksCompleted}',
                    subtitle: '${report.totalTasksPending} pending',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBox(
                    context,
                    title: 'Rescheduled',
                    value: '${report.postponementsCount}',
                    subtitle: 'Schedule shifts',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBox(
                    context,
                    title: 'Execution',
                    value: '${(report.executionRatio * 100).round()}%',
                    subtitle: 'Time accuracy',
                    color: colorScheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // FL_CHART Bar Comparison: Planned vs Actual
            AnimatedEntry(
              index: 3,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Planned vs Actual Study Time (Mins)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (report.totalPlannedMinutes > report.totalActualMinutes ? report.totalPlannedMinutes : report.totalActualMinutes) + 30.0,
                          barGroups: [
                            BarChartGroupData(
                              x: 0,
                              barRods: [
                                BarChartRodData(toY: report.totalPlannedMinutes.toDouble(), color: const Color(0xFF6366F1), width: 26, borderRadius: BorderRadius.circular(6)),
                                BarChartRodData(toY: report.totalActualMinutes.toDouble(), color: const Color(0xFF10B981), width: 26, borderRadius: BorderRadius.circular(6)),
                              ],
                            ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) => const Text('Weekly Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Subject Breakdown List
            AnimatedEntry(
              index: 4,
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Actual Hours by Focus Subject', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (report.actualMinutesBySubject.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No completed study sessions recorded yet.'),
                      )
                    else
                      ...report.actualMinutesBySubject.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.book_rounded, color: Color(0xFF6366F1), size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                              GlassPillBadge(
                                label: '${entry.value} mins',
                                color: const Color(0xFF6366F1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(BuildContext context, {required String title, required String value, required String subtitle, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
