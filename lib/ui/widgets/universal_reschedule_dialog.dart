import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../engine/scheduling_engine.dart';
import 'glass_widgets.dart';

enum RescheduleTargetType {
  task,
  alarm,
  calendarEvent,
  scheduledSlot,
  note,
  dsaPlan,
}

class UniversalRescheduleDialog extends StatefulWidget {
  final RescheduleTargetType type;
  final String title;
  final String? currentSubtitle;
  final String itemId;
  
  // Specific data objects
  final TaskItem? task;
  final AlarmItem? alarm;
  final ScheduledSlot? slot;
  final CalendarEvent? event;
  final NoteItem? note;

  const UniversalRescheduleDialog({
    super.key,
    required this.type,
    required this.title,
    this.currentSubtitle,
    required this.itemId,
    this.task,
    this.alarm,
    this.slot,
    this.event,
    this.note,
  });

  static Future<void> showForTask(BuildContext context, TaskItem task) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UniversalRescheduleDialog(
        type: RescheduleTargetType.task,
        title: task.title,
        currentSubtitle: 'Due: ${task.dueDate ?? "No due date"}',
        itemId: task.id,
        task: task,
      ),
    );
  }

  static Future<void> showForAlarm(BuildContext context, AlarmItem alarm) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UniversalRescheduleDialog(
        type: RescheduleTargetType.alarm,
        title: alarm.title.isNotEmpty ? alarm.title : 'Alarm',
        currentSubtitle: 'Current Time: ${alarm.time}',
        itemId: alarm.id,
        alarm: alarm,
      ),
    );
  }

  static Future<void> showForSlot(BuildContext context, ScheduledSlot slot) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UniversalRescheduleDialog(
        type: RescheduleTargetType.scheduledSlot,
        title: slot.title,
        currentSubtitle: '${slot.date} • ${slot.startTime} - ${slot.endTime}',
        itemId: slot.id,
        slot: slot,
      ),
    );
  }

  static Future<void> showForEvent(BuildContext context, CalendarEvent event) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UniversalRescheduleDialog(
        type: RescheduleTargetType.calendarEvent,
        title: event.title,
        currentSubtitle: '${event.date} • ${event.startTime} - ${event.endTime}',
        itemId: event.id,
        event: event,
      ),
    );
  }

  static Future<void> showForNote(BuildContext context, NoteItem note) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UniversalRescheduleDialog(
        type: RescheduleTargetType.note,
        title: note.displayTitle,
        currentSubtitle: note.date != null ? 'Scheduled: ${note.date} ${note.startTime ?? ""}' : 'No schedule',
        itemId: note.id,
        note: note,
      ),
    );
  }

  /// Global picker to pick ANY existing task, alarm, event, or note to reschedule
  static void showUniversalPicker(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_send_rounded, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Text('Reschedule Anything', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('Select any item to reschedule to a new optimal slot:'),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (provider.tasks.isNotEmpty) ...[
                      const Text('TASKS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      ...provider.tasks.take(5).map((t) => ListTile(
                        leading: const Icon(Icons.task_alt_rounded, color: Colors.indigo),
                        title: Text(t.title),
                        subtitle: Text('Due: ${t.dueDate ?? "No due date"}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(ctx);
                          showForTask(context, t);
                        },
                      )),
                      const SizedBox(height: 12),
                    ],
                    if (provider.alarms.isNotEmpty) ...[
                      const Text('ALARMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      ...provider.alarms.take(5).map((a) => ListTile(
                        leading: const Icon(Icons.alarm_rounded, color: Colors.orange),
                        title: Text(a.title.isNotEmpty ? a.title : 'Alarm'),
                        subtitle: Text('Time: ${a.time}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(ctx);
                          showForAlarm(context, a);
                        },
                      )),
                      const SizedBox(height: 12),
                    ],
                    if (provider.events.isNotEmpty) ...[
                      const Text('CALENDAR EVENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      ...provider.events.take(5).map((e) => ListTile(
                        leading: const Icon(Icons.event_rounded, color: Colors.blue),
                        title: Text(e.title),
                        subtitle: Text('${e.date} • ${e.startTime} - ${e.endTime}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(ctx);
                          showForEvent(context, e);
                        },
                      )),
                      const SizedBox(height: 12),
                    ],
                    if (provider.notes.isNotEmpty) ...[
                      const Text('NOTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      ...provider.notes.take(5).map((n) => ListTile(
                        leading: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFF6366F1)),
                        title: Text(n.displayTitle),
                        subtitle: Text(n.body.isNotEmpty ? n.body : '(Empty content)', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(ctx);
                          showForNote(context, n);
                        },
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  State<UniversalRescheduleDialog> createState() => _UniversalRescheduleDialogState();
}

