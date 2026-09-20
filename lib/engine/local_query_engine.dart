import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import 'nlp_parser_engine.dart';

class LocalQueryResult {
  final String spokenText;
  final String displayText;
  final String intentType;
  final List<String> details;
  final dynamic createdItem;

  LocalQueryResult({
    required this.spokenText,
    required this.displayText,
    required this.intentType,
    this.details = const [],
    this.createdItem,
  });
}

class LocalQueryEngine {
  static Future<LocalQueryResult> processQuery(String input, AppProvider provider) async {
    final lower = input.toLowerCase().trim();
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // 1. GREETINGS & HELP QUERIES
    if (lower == 'hi' ||
        lower == 'hello' ||
        lower == 'hey' ||
        lower.contains('who are you') ||
        lower.contains('what can you do') ||
        lower == 'help') {
      return LocalQueryResult(
        spokenText:
            'Hello! I am your Maid Assistant. You can ask me about today\'s work, set alarms by saying "meeting at 3pm as alarm", or ask "tell my work" to hear your full day summary.',
        displayText:
            '👋 Hello! I am your Maid Assistant.\n\nTry saying:\n• "Meeting at 3pm as alarm"\n• "Tell my work"\n• "What is today\'s task?"\n• "What alarms are set?"\n• "Add task finish assignment"',
        intentType: 'help',
      );
    }

    // 2. ACTION: SET / CREATE ALARM (e.g. "meeting at 3pm as alarm", "set alarm for meeting at 3pm", "wake me up at 6am")
    final isAlarmCreation = lower.contains('set alarm') ||
        lower.contains('set an alarm') ||
        lower.contains('as alarm') ||
        lower.contains('wake me up') ||
        lower.contains('wake up at') ||
        (lower.contains('alarm') &&
            !lower.startsWith('what') &&
            !lower.startsWith('show') &&
            !lower.startsWith('list') &&
            !lower.contains('what alarms') &&
            !lower.contains('show alarms') &&
            !lower.contains('any alarm') &&
            (lower.contains(' at ') ||
                lower.contains('pm') ||
                lower.contains('am') ||
                RegExp(r'\b\d{1,2}(:\d{2})?\b').hasMatch(lower)));

    if (isAlarmCreation) {
      final parsed = NlpParserEngine.parseText(input);
      final alarmTime = parsed.startTime ?? '07:00';
      final alarmTitle = parsed.title.isNotEmpty ? parsed.title : 'Wake Up Alarm';

      final alarm = AlarmItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: alarmTitle,
        time: alarmTime,
        description: parsed.description ?? (parsed.title != 'Wake Up Alarm' ? 'Alarm for $alarmTitle' : ''),
        isEnabled: true,
        soundRingtone: provider.defaultAlarmTone,
      );

      await provider.addAlarm(alarm);

      // Convert 24h time to 12h readable for speech (e.g. 15:00 -> 3:00 PM)
      String timeSpeech = alarmTime;
      try {
        final timeParts = alarmTime.split(':');
        int hour = int.parse(timeParts[0]);
        int minute = int.parse(timeParts[1]);
        final amPm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final minStr = minute == 0 ? '' : ' ${minute.toString().padLeft(2, '0')}';
        timeSpeech = '$displayHour$minStr $amPm';
      } catch (_) {}

      return LocalQueryResult(
        spokenText: 'Alarm set for $alarmTitle at $timeSpeech! I will ring and wake you up.',
        displayText:
            '⏰ Alarm Set & Scheduled!\n\n• Title: $alarmTitle\n• Time: $alarmTime\n• Tone: ${provider.defaultAlarmTone}\n• Status: Active & Ready',
        intentType: 'alarm_created',
        createdItem: alarm,
      );
    }

