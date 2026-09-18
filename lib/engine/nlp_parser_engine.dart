import 'package:intl/intl.dart';

class ParsedQuickCapture {
  final String title;
  final String? date;
  final String? startTime;
  final String? endTime;
  final String category;
  final int priority;
  final String type; // 'event', 'task', 'note', 'alarm', 'habit', 'inbox'
  final String? description;

  ParsedQuickCapture({
    required this.title,
    this.date,
    this.startTime,
    this.endTime,
    this.category = 'General',
    this.priority = 2,
    this.type = 'task',
    this.description,
  });
}

class NlpParserEngine {
  static ParsedQuickCapture parseText(String input) {
    final original = input.trim();
    final lower = original.toLowerCase();
    final now = DateTime.now();

    String parsedDate = DateFormat('yyyy-MM-dd').format(now);
    String? startTime;
    String? endTime;
    String category = 'General';
    int priority = 2;
    String type = 'task';
    String cleaned = original;
    String? customDescription;

    // 1. Extract custom description if present
    final descMatch = RegExp(
      r'\b(desc|description|note|with note|with description)[:\s]+(.+)$',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (descMatch != null) {
      customDescription = descMatch.group(2)?.trim();
      cleaned = cleaned.substring(0, descMatch.start).trim();
    }

    // 2. Detect Intent / Type
    final isAlarmIntent = lower.contains('alarm') ||
        lower.contains('wake me up') ||
        lower.contains('wake up at') ||
        lower.startsWith('alarm') ||
        lower.contains('as alarm') ||
        lower.contains('set alarm');

    final isHabitIntent = lower.startsWith('habit:') ||
        lower.startsWith('habit ') ||
        lower.contains('as habit') ||
        lower.contains('track habit');

    final isNoteIntent = lower.startsWith('note:') ||
        lower.startsWith('note ') ||
        lower.contains('as note') ||
        lower.contains('take a note') ||
        lower.contains('write a note');

    final isEventIntent = lower.startsWith('event:') ||
        lower.startsWith('event ') ||
        lower.contains('as event') ||
        lower.contains('schedule meeting') ||
        lower.contains('schedule routine');

    if (isAlarmIntent) {
      type = 'alarm';
    } else if (isHabitIntent) {
      type = 'habit';
    } else if (isNoteIntent) {
      type = 'note';
    } else if (isEventIntent) {
      type = 'event';
    } else if (lower.contains('at ') || lower.contains('from ')) {
      // Default to event if specific time range given without alarm keyword
      type = 'event';
    }

    // 3. Detect relative dates
    if (lower.contains('tomorrow')) {
      final tomorrow = now.add(const Duration(days: 1));
      parsedDate = DateFormat('yyyy-MM-dd').format(tomorrow);
      cleaned = cleaned.replaceAll(RegExp(r'\btomorrow\b', caseSensitive: false), '');
    } else if (lower.contains('today')) {
      parsedDate = DateFormat('yyyy-MM-dd').format(now);
      cleaned = cleaned.replaceAll(RegExp(r'\btoday\b', caseSensitive: false), '');
    }

    // 4. Extract time (e.g. "at 3pm", "3:30pm", "15:00", "at 6 am")
    final timeMatch = RegExp(
      r'(?:\bat\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
      caseSensitive: false,
    ).firstMatch(cleaned);

    if (timeMatch != null && timeMatch.group(1) != null) {
      int hour = int.parse(timeMatch.group(1)!);
      int minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final amPm = timeMatch.group(3)?.toLowerCase();

      if (hour <= 24 && minute < 60) {
        if (amPm == 'pm' && hour < 12) hour += 12;
        if (amPm == 'am' && hour == 12) hour = 0;

        startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        int endHour = (hour + 1) % 24;
        endTime = '${endHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

        // Remove the time portion from cleaned title
        cleaned = cleaned.replaceRange(timeMatch.start, timeMatch.end, '');
      }
    }

    // 5. Clean up command keywords from title
    cleaned = cleaned
        .replaceAll(RegExp(r'^(set|create|add)(\s+(an|a))?\s+(alarm|habit|note|event|task)(\s+(for|at|to))?', caseSensitive: false), '')
        .replaceAll(RegExp(r'^(wake\s+me\s+up(\s+(at|for))?|wake\s+up(\s+(at|for))?)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bas\s+(an|a)?\s*(alarm|habit|note|event|task)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(alarm|habit|note|event)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'^(for|at|to|on)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+(for|at|to|on)$', caseSensitive: false), '')
        .replaceAll(RegExp(r'^(habit:|note:|event:|task:)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+', caseSensitive: false), ' ')
        .trim();

    // 6. Detect priority
    if (lower.contains('priority high') || lower.contains('p1') || lower.contains('urgent')) {
      priority = 3;
      cleaned = cleaned.replaceAll(RegExp(r'\b(priority\s+high|p1|urgent)\b', caseSensitive: false), '').trim();
    } else if (lower.contains('priority low') || lower.contains('p3')) {
      priority = 1;
      cleaned = cleaned.replaceAll(RegExp(r'\b(priority\s+low|p3)\b', caseSensitive: false), '').trim();
    }

    // 7. Detect Category
    if (lower.contains('math') || lower.contains('physics') || lower.contains('study') || lower.contains('exam') || lower.contains('dsa') || lower.contains('algorithm')) {
      category = 'Study';
    } else if (lower.contains('work') || lower.contains('meeting') || lower.contains('project') || lower.contains('client') || lower.contains('office')) {
      category = 'Work';
    } else if (lower.contains('gym') || lower.contains('run') || lower.contains('health') || lower.contains('workout') || lower.contains('water') || lower.contains('meditate')) {
      category = 'Health';
    }

    // 8. Capitalize and fallback
    if (cleaned.isEmpty) {
      if (type == 'alarm') {
        cleaned = 'Wake Up Alarm';
      } else if (type == 'habit') {
        cleaned = 'Daily Habit';
      } else if (type == 'note') {
        cleaned = 'Quick Note';
      } else {
        cleaned = original;
      }
    } else {
      // Capitalize first letter
      cleaned = cleaned[0].toUpperCase() + (cleaned.length > 1 ? cleaned.substring(1) : '');
    }

    return ParsedQuickCapture(
      title: cleaned,
      date: parsedDate,
      startTime: startTime,
      endTime: endTime,
      category: category,
      priority: priority,
      type: type,
      description: customDescription,
    );
  }
}
