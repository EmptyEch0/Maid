import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Updates the Android Home Screen Widget with the latest to-dos and scheduled events
  Future<void> updateTodoWidget({
    required List<TaskItem> tasks,
    required List<CalendarEvent> events,
    required List<RecurrenceRule> recurrenceRules,
    required List<ScheduleException> exceptions,
  }) async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final dateHeader = DateFormat('EEE, MMM d').format(now); // e.g. "Thu, Sep 24"

      // 1. Resolve today's scheduled events/routines
      final todaySlots = SchedulingEngine.resolveScheduleForDate(
        targetDate: todayStr,
        oneOffEvents: events,
        recurrenceRules: recurrenceRules,
        exceptions: exceptions,
      );

      // 2. Filter pending tasks
      final todayPendingTasks = tasks.where((t) {
        final isTodayOrNoDate = t.dueDate == null || t.dueDate == todayStr;
        return isTodayOrNoDate && t.status != 'completed';
      }).toList();

      final allPendingTasks = tasks.where((t) => t.status != 'completed').toList();

      final List<String> displayLines = [];

      // Add Today's Scheduled Events first
      if (todaySlots.isNotEmpty) {
        for (final slot in todaySlots.take(3)) {
          displayLines.add('📅 ${slot.startTime} ${slot.title}');
        }
      }

      // Add Today's Tasks or General Pending Tasks
      final tasksToShow = todayPendingTasks.isNotEmpty ? todayPendingTasks : allPendingTasks;
      final remainingSlotCount = 5 - displayLines.length;

      if (tasksToShow.isNotEmpty && remainingSlotCount > 0) {
        for (final task in tasksToShow.take(remainingSlotCount)) {
          String icon = '•';
          if (task.priority == 3) {
            icon = '🔴';
          } else if (task.priority == 2) {
            icon = '🟡';
          }
          displayLines.add('$icon ${task.title}');
        }
      }

      if (tasksToShow.length > remainingSlotCount && remainingSlotCount > 0) {
        final remaining = tasksToShow.length - remainingSlotCount;
        displayLines.add('+$remaining more...');
      }

      String tasksText;
      if (displayLines.isEmpty) {
        tasksText = '🎉 All caught up!\nNothing planned.';
      } else {
        tasksText = displayLines.join('\n');
      }

      // 1. Save data via HomeWidget (group.com.maid.app.maid / default prefs)
      await HomeWidget.saveWidgetData<String>('widget_date', dateHeader);
      await HomeWidget.saveWidgetData<String>('widget_tasks_text', tasksText);
      await HomeWidget.saveWidgetData<int>('widget_task_count', tasksToShow.length);

      // 2. Also save to Flutter SharedPreferences as backup
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('widget_date', dateHeader);
        await prefs.setString('widget_tasks_text', tasksText);
        await prefs.setInt('widget_task_count', tasksToShow.length);
      } catch (_) {}

      // 3. Trigger native widget update
      await HomeWidget.updateWidget(
        name: androidWidgetProvider,
        androidName: androidWidgetProvider,
      );
    } catch (_) {
      // Ignore if home widget is not supported on platform
    }
  }
}
