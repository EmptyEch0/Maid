import '../models/app_models.dart';

class WeeklyReviewReport {
  final int totalPlannedMinutes;
  final int totalActualMinutes;
  final double executionRatio; // actual / planned
  final int totalTasksCompleted;
  final int totalTasksPending;
  final int postponementsCount;
  final Map<String, int> actualMinutesBySubject;
  final Map<String, int> plannedMinutesBySubject;

  WeeklyReviewReport({
    required this.totalPlannedMinutes,
    required this.totalActualMinutes,
    required this.executionRatio,
    required this.totalTasksCompleted,
    required this.totalTasksPending,
    required this.postponementsCount,
    required this.actualMinutesBySubject,
    required this.plannedMinutesBySubject,
  });

  String get summaryRating {
    if (executionRatio >= 0.9) return 'Excellent execution! 🚀';
    if (executionRatio >= 0.7) return 'Good steady progress 👍';
    if (executionRatio >= 0.5) return 'Moderate progress — check postponed items ⚖️';
    return 'Room for improvement — simplify your plan 💡';
  }
}

class WeeklyReviewEngine {
  static WeeklyReviewReport generateReport({
    required List<StudySession> studySessions,
    required List<TaskItem> tasks,
    required List<ScheduleException> exceptions,
  }) {
    int totalPlanned = 0;
    int totalActual = 0;
    final Map<String, int> actualBySubj = {};
    final Map<String, int> plannedBySubj = {};

    for (var session in studySessions) {
      totalPlanned += session.plannedMinutes;
      totalActual += session.actualMinutes;

      actualBySubj[session.subject] = (actualBySubj[session.subject] ?? 0) + session.actualMinutes;
      plannedBySubj[session.subject] = (plannedBySubj[session.subject] ?? 0) + session.plannedMinutes;
    }

    int completedTasks = tasks.where((t) => t.status == 'completed').length;
    int pendingTasks = tasks.where((t) => t.status != 'completed').length;
    int postponements = exceptions.length;

    double ratio = totalPlanned > 0 ? (totalActual / totalPlanned) : (totalActual > 0 ? 1.0 : 0.0);

    return WeeklyReviewReport(
      totalPlannedMinutes: totalPlanned,
      totalActualMinutes: totalActual,
      executionRatio: ratio,
      totalTasksCompleted: completedTasks,
      totalTasksPending: pendingTasks,
      postponementsCount: postponements,
      actualMinutesBySubject: actualBySubj,
      plannedMinutesBySubject: plannedBySubj,
    );
  }
}
