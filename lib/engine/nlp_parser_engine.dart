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
    final lower = input.toLowerCase().trim();
    final now = DateTime.now();

    String parsedDate = DateFormat('yyyy-MM-dd').format(now);
    String? startTime;
    String? endTime;
    String category = 'General';
    int priority = 2;
    String type = 'task';
    String cleanedTitle = input;
    String? customDescription;

    // Detect type keyword
    if (lower.startsWith('alarm') || lower.contains('set alarm') || lower.contains('alarm at')) {
      type = 'alarm';
      cleanedTitle = input.replaceAll(RegExp(r'^(set\s+)?alarm(\s+at)?\s*', caseSensitive: false), '');
    } else if (lower.startsWith('habit:') || lower.startsWith('habit ')) {
      type = 'habit';
      cleanedTitle = input.replaceFirst(RegExp(r'^habit:?\s*', caseSensitive: false), '');
    } else if (lower.startsWith('note:') || lower.startsWith('note ')) {
      type = 'note';
      cleanedTitle = input.replaceFirst(RegExp(r'^note:?\s*', caseSensitive: false), '');
    } else if (lower.startsWith('event:') || lower.contains('at ') || lower.contains('from ')) {
      type = 'event';
    }

    // Extract custom description if "description" or "note" or "with desc" is included
    final descMatch = RegExp(r'\b(desc|description|note|with note|with description)[:\s]+(.+)$', caseSensitive: false).firstMatch(cleanedTitle);
    if (descMatch != null) {
      customDescription = descMatch.group(2)?.trim();
      cleanedTitle = cleanedTitle.substring(0, descMatch.start).trim();
    }

    // Detect relative dates
    if (lower.contains('tomorrow')) {
      final tomorrow = now.add(const Duration(days: 1));
      parsedDate = DateFormat('yyyy-MM-dd').format(tomorrow);
      cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\btomorrow\b', caseSensitive: false), '');
    } else if (lower.contains('today')) {
      parsedDate = DateFormat('yyyy-MM-dd').format(now);
      cleanedTitle = cleanedTitle.replaceAll(RegExp(r'\btoday\b', caseSensitive: false), '');
    }

    // Detect explicit time regex e.g. "at 4pm", "3:30pm", "16:00"
    final timeMatch = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b', caseSensitive: false).firstMatch(cleanedTitle);
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      int minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final amPm = timeMatch.group(3)?.toLowerCase();

      if (amPm == 'pm' && hour < 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;

      startTime = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      // Default duration 1 hour
      int endHour = (hour + 1) % 24;
      endTime = '${endHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }

    // Detect priority
    if (lower.contains('priority high') || lower.contains('p1') || lower.contains('urgent')) {
      priority = 3;
    } else if (lower.contains('priority low') || lower.contains('p3')) {
      priority = 1;
    }

    // Detect category/subject keywords
    if (lower.contains('math') || lower.contains('physics') || lower.contains('study') || lower.contains('exam')) {
      category = 'Study';
    } else if (lower.contains('work') || lower.contains('meeting') || lower.contains('project')) {
      category = 'Work';
    } else if (lower.contains('gym') || lower.contains('run') || lower.contains('health')) {
      category = 'Health';
    }

    cleanedTitle = cleanedTitle.trim();
    if (cleanedTitle.isEmpty) cleanedTitle = type == 'alarm' ? 'Wake Up Alarm' : input;

    return ParsedQuickCapture(
      title: cleanedTitle,
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