    // 3. ACTION: ADD TASK / TO-DO (e.g. "add task finish report", "create task study math")
    if (lower.startsWith('add task') ||
        lower.startsWith('create task') ||
        lower.startsWith('task:') ||
        lower.contains('as task') ||
        lower.startsWith('remind me to')) {
      final parsed = NlpParserEngine.parseText(input);
      final task = TaskItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: parsed.title,
        dueDate: parsed.date ?? todayStr,
        priority: parsed.priority,
      );

      await provider.addTask(task);

      final pText = task.priority == 3 ? 'high priority' : 'regular';
      return LocalQueryResult(
        spokenText: 'Task added: ${task.title} for today as a $pText task.',
        displayText: '📋 Task Created!\n\n• Title: ${task.title}\n• Due: ${task.dueDate}\n• Priority: P${task.priority}',
        intentType: 'task_created',
        createdItem: task,
      );
    }

    // 4. TODAY'S TASKS & "TELL MY WORK" / "WHERE IS MY WORK" QUERIES
    final isTodayTaskQuery = lower.contains('today task') ||
        lower.contains("today's task") ||
        lower.contains('todays task') ||
        lower.contains('today tasks') ||
        lower.contains("today's tasks") ||
        lower.contains('todays tasks') ||
        lower.contains('task for today') ||
        lower.contains('tasks for today') ||
        lower.contains('tasks today') ||
        lower.contains('what is my task') ||
        lower.contains('whats my task') ||
        lower.contains("what's my task") ||
        lower.contains('whats today task') ||
        lower.contains("what's today task") ||
        lower.contains('what is today task');

    final isWorkQuery = lower.contains('tell my work') ||
        lower.contains('tell me my work') ||
        lower.contains('read out loud') ||
        lower.contains('read tasks') ||
        lower.contains('read my work') ||
        lower.contains('speak my work') ||
        lower.contains('where is my work') ||
        lower.contains('where my work') ||
        lower.contains('where are my work') ||
        lower.contains('what is my work') ||
        lower.contains('whats my work') ||
        lower.contains("what's my work") ||
        lower.contains('what are my works') ||
        lower.contains('my work') ||
        lower.contains('my works') ||
        lower.contains('show my work') ||
        lower.contains('what do i have to do today') ||
        lower.contains('what do i need to do today');

    if (isTodayTaskQuery || isWorkQuery) {
      final allTasks = provider.tasks;
      final pendingTasks = allTasks.where((t) => t.status != 'completed').toList();
      final todayPendingTasks = allTasks.where((t) {
        final isDueTodayOrUnset = t.dueDate == null || t.dueDate == todayStr;
        return isDueTodayOrUnset && t.status != 'completed';
      }).toList();

      final todayScheduleSlots = provider.getResolvedSchedule(todayStr);

      final relevantTasks = todayPendingTasks.isNotEmpty ? todayPendingTasks : pendingTasks;

      if (relevantTasks.isEmpty && todayScheduleSlots.isEmpty) {
        return LocalQueryResult(
          spokenText: 'You have no pending tasks or scheduled work for today! You are completely all caught up.',
          displayText: '🎉 All Caught Up!\n\nNo pending tasks or scheduled events found for today ($todayStr). Great job!',
          intentType: 'today_work',
        );
      }

      final List<String> spokenParts = [];
      final List<String> detailLines = [];

      if (relevantTasks.isNotEmpty) {
        final taskTitles = relevantTasks.take(4).map((t) => t.title).join(', ');
        spokenParts.add('For today, you have ${relevantTasks.length} pending ${relevantTasks.length == 1 ? 'task' : 'tasks'}: $taskTitles.');
        detailLines.add('📋 Tasks To-Do (${relevantTasks.length} pending):');
        for (var t in relevantTasks) {
          final pLabel = t.priority == 3 ? '🔴 [High]' : (t.priority == 2 ? '🟡 [Med]' : '⚪');
          final due = t.dueDate != null ? ' (Due: ${t.dueDate})' : '';
          detailLines.add('  • $pLabel ${t.title}$due');
        }
      } else {
        spokenParts.add('All your tasks are completed for today!');
      }

      if (todayScheduleSlots.isNotEmpty) {
        final slotTitles = todayScheduleSlots.take(3).map((s) => '${s.title} at ${s.startTime}').join(', ');
        spokenParts.add('You also have ${todayScheduleSlots.length} scheduled ${todayScheduleSlots.length == 1 ? 'routine' : 'routines'}: $slotTitles.');
        detailLines.add('\n📅 Today\'s Scheduled Routines:');
        for (var s in todayScheduleSlots) {
          detailLines.add('  • ${s.startTime} - ${s.endTime}: ${s.title}');
        }
      }

      spokenParts.add('Keep up the momentum!');

      return LocalQueryResult(
        spokenText: spokenParts.join(' '),
        displayText: '🌟 Today\'s Work & Tasks Overview ($todayStr):\n\n${detailLines.join('\n')}',
        intentType: 'today_work',
        details: detailLines,
      );
    }

    // 5. GENERAL TASKS & TO-DO QUERIES
    if (lower.contains('task') || lower.contains('to do') || lower.contains('todo') || lower.contains('pending')) {
      final tasks = provider.tasks;
      if (tasks.isEmpty) {
        return LocalQueryResult(
          spokenText: 'Your task list is completely empty! You have no tasks saved.',
          displayText: '✅ No tasks found. Use the Top To-Do bar or voice to add one!',
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
        final spokenStr = 'You have ${pendingTasks.length} pending tasks out of ${tasks.length} total. Next up is: ${topTask.title}.';
        final detailLines = pendingTasks.map((t) => '• [P${t.priority}] ${t.title} ${t.dueDate != null ? '(Due: ${t.dueDate})' : ''}').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '📋 Pending Tasks (${pendingTasks.length} left):\n\n${detailLines.join('\n')}',
          intentType: 'tasks',
          details: detailLines,
        );
      }
    }

    // 6. SCHEDULE / CALENDAR QUERIES
    if (lower.contains('schedule') ||
        lower.contains('event') ||
        lower.contains('calendar') ||
        lower.contains('routine') ||
        lower.contains('what do i have') ||
        lower.contains('today') ||
        lower.contains('tomorrow')) {
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

    // 7. READ-ONLY ALARMS QUERIES
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

    // 8. HABITS QUERIES
    if (lower.contains('habit') || lower.contains('streak')) {
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

    // 9. LOCAL NOTE SEARCH
    String searchTerm = lower
        .replaceAll(RegExp(r'^(search|find|show|where|look for|notes about|note for)\s+', caseSensitive: false), '')
        .trim();

    if (searchTerm.isNotEmpty && searchTerm.length > 2) {
      final matchedNotes = provider.notes.where((n) {
        final titleMatch = n.displayTitle.toLowerCase().contains(searchTerm);
        final bodyMatch = n.body.toLowerCase().contains(searchTerm);
        return titleMatch || bodyMatch;
      }).toList();

      if (matchedNotes.isNotEmpty) {
        final topNote = matchedNotes.first;
        final preview = topNote.body.length > 80 ? '${topNote.body.substring(0, 80)}...' : topNote.body;
        final spokenStr = 'Found ${matchedNotes.length} matching notes. Top note (${topNote.displayTitle}) says: $preview';
        final detailLines = matchedNotes.map((n) => '• ${n.displayTitle}: ${n.body}').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '🔍 Found ${matchedNotes.length} matching notes for "$searchTerm":\n\n${detailLines.join('\n')}',
          intentType: 'notes',
          details: detailLines,
        );
      }
    }

    // 10. DEFAULT / QUICK CAPTURE FALLBACK
    await provider.processQuickCapture(input);
    return LocalQueryResult(
      spokenText: 'I processed and saved your request: $input',
      displayText: '⚡ Command captured & saved: "$input"',
      intentType: 'quick_capture',
    );
  }
}
