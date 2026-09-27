import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
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

    // 0. STOP / SILENCE / CANCEL VOICE COMMANDS
    if (SpeechService.isStopCommand(lower) ||
        lower == 'stop' ||
        lower == 'maid stop' ||
        lower == 'hey maid stop' ||
        lower == 'stop talking' ||
        lower == 'stop reading' ||
        lower == 'stop speaking' ||
        lower == 'stop telling' ||
        lower == 'stop plans' ||
        lower == 'stop tasks' ||
        lower == 'shut up' ||
        lower == 'be quiet' ||
        lower == 'quiet' ||
        lower == 'silence' ||
        lower == 'mute' ||
        lower == 'cancel' ||
        lower == 'abort' ||
        lower == 'nevermind' ||
        lower == 'pause' ||
        lower == 'enough' ||
        lower == 'hush') {
      await TtsService.instance.stop();
      return LocalQueryResult(
        spokenText: '',
        displayText: '🛑 Assistant Stopped & Silenced\n\nVoice playback has been stopped.',
        intentType: 'stop',
      );
    }

    // 1. GREETINGS & HELP QUERIES
    if (lower == 'hi' ||
        lower == 'hello' ||
        lower == 'hey' ||
        lower.contains('who are you') ||
        lower.contains('what can you do') ||
        lower == 'help') {
      return LocalQueryResult(
        spokenText:
            'Hello! I am your Maid Assistant. You can ask me about today\'s work, set alarms by saying "meeting at 3pm as alarm", or ask "tell my work" to hear your full day summary. Say "stop" anytime to silence me.',
        displayText:
            '✨ Hello! I am your Maid Assistant.\n\nTry saying:\n• "Tell my work"\n• "What is today\'s task?"\n• "Meeting at 3pm as alarm"\n• "What alarms are set?"\n• "Stop" (to silence speech anytime)',
        intentType: 'help',
      );
    }

    // 2. ACTION: SET / CREATE ALARM (e.g. "meeting at 3pm as alarm", "set alarm for meeting at 3pm", "wake me up at 6am")
    final isAlarmCreation = lower.contains('set alarm') ||
        lower.contains('as alarm') ||
        lower.contains('alarm for') ||
        lower.contains('alarm at') ||
        lower.contains('wake me up at') ||
        lower.contains('set an alarm');

    if (isAlarmCreation) {
      final parsed = NlpParserEngine.parseText(input);
      String time = parsed.startTime ?? '07:00';
      String title = parsed.title;
      if (title.isEmpty || title.toLowerCase() == 'wake up alarm') {
        title = 'Alarm';
      }

      final createdAlarm = AlarmItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        time: time,
        description: parsed.description ?? 'Created via Maid Voice Assistant',
        isEnabled: true,
        soundRingtone: provider.defaultAlarmTone,
      );

      await provider.addAlarm(createdAlarm);

      return LocalQueryResult(
        spokenText: 'Done! I have set an alarm for $title at $time.',
        displayText: '🔔 Alarm Set Successfully!\n\n• Time: $time\n• Title: $title\n• Status: Active',
        intentType: 'alarm_created',
        createdItem: createdAlarm,
      );
    }

    // 3. ACTION: ADD / CREATE TASK (e.g. "add task buy milk", "create task finish homework", "task: buy groceries")
    final isTaskCreation = lower.startsWith('add task') ||
        lower.startsWith('create task') ||
        lower.startsWith('new task') ||
        lower.startsWith('task:');

    if (isTaskCreation) {
      final cleanTaskTitle = input
          .replaceFirst(RegExp(r'^(add task|create task|new task|task:)\s*', caseSensitive: false), '')
          .trim();

      if (cleanTaskTitle.isNotEmpty) {
        final parsed = NlpParserEngine.parseText(cleanTaskTitle);
        final newTask = TaskItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: parsed.title.isNotEmpty ? parsed.title : cleanTaskTitle,
          dueDate: parsed.date ?? todayStr,
          priority: parsed.priority,
        );

        await provider.addTask(newTask);

        return LocalQueryResult(
          spokenText: 'Added task: ${newTask.title} to your list.',
          displayText: '✅ Task Created!\n\n• Title: ${newTask.title}\n• Due: ${newTask.dueDate}\n• Priority: P${newTask.priority}',
          intentType: 'task_created',
          createdItem: newTask,
        );
      }
    }

    // 4. "TELL MY WORK" / "TODAY TASKS" / "ALL TASKS" / "FULL DAY OVERVIEW"
    final isTodayWorkQuery = lower.contains('tell my work') ||
        lower.contains('tell my tasks') ||
        lower.contains('all tasks') ||
        lower.contains('all task') ||
        lower.contains('my work') ||
        lower.contains('today task') ||
        lower.contains('today\'s task') ||
        lower.contains('today tasks') ||
        lower.contains('today\'s tasks') ||
        lower.contains('day overview') ||
        lower.contains('what do i have today') ||
        lower.contains('what are my tasks') ||
        lower.contains('show my tasks') ||
        lower.contains('what is my plan') ||
        lower.contains('what is the plan');

    if (isTodayWorkQuery) {
      final allTasks = provider.tasks;
      final pendingTasks = allTasks.where((t) => t.status != 'completed').toList();
      final completedCount = allTasks.where((t) => t.status == 'completed').length;
      final todayPending = provider.pendingTodayTasks;
      final overduePending = pendingTasks.where((t) {
        if (t.dueDate == null || t.dueDate!.isEmpty) return false;
        return t.dueDate!.compareTo(todayStr) < 0;
      }).toList();
      final upcomingPending = pendingTasks.where((t) {
        return !todayPending.contains(t) && !overduePending.contains(t);
      }).toList();

      final todayScheduleSlots = provider.getResolvedSchedule(todayStr);

      List<String> spokenParts = [];
      List<String> detailLines = [];

      spokenParts.add('Good day ${provider.userName}!');

      if (pendingTasks.isEmpty && allTasks.isEmpty) {
        spokenParts.add('You have no tasks in your to-do list right now.');
        detailLines.add('✨ No tasks in your to-do list yet.');
      } else if (pendingTasks.isEmpty) {
        spokenParts.add('All ${allTasks.length} of your tasks are completed! Excellent job.');
        detailLines.add('🎉 All ${allTasks.length} tasks completed!');
      } else {
        spokenParts.add('You have ${pendingTasks.length} pending ${pendingTasks.length == 1 ? 'task' : 'tasks'} in total ($completedCount completed).');

        // 1. Today's Tasks
        if (todayPending.isNotEmpty) {
          final titles = todayPending.map((t) => t.title).join(', ');
          spokenParts.add('For today, you have ${todayPending.length}: $titles.');

          detailLines.add('📋 Today\'s Tasks (${todayPending.length}):');
          for (var t in todayPending) {
            final pLabel = t.priority == 3 ? '🔴 [High]' : (t.priority == 2 ? '🟡 [Med]' : '⚪');
            detailLines.add('  • $pLabel ${t.title}');
          }
        } else {
          spokenParts.add('No pending tasks specifically due today.');
          detailLines.add('📋 Today\'s Tasks: All caught up for today!');
        }

        // 2. Overdue Tasks
        if (overduePending.isNotEmpty) {
          final titles = overduePending.take(3).map((t) => t.title).join(', ');
          spokenParts.add('You also have ${overduePending.length} overdue ${overduePending.length == 1 ? 'task' : 'tasks'}: $titles.');

          detailLines.add('\n⚠️ Overdue Tasks (${overduePending.length}):');
          for (var t in overduePending) {
            final pLabel = t.priority == 3 ? '🔴 [High]' : (t.priority == 2 ? '🟡 [Med]' : '⚪');
            detailLines.add('  • $pLabel ${t.title} (Due: ${t.dueDate})');
          }
        }

        // 3. Upcoming / Other Tasks
        if (upcomingPending.isNotEmpty) {
          final titles = upcomingPending.take(3).map((t) => t.title).join(', ');
          spokenParts.add('Other upcoming tasks include: $titles.');

          detailLines.add('\n🔮 Upcoming & Other Tasks (${upcomingPending.length}):');
          for (var t in upcomingPending) {
            final pLabel = t.priority == 3 ? '🔴 [High]' : (t.priority == 2 ? '🟡 [Med]' : '⚪');
            final dueStr = t.dueDate != null ? ' (Due: ${t.dueDate})' : '';
            detailLines.add('  • $pLabel ${t.title}$dueStr');
          }
        }
      }

      // Schedule slots
      if (todayScheduleSlots.isNotEmpty) {
        final slotTitles = todayScheduleSlots.take(3).map((s) => '${s.title} at ${s.startTime}').join(', ');
        spokenParts.add('You also have ${todayScheduleSlots.length} scheduled ${todayScheduleSlots.length == 1 ? 'routine' : 'routines'} today: $slotTitles.');
        detailLines.add('\n📅 Today\'s Scheduled Routines:');
        for (var s in todayScheduleSlots) {
          detailLines.add('  • ${s.startTime} - ${s.endTime}: ${s.title}');
        }
      }

      spokenParts.add('Keep up the great productivity!');

      return LocalQueryResult(
        spokenText: spokenParts.join(' '),
        displayText: '📊 Complete Work & Tasks Overview ($todayStr):\n\n${detailLines.join('\n')}',
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
          displayText: '✨ No tasks found. Use the Top To-Do bar or voice to add one!',
          intentType: 'tasks',
        );
      }

      final pendingTasks = tasks.where((t) => t.status != 'completed').toList();
      final completedCount = tasks.where((t) => t.status == 'completed').length;

      if (pendingTasks.isEmpty) {
        return LocalQueryResult(
          spokenText: 'Great job! All ${tasks.length} of your tasks are completed.',
          displayText: '🎉 All ${tasks.length} tasks completed!',
          intentType: 'tasks',
        );
      } else {
        final taskTitles = pendingTasks.take(5).map((t) => t.title).join(', ');
        final spokenStr = 'You have ${pendingTasks.length} pending tasks out of ${tasks.length} total ($completedCount completed). Key tasks are: $taskTitles.';
        final detailLines = pendingTasks.map((t) => '• [P${t.priority}] ${t.title} ${t.dueDate != null ? '(Due: ${t.dueDate})' : ''}').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '📌 All Pending Tasks (${pendingTasks.length} left, $completedCount done):\n\n${detailLines.join('\n')}',
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
          displayText: '🔔 No alarms set in Maid Assistant.',
          intentType: 'alarms',
        );
      }

      final activeAlarms = alarms.where((a) => a.isEnabled).toList();
      if (activeAlarms.isEmpty) {
        return LocalQueryResult(
          spokenText: 'All your alarms are currently turned off.',
          displayText: '🔔 ${alarms.length} alarms configured (all currently turned off).',
          intentType: 'alarms',
        );
      } else {
        final nextAlarm = activeAlarms.first;
        final descStr = nextAlarm.description.isNotEmpty ? ' with note: ${nextAlarm.description}' : '';
        final spokenStr = 'You have ${activeAlarms.length} active alarms. Next alarm is set for ${nextAlarm.time}$descStr.';
        final detailLines = activeAlarms.map((a) => '• ${a.time} - ${a.title}${a.description.isNotEmpty ? ' ("${a.description}")' : ''}').toList();

        return LocalQueryResult(
          spokenText: spokenStr,
          displayText: '🔔 Active Alarms:\n\n${detailLines.join('\n')}',
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
          displayText: '📝 Found ${matchedNotes.length} matching notes for "$searchTerm":\n\n${detailLines.join('\n')}',
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
