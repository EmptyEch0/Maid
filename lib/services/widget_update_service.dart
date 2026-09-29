import 'dart:convert';
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

  // How far ahead calendar events are handed to the widget. The native widget picks "today"
  // itself from this list, so it stays correct after midnight even if the app isn't opened.
  static const int _eventLookaheadDays = 14;

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
      final dayFormat = DateFormat('yyyy-MM-dd');
      final todayStr = dayFormat.format(now);
      final dateHeader = DateFormat('EEE, MMM d').format(now); // e.g. "Thu, Sep 24"

      // 1. Resolve events/routines for today and the coming days
      final List<Map<String, String>> upcomingEvents = [];
      List<ScheduledSlot> todaySlots = [];
      for (int i = 0; i < _eventLookaheadDays; i++) {
        final dateStr = dayFormat.format(DateTime(now.year, now.month, now.day + i));
        final slots = SchedulingEngine.resolveScheduleForDate(
          targetDate: dateStr,
          oneOffEvents: events,
          recurrenceRules: recurrenceRules,
          exceptions: exceptions,
        );
        if (i == 0) todaySlots = slots;
        for (final slot in slots) {
          final parsed = TimeHelper.parseTime(slot.startTime);
          upcomingEvents.add({
            'date': slot.date,
            'time': TimeHelper.format12h(parsed.hour, parsed.minute),
            'sort': TimeHelper.format24h(parsed.hour, parsed.minute),
            'title': slot.title,
            // Routines repeat daily/weekly; only one-off events are worth listing as "upcoming"
            'recurring': slot.isRecurringInstance ? '1' : '0',
          });
        }
      }
      upcomingEvents.sort((a, b) => '${a['date']} ${a['sort']}'.compareTo('${b['date']} ${b['sort']}'));

      // 2. Filter pending tasks
      final todayPendingTasks = tasks.where((t) {
        final isTodayOrNoDate = t.dueDate == null || t.dueDate == todayStr;
        return isTodayOrNoDate && t.status != 'completed';
      }).toList();

      final allPendingTasks = tasks.where((t) => t.status != 'completed').toList();
      final pendingTasksJson = allPendingTasks
          .take(30)
          .map((t) => {'title': t.title, 'priority': t.priority, 'due': t.dueDate ?? ''})
          .toList();

      // 3. Pre-rendered text, used as a fallback by older widget code
      final List<String> displayLines = [];
      for (final slot in todaySlots.take(3)) {
        final parsed = TimeHelper.parseTime(slot.startTime);
        displayLines.add('📅 ${TimeHelper.format12h(parsed.hour, parsed.minute)} ${slot.title}');
      }

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

      final tasksText = displayLines.isEmpty ? '🎉 All caught up!\nNothing planned.' : displayLines.join('\n');
      final eventsJson = jsonEncode(upcomingEvents);
      final tasksJson = jsonEncode(pendingTasksJson);

      // 4. Save data via HomeWidget (HomeWidgetPreferences on Android)
      await HomeWidget.saveWidgetData<String>('widget_date', dateHeader);
      await HomeWidget.saveWidgetData<String>('widget_tasks_text', tasksText);
      await HomeWidget.saveWidgetData<int>('widget_task_count', tasksToShow.length);
      await HomeWidget.saveWidgetData<String>('widget_events_json', eventsJson);
      await HomeWidget.saveWidgetData<String>('widget_pending_tasks_json', tasksJson);

      // Also save to Flutter SharedPreferences as backup
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('widget_date', dateHeader);
        await prefs.setString('widget_tasks_text', tasksText);
        await prefs.setInt('widget_task_count', tasksToShow.length);
        await prefs.setString('widget_events_json', eventsJson);
        await prefs.setString('widget_pending_tasks_json', tasksJson);
      } catch (_) {}

      // 5. Trigger native widget update
      await HomeWidget.updateWidget(
        name: androidWidgetProvider,
        androidName: androidWidgetProvider,
      );
    } catch (_) {
      // Ignore if home widget is not supported on platform
    }
  }
}
