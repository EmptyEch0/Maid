import 'package:flutter_test/flutter_test.dart';
import 'package:maid/models/app_models.dart';
import 'package:maid/engine/scheduling_engine.dart';
import 'package:maid/engine/nlp_parser_engine.dart';
import 'package:maid/engine/weekly_review_engine.dart';
import 'package:maid/engine/dsa_plan_seeder.dart';

void main() {
  group('1. Universal Rescheduling & Scheduling Engine Tests', () {
    test('Detects schedule overlap conflict accurately', () {
      final slot1 = ScheduledSlot(
        id: '1',
        title: 'Morning DSA Session',
        date: '2026-08-17',
        startTime: '10:00',
        endTime: '11:30',
        category: 'Study',
      );

      final slot2 = ScheduledSlot(
        id: '2',
        title: 'Team Meeting',
        date: '2026-08-17',
        startTime: '11:00',
        endTime: '12:00',
        category: 'Work',
      );

      final conflicts = SchedulingEngine.detectConflicts([slot1, slot2]);
      expect(conflicts.length, 1);
      expect(conflicts.first.contains('Morning DSA Session'), true);
      expect(conflicts.first.contains('Team Meeting'), true);
    });

    test('Identifies conflict-free candidate slots when rescheduling', () {
      final event1 = CalendarEvent(
        id: 'e1',
        title: 'Busy Slot',
        date: '2026-08-17',
        startTime: '09:00',
        endTime: '10:00',
        category: 'Work',
      );

      final candidates = SchedulingEngine.findCandidateSlots(
        fromDate: DateTime(2026, 8, 17),
        durationMinutes: 60,
        oneOffEvents: [event1],
        recurrenceRules: [],
        exceptions: [],
      );

      expect(candidates.isNotEmpty, true);
      // Ensure candidate doesn't clash with 09:00 - 10:00 on 2026-08-17
      for (final c in candidates) {
        if (c.date == '2026-08-17') {
          final isOverlapping = (c.startTime == '09:00');
          expect(isOverlapping, false);
        }
      }
    });

    test('Schedule exception correctly shifts recurring slot (Postpone)', () {
      final rule = RecurrenceRule(
        id: 'rec_leetcode',
        title: 'LeetCode Practice',
        daysOfWeek: 'MON,TUE,WED,THU,FRI,SAT,SUN',
        startTime: '10:00',
        endTime: '11:00',
        category: 'Study',
      );

      // Exception shifting 2026-08-17 from 10:00 to 14:00
      final exception = ScheduleException(
        id: 'exc_1',
        recurrenceRuleId: 'rec_leetcode',
        originalDate: '2026-08-17',
        newDate: '2026-08-17',
        newStartTime: '14:00',
        newEndTime: '15:00',
        reason: 'Shifted via Universal Rescheduler',
      );

      final slots = SchedulingEngine.resolveScheduleForDate(
        targetDate: '2026-08-17',
        oneOffEvents: [],
        recurrenceRules: [rule],
        exceptions: [exception],
      );

      expect(slots.length, 1);
      expect(slots.first.startTime, '14:00');
      expect(slots.first.endTime, '15:00');
      expect(slots.first.isException, true);
    });
  });

  group('2. Natural Language Processing (NLP) Quick Capture Tests', () {
    test('Parses alarm query with unique description', () {
      final result = NlpParserEngine.parseText('Set alarm at 7:00 AM description Drink water and run 5k');
      expect(result.type, 'alarm');
      expect(result.startTime, '07:00');
      expect(result.description, 'Drink water and run 5k');
    });

    test('Parses study task with tomorrow relative date and priority', () {
      final result = NlpParserEngine.parseText('Math study tomorrow at 4pm priority high');
      expect(result.type, 'event');
      expect(result.startTime, '16:00');
      expect(result.priority, 3);
      expect(result.category, 'Study');
    });

    test('Parses habit creation with streak goal', () {
      final result = NlpParserEngine.parseText('Habit: Daily LeetCode 2 Problems');
      expect(result.type, 'habit');
      expect(result.title.contains('Daily LeetCode'), true);
    });
  });

  group('3. 90-Day DSA Preparation Plan Seeder Tests', () {
    test('Generates exactly 90 weekdays across 18 weeks', () {
      final plans = DsaPlanSeeder.generate90DayPlan();
      expect(plans.length, 90);
      expect(plans.first.dayNumber, 1);
      expect(plans.last.dayNumber, 90);
      expect(plans.first.weekNumber, 1);
      expect(plans.last.weekNumber, 18);
    });

    test('All generated dates are Monday through Friday (No weekends)', () {
      final plans = DsaPlanSeeder.generate90DayPlan();
      for (final p in plans) {
        final parsed = DateTime.parse(p.date);
        expect(parsed.weekday >= DateTime.monday && parsed.weekday <= DateTime.friday, true);
      }
    });
  });

  group('4. Weekly Review & Analytics Engine Tests', () {
    test('Calculates execution ratio and rating accurately', () {
      final sessions = <StudySession>[
        StudySession(
          id: 's1',
          subject: 'Mathematics',
          plannedMinutes: 60,
          actualMinutes: 60,
          startTs: '2026-08-17T10:00:00',
          endTs: '2026-08-17T11:00:00',
        ),
        StudySession(
          id: 's2',
          subject: 'Programming',
          plannedMinutes: 60,
          actualMinutes: 50,
          startTs: '2026-08-18T10:00:00',
          endTs: '2026-08-18T10:50:00',
        ),
      ];

      final tasks = <TaskItem>[
        TaskItem(id: 't1', title: 'Task 1', status: 'completed'),
        TaskItem(id: 't2', title: 'Task 2', status: 'todo'),
      ];

      final report = WeeklyReviewEngine.generateReport(
        studySessions: sessions,
        tasks: tasks,
        exceptions: [],
      );

      expect(report.totalPlannedMinutes, 120);
      expect(report.totalActualMinutes, 110);
      expect(report.totalTasksCompleted, 1);
      expect(report.totalTasksPending, 1);
      expect(report.executionRatio, closeTo(110 / 120, 0.01));
      expect(report.summaryRating.contains('Excellent') || report.summaryRating.contains('Good'), true);
    });
  });

  group('5. Data Models & JSON Mapping Tests', () {
    test('AlarmItem serialization preserves all fields', () {
      final alarm = AlarmItem(
        id: 'alarm_101',
        title: 'Morning Workout',
        time: '06:30',
        description: 'Take pre-workout, pack gym bag',
        isEnabled: true,
        repeatDays: ['Mon', 'Wed', 'Fri'],
        soundRingtone: 'Energetic Pulse',
        snoozeDurationMinutes: 10,
      );

      final map = alarm.toMap();
      final reconstructed = AlarmItem.fromMap(map);

      expect(reconstructed.id, 'alarm_101');
      expect(reconstructed.title, 'Morning Workout');
      expect(reconstructed.time, '06:30');
      expect(reconstructed.description, 'Take pre-workout, pack gym bag');
      expect(reconstructed.repeatDays, ['Mon', 'Wed', 'Fri']);
      expect(reconstructed.soundRingtone, 'Energetic Pulse');
      expect(reconstructed.snoozeDurationMinutes, 10);
    });

    test('CalendarEvent copyWith works properly for universal rescheduling', () {
      final event = CalendarEvent(
        id: 'evt_1',
        title: 'Project Presentation',
        date: '2026-08-17',
        startTime: '10:00',
        endTime: '11:00',
        category: 'Work',
      );

      final rescheduled = event.copyWith(
        date: '2026-08-18',
        startTime: '14:00',
        endTime: '15:00',
      );

      expect(rescheduled.id, 'evt_1');
      expect(rescheduled.date, '2026-08-18');
      expect(rescheduled.startTime, '14:00');
      expect(rescheduled.endTime, '15:00');
    });
  });
}