class _UniversalRescheduleDialogState extends State<UniversalRescheduleDialog> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _selectedEndTime = const TimeOfDay(hour: 10, minute: 0);
  String? _conflictWarning;
  List<CandidateSlot> _candidateSlots = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now.add(const Duration(days: 1)); // Default tomorrow

    if (widget.alarm != null) {
      final parts = widget.alarm!.time.split(':');
      if (parts.length == 2) {
        _selectedStartTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 7, minute: int.tryParse(parts[1]) ?? 0);
      }
    } else if (widget.slot != null) {
      final parts = widget.slot!.startTime.split(':');
      if (parts.length == 2) {
        _selectedStartTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
      }
      final endParts = widget.slot!.endTime.split(':');
      if (endParts.length == 2) {
        _selectedEndTime = TimeOfDay(hour: int.tryParse(endParts[0]) ?? 10, minute: int.tryParse(endParts[1]) ?? 0);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _computeCandidateSlots();
      _checkConflict();
    });
  }

  void _computeCandidateSlots() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    _candidateSlots = provider.getPostponeCandidates(_selectedDate, 60);
    setState(() {});
  }

  void _checkConflict() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final resolved = provider.getResolvedSchedule(dateStr);

    final startMin = _selectedStartTime.hour * 60 + _selectedStartTime.minute;
    final endMin = _selectedEndTime.hour * 60 + _selectedEndTime.minute;

    bool hasConflict = false;
    String conflictName = '';

    for (final s in resolved) {
      if (s.id == widget.itemId) continue;
      final p1 = s.startTime.split(':');
      final p2 = s.endTime.split(':');
      if (p1.length == 2 && p2.length == 2) {
        final sMin = int.parse(p1[0]) * 60 + int.parse(p1[1]);
        final eMin = int.parse(p2[0]) * 60 + int.parse(p2[1]);
        if (startMin < eMin && sMin < endMin) {
          hasConflict = true;
          conflictName = s.title;
          break;
        }
      }
    }

    setState(() {
      _conflictWarning = hasConflict ? 'Conflicts with "$conflictName" ($dateStr)' : null;
    });
  }

  void _applyQuickPreset(Duration offset, int hour, int minute, [int durationHours = 1]) {
    final target = DateTime.now().add(offset);
    setState(() {
      _selectedDate = target;
      _selectedStartTime = TimeOfDay(hour: hour, minute: minute);
      _selectedEndTime = TimeOfDay(hour: (hour + durationHours) % 24, minute: minute);
    });
    _checkConflict();
  }

  void _applyAlarmQuickDelay(int minutes) {
    final now = DateTime.now().add(Duration(minutes: minutes));
    setState(() {
      _selectedDate = now;
      _selectedStartTime = TimeOfDay(hour: now.hour, minute: now.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dateFormatted = DateFormat('EEEE, MMM d, yyyy').format(_selectedDate);
    final startFormatted = _selectedStartTime.format(context);
    final endFormatted = _selectedEndTime.format(context);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 25,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.schedule_send_rounded, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GlassPillBadge(
                            label: widget.type.name.toUpperCase(),
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reschedule',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.currentSubtitle != null)
                        Text(
                          widget.currentSubtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Quick Reschedule Presets Section
            Text(
              'Quick Reschedule Presets',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),

            if (widget.type == RescheduleTargetType.alarm) ...[
              // Alarm Presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.snooze_rounded, size: 16),
                    label: const Text('+15 Mins'),
                    onPressed: () => _applyAlarmQuickDelay(15),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.snooze_rounded, size: 16),
                    label: const Text('+30 Mins'),
                    onPressed: () => _applyAlarmQuickDelay(30),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.snooze_rounded, size: 16),
                    label: const Text('+1 Hour'),
                    onPressed: () => _applyAlarmQuickDelay(60),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wb_sunny_rounded, size: 16),
                    label: const Text('Tomorrow 7:00 AM'),
                    onPressed: () => _applyQuickPreset(const Duration(days: 1), 7, 0),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.access_time_rounded, size: 16),
                    label: const Text('Tomorrow 10:00 AM (LeetCode)'),
                    onPressed: () => _applyQuickPreset(const Duration(days: 1), 10, 0),
                  ),
                ],
              ),
            ] else ...[
              // Task / Event / Note Presets
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                    label: const Text('Tomorrow Morning (9:00 AM)'),
                    onPressed: () => _applyQuickPreset(const Duration(days: 1), 9, 0),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.wb_twilight_rounded, size: 16),
                    label: const Text('Tomorrow Afternoon (2:00 PM)'),
                    onPressed: () => _applyQuickPreset(const Duration(days: 1), 14, 0),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.nightlight_round, size: 16),
                    label: const Text('Tomorrow Evening (8:00 PM)'),
                    onPressed: () => _applyQuickPreset(const Duration(days: 1), 20, 0),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.weekend_rounded, size: 16),
                    label: const Text('This Weekend'),
                    onPressed: () {
                      final now = DateTime.now();
                      final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
                      _applyQuickPreset(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat), 10, 0);
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.next_plan_rounded, size: 16),
                    label: const Text('Next Monday'),
                    onPressed: () {
                      final now = DateTime.now();
                      final daysUntilMon = (DateTime.monday - now.weekday + 7) % 7;
                      _applyQuickPreset(Duration(days: daysUntilMon == 0 ? 7 : daysUntilMon), 9, 0);
                    },
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            // Smart Best Slots (from Scheduling Engine)
            if (_candidateSlots.isNotEmpty && widget.type != RescheduleTargetType.alarm) ...[
              Text(
                'Maid Smart Conflict-Free Suggestions',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _candidateSlots.take(3).length,
                  itemBuilder: (context, idx) {
                    final c = _candidateSlots[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.green),
                        label: Text(c.label),
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        onPressed: () {
                          final parsedDate = DateTime.tryParse(c.date) ?? DateTime.now();
                          final sParts = c.startTime.split(':');
                          final eParts = c.endTime.split(':');
                          setState(() {
                            _selectedDate = parsedDate;
                            if (sParts.length == 2) {
                              _selectedStartTime = TimeOfDay(hour: int.parse(sParts[0]), minute: int.parse(sParts[1]));
                            }
                            if (eParts.length == 2) {
                              _selectedEndTime = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
                            }
                          });
                          _checkConflict();
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Target Date & Time Card Selector
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Date Picker Row
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _computeCandidateSlots();
                        _checkConflict();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TARGET DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                Text(dateFormatted, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_calendar_rounded, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 16),

                  // Time Picker Row
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _selectedStartTime,
                            );
                            if (picked != null) {
                              setState(() => _selectedStartTime = picked);
                              _checkConflict();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.type == RescheduleTargetType.alarm ? 'ALARM TIME' : 'START TIME',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                                    ),
                                    Text(startFormatted, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.type != RescheduleTargetType.alarm) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _selectedEndTime,
                              );
                              if (picked != null) {
                                setState(() => _selectedEndTime = picked);
                                _checkConflict();
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.timer_outlined, color: colorScheme.secondary),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('END TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      Text(endFormatted, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Conflict Warning Alert
            if (_conflictWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _conflictWarning!,
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Confirm Reschedule Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 3,
                ),
                onPressed: _performReschedule,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Confirm Reschedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performReschedule() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final startH = _selectedStartTime.hour.toString().padLeft(2, '0');
    final startM = _selectedStartTime.minute.toString().padLeft(2, '0');
    final startTimeStr = '$startH:$startM';

    final endH = _selectedEndTime.hour.toString().padLeft(2, '0');
    final endM = _selectedEndTime.minute.toString().padLeft(2, '0');
    final endTimeStr = '$endH:$endM';

    if (widget.type == RescheduleTargetType.task && widget.task != null) {
      await provider.rescheduleTask(widget.task!.id, dateStr, startTimeStr);
      messenger.showSnackBar(
        SnackBar(content: Text('Rescheduled task "${widget.title}" to $dateStr')),
      );
    } else if (widget.type == RescheduleTargetType.alarm && widget.alarm != null) {
      await provider.rescheduleAlarm(widget.alarm!.id, startTimeStr);
      messenger.showSnackBar(
        SnackBar(content: Text('Rescheduled alarm "${widget.title}" to $startTimeStr')),
      );
    } else if (widget.type == RescheduleTargetType.scheduledSlot && widget.slot != null) {
      if (widget.slot!.recurrenceRuleId != null) {
        await provider.postponeEvent(
          recurrenceRuleId: widget.slot!.recurrenceRuleId!,
          originalDate: widget.slot!.date,
          newDate: dateStr,
          newStartTime: startTimeStr,
          newEndTime: endTimeStr,
          reason: 'Universal Rescheduler',
        );
      } else {
        await provider.rescheduleEvent(widget.slot!.id, dateStr, startTimeStr, endTimeStr);
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Rescheduled "${widget.title}" to $dateStr ($startTimeStr - $endTimeStr)')),
      );
    } else if (widget.type == RescheduleTargetType.calendarEvent && widget.event != null) {
      await provider.rescheduleEvent(widget.event!.id, dateStr, startTimeStr, endTimeStr);
      messenger.showSnackBar(
        SnackBar(content: Text('Rescheduled event "${widget.title}" to $dateStr')),
      );
    } else if (widget.type == RescheduleTargetType.note && widget.note != null) {
      await provider.rescheduleNote(widget.note!.id, dateStr, startTimeStr);
      messenger.showSnackBar(
        SnackBar(content: Text('Rescheduled note "${widget.title}" to $dateStr')),
      );
    }

    nav.pop();
  }
}
