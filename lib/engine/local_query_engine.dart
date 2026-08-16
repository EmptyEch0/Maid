import 'package:intl/intl.dart';
import '../providers/app_provider.dart';

class LocalQueryResult {
  final String spokenText;
  final String displayText;
  final String intentType;
  final List<String> details;

  LocalQueryResult({
    required this.spokenText,
    required this.displayText,
    required this.intentType,
    this.details = const [],
  });
}

class LocalQueryEngine {
  static LocalQueryResult processQuery(String input, AppProvider provider) {
    final lower = input.toLowerCase().trim();
    final now = DateTime.now();

    // 1. SCHEDULE / CALENDAR QUERIES
    if (lower.contains('schedule') || lower.contains('event') || lower.contains('calendar') || lower.contains('what do i have') || lower.contains('today')) {
      bool isTomorrow = lower.contains('tomorrow');
      final targetDate = isTomorrow ? now.add(const Duration(days: 1)) : now;
      final targetDateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final dayLabel = isTomorrow ? 'tomorrow' : 'today';

      final slots = provider.getResolvedSchedule(targetDateStr);

      if (slots.isEmpty) {
        return LocalQueryResult(
          spokenText: 'You have no events or routines scheduled for $dayLabel.',
          displayText: '📅 No events or routines scheduled for $dayLabel.',
          intentType: 'schedule',
        );
      } else {
        final titles = slots.map((s) => '${s.title} at ${s.startTime}').join(', ');
        final spokenStr = 'You have ${slots.length} items scheduled for $dayLabel: $titles.';
        final detailLines = slots.map((s) => '• ${s.startTime} - ${s.endTime}: ${s.title} (${s.category})').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '📅 Schedule for $dayLabel (${slots.length} items):\n\n${detailLines.join('\n')}',
          intentType: 'schedule',
          details: detailLines,
        );
      }
    }

    // 2. TASKS & TO-DO QUERIES
    if (lower.contains('task') || lower.contains('to do') || lower.contains('todo') || lower.contains('progress')) {
      final tasks = provider.tasks;
      if (tasks.isEmpty) {
        return LocalQueryResult(
          spokenText: 'Your task inbox is completely empty! You are all caught up.',
          displayText: '✅ No tasks found in your inbox.',
          intentType: 'tasks',
        );
      }

      final pendingTasks = tasks.where((t) => t.status != 'completed').toList();

      if (pendingTasks.isEmpty) {
        return LocalQueryResult(
          spokenText: 'Great job! All ${tasks.length} of your tasks are completed.',
          displayText: '🎉 All ${tasks.length} tasks completed!',
          intentType: 'tasks',
        );
      } else {
        final topTask = pendingTasks.first;
        final spokenStr = 'You have ${pendingTasks.length} pending tasks out of ${tasks.length} total. Next task is: ${topTask.title}.';
        final detailLines = pendingTasks.map((t) => '• [P${t.priority}] ${t.title} ${t.dueDate != null ? '(Due: ${t.dueDate})' : ''}').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '📋 Pending Tasks (${pendingTasks.length} left):\n\n${detailLines.join('\n')}',
          intentType: 'tasks',
          details: detailLines,
        );
      }
    }

    // 3. ALARMS & WAKE-UP QUERIES
    if (lower.contains('alarm') || lower.contains('wake up') || lower.contains('ring')) {
      final alarms = provider.alarms;
      if (alarms.isEmpty) {
        return LocalQueryResult(
          spokenText: 'You currently have no wake up alarms configured.',
          displayText: '⏰ No alarms set in Maid Assistant.',
          intentType: 'alarms',
        );
      }

      final activeAlarms = alarms.where((a) => a.isEnabled).toList();
      if (activeAlarms.isEmpty) {
        return LocalQueryResult(
          spokenText: 'All your alarms are currently turned off.',
          displayText: '⏰ ${alarms.length} alarms configured (all currently turned off).',
          intentType: 'alarms',
        );
      } else {
        final nextAlarm = activeAlarms.first;
        final descStr = nextAlarm.description.isNotEmpty ? ' with note: ${nextAlarm.description}' : '';
        final spokenStr = 'You have ${activeAlarms.length} active alarms. Next alarm is set for ${nextAlarm.time}$descStr.';
        final detailLines = activeAlarms.map((a) => '• ${a.time} - ${a.title}${a.description.isNotEmpty ? ' ("${a.description}")' : ''}').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '⏰ Active Alarms:\n\n${detailLines.join('\n')}',
          intentType: 'alarms',
          details: detailLines,
        );
      }
    }

    // 4. HABITS QUERIES
    if (lower.contains('habit') || lower.contains('streak') || lower.contains('routine')) {
      final habits = provider.habits;
      if (habits.isEmpty) {
        return LocalQueryResult(
          spokenText: 'You have not added any daily habits yet.',
          displayText: '⚡ No daily habits configured.',
          intentType: 'habits',
        );
      }

      final topHabit = habits.reduce((a, b) => a.streak >= b.streak ? a : b);
      final spokenStr = 'You have ${habits.length} habits tracked. Your longest streak is ${topHabit.title} with ${topHabit.streak} days!';
      final detailLines = habits.map((h) => '• ${h.title} (🔥 ${h.streak}d streak)').toList();

      return LocalQueryResult(
        spokenText: spokenStr,
        displayText: '⚡ Daily Habits (${habits.length}):\n\n${detailLines.join('\n')}',
        intentType: 'habits',
        details: detailLines,
      );
    }

    // 5. LOCAL NOTE & KNOWLEDGE KEYWORD SEARCH
    String searchTerm = lower
        .replaceAll(RegExp(r'^(search|find|show|where|look for|notes about|note for)\s+', caseSensitive: false), '')
        .trim();

    if (searchTerm.isNotEmpty && searchTerm.length > 2) {
      final matchedNotes = provider.notes.where((n) {
        final titleMatch = (n.title ?? '').toLowerCase().contains(searchTerm);
        final bodyMatch = n.body.toLowerCase().contains(searchTerm);
        return titleMatch || bodyMatch;
      }).toList();

      if (matchedNotes.isNotEmpty) {
        final topNote = matchedNotes.first;
        final preview = topNote.body.length > 80 ? '${topNote.body.substring(0, 80)}...' : topNote.body;
        final spokenStr = 'Found ${matchedNotes.length} matching notes. Top note says: $preview';
        final detailLines = matchedNotes.map((n) => '• ${n.title ?? 'Note'}: ${n.body}').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '🔍 Found ${matchedNotes.length} matching notes for "$searchTerm":\n\n${detailLines.join('\n')}',
          intentType: 'notes',
          details: detailLines,
        );
      }
    }

    // 6. DEFAULT / QUICK CAPTURE FALLBACK
    return LocalQueryResult(
      spokenText: 'I processed your request: $input',
      displayText: '⚡ Command captured: "$input"',
      intentType: 'quick_capture',
    );
  }
}
