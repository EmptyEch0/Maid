import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../engine/scheduling_engine.dart';

class WidgetUpdateService {
  static final WidgetUpdateService instance = WidgetUpdateService._init();
  WidgetUpdateService._init();

  static const String appGroupId = 'group.com.maid.app.maid';
  static const String androidWidgetProvider = 'MaidTodoWidgetProvider';

  Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (_) {}
  }

  /// Updates the Android Home Screen Widget with the latest to-dos and work items
  Future<void> updateTodoWidget({
    required List<TaskItem> tasks,
    required List<CalendarEvent> events,
    required List<RecurrenceRule> recurrenceRules,
    required List<ScheduleException> exceptions,
  }) async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final dateHeader = DateFormat('EEE, MMM d').format(now); // e.g. "Thu, Sep 17"

      // Filter pending tasks for today or unscheduled
      final pendingTasks = tasks.where((t) {
        final isTodayOrNoDate = t.dueDate == null || t.dueDate == todayStr;
        return isTodayOrNoDate && t.status != 'completed';
      }).toList();

      // Resolve today's scheduled calendar routines/events
      final todaySlots = SchedulingEngine.resolveScheduleForDate(
        targetDate: todayStr,
        oneOffEvents: events,
        recurrenceRules: recurrenceRules,
        exceptions: exceptions,
      );

      final List<String> displayLines = [];

      // 1. Add pending to-dos
      for (final task in pendingTasks.take(5)) {
        String priorityIcon = '•';
        if (task.priority == 3) {
          priorityIcon = '🔴';
        } else if (task.priority == 2) {
          priorityIcon = '🟡';
        } else {
          priorityIcon = '⚪';
        }
        displayLines.add('$priorityIcon ${task.title}');
      }

      // If there are more tasks
      if (pendingTasks.length > 5) {
        displayLines.add('+ ${pendingTasks.length - 5} more tasks...');
      }

      // 2. Add upcoming routines if space permits
      if (displayLines.length < 5 && todaySlots.isNotEmpty) {
        for (final slot in todaySlots.take(5 - displayLines.length)) {
          displayLines.add('⏰ ${slot.startTime} ${slot.title}');
        }
      }

      String tasksText;
      if (displayLines.isEmpty) {
        tasksText = '🎉 All caught up!\nNothing planned for today.';
      } else {
        tasksText = displayLines.join('\n');
      }

      // Save data for Android AppWidget
      await HomeWidget.saveWidgetData<String>('widget_date', dateHeader);
      await HomeWidget.saveWidgetData<String>('widget_tasks_text', tasksText);
      await HomeWidget.saveWidgetData<int>('widget_task_count', pendingTasks.length);

      // Trigger native widget update
      await HomeWidget.updateWidget(
        name: androidWidgetProvider,
        androidName: androidWidgetProvider,
      );
    } catch (_) {
      // Ignore if home widget is not supported on platform
    }
  }
}
