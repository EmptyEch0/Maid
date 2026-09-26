import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../models/app_models.dart';
import '../../engine/scheduling_engine.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/animated_entry.dart';
import '../widgets/universal_reschedule_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  static Color parseEventColor(String? colorHex, String category) {
    if (colorHex != null && colorHex.isNotEmpty) {
      try {
        final hex = colorHex.replaceFirst('#', '');
        if (hex.length == 6) {
          return Color(int.parse('0xFF$hex'));
        } else if (hex.length == 8) {
          return Color(int.parse('0x$hex'));
        }
      } catch (_) {}
    }
    switch (category.toLowerCase()) {
      case 'study':
        return const Color(0xFF6366F1); // Indigo
      case 'work':
        return const Color(0xFF0EA5E9); // Sky
      case 'health':
        return const Color(0xFF10B981); // Emerald
      case 'exam':
        return const Color(0xFFEF4444); // Red
      case 'meeting':
        return const Color(0xFFF59E0B); // Amber
      case 'personal':
        return const Color(0xFFEC4899); // Pink
      case 'routine':
        return const Color(0xFF8B5CF6); // Purple
      default:
        return const Color(0xFF6366F1);
    }
  }

  static String getReminderLabel(int minutes) {
    if (minutes < 0) return 'No reminder';
    if (minutes == 0) return 'At event start';
    if (minutes == 15) return '15m before';
    if (minutes == 30) return '30m before';
    if (minutes == 60) return '1h before';
    if (minutes == 1440) return '1 day before';
    if (minutes == 2880) return '2 days before';
    final hours = minutes ~/ 60;
    return '${hours}h before';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final selectedDateStr = provider.selectedDateStr;
    final resolvedSchedule = provider.getResolvedSchedule(selectedDateStr);
    final conflicts = SchedulingEngine.detectConflicts(resolvedSchedule);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Smart Calendar'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Universal Rescheduler',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Go to Today',
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
              });
              provider.setSelectedDate(DateTime.now());
            },
          ),
        ],
      ),
      body: GlassBackground(
        child: Column(
          children: [
            // TableCalendar in Frosted Glass Container with Colored Event Markers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                borderRadius: 24,
                child: TableCalendar<CalendarEvent>(
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  eventLoader: (day) => provider.getEventsForDay(day),
                  selectedDayPredicate: (day) => isSameDay(provider.selectedDate, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                    provider.setSelectedDate(selectedDay);
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    formatButtonShowsNext: false,
                    titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  calendarStyle: CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    todayDecoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.primary, width: 1.5),
                    ),
                    markerSize: 7,
                    markersMaxCount: 4,
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return null;
                      return Positioned(
                        bottom: 2,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: events.take(4).map((event) {
                            final color = parseEventColor(event.colorHex, event.category);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.5),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.8),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Conflict Banner
            if (conflicts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${conflicts.length} time conflict(s) detected today! Tap Reschedule to fix.',
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Schedule Timeline Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('EEE, MMM d, yyyy').format(provider.selectedDate),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      GlassPillBadge(
                        label: '${resolvedSchedule.length} Slots',
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddEventDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Event'),
                  ),
                ],
              ),
            ),

            // Schedule List
            Expanded(
              child: resolvedSchedule.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No events scheduled for this day.',
                              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 16),
                            GlassButton(
                              onPressed: () => _showAddEventDialog(context),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Special Event'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: resolvedSchedule.length,
                      itemBuilder: (context, index) {
                        final slot = resolvedSchedule[index];
                        final isException = slot.isException;
                        final isRecurring = slot.isRecurringInstance;

                        final Color eventColor = isException
                            ? Colors.amber
                            : (isRecurring
                                ? const Color(0xFF0EA5E9)
                                : parseEventColor(slot.colorHex, slot.category));

                        return AnimatedEntry(
                          index: index,
                          child: GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            accentColor: eventColor,
                            child: Row(
                              children: [
                                // Time & Category Pillar
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: eventColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: eventColor.withValues(alpha: 0.4), width: 1.5),
                                  ),
                                  child: Icon(
                                    isException
                                        ? Icons.update_rounded
                                        : (isRecurring ? Icons.repeat_rounded : Icons.event_rounded),
                                    color: eventColor,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Content Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        slot.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: eventColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${slot.startTime} - ${slot.endTime}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: eventColor,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '• ${slot.category}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                                            ),
                                          ),
                                          if (slot.reminderMinutesBefore >= 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 0.8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.notifications_active_rounded, size: 10, color: Colors.amber),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    getReminderLabel(slot.reminderMinutesBefore),
                                                    style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (isException)
                                            const Text('(Shifted)', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Quick Reschedule Button
                                IconButton(
                                  icon: const Icon(Icons.schedule_send_rounded, color: Color(0xFF6366F1)),
                                  tooltip: 'Reschedule This Event',
                                  onPressed: () {
                                    UniversalRescheduleDialog.showForSlot(context, slot);
                                  },
                                ),

                                // Popup More Menu
                                PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'reschedule') {
                                      UniversalRescheduleDialog.showForSlot(context, slot);
                                    } else if (val == 'delete' && !slot.isRecurringInstance) {
                                      provider.deleteEvent(slot.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'reschedule',
                                      child: Row(
                                        children: [
                                          Icon(Icons.schedule_send_rounded, size: 18, color: Color(0xFF6366F1)),
                                          SizedBox(width: 8),
                                          Text('Reschedule / Postpone'),
                                        ],
                                      ),
                                    ),
                                    if (!slot.isRecurringInstance)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                            SizedBox(width: 8),
                                            Text('Delete Event', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event'),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final titleController = TextEditingController();
    final startController = TextEditingController(text: '09:00');
    final endController = TextEditingController(text: '10:00');
    final categoryController = TextEditingController(text: 'General');
    final notesController = TextEditingController();

    DateTime selectedEventDate = provider.selectedDate;
    bool isRecurring = false;
    String selectedColorHex = '#6366F1';
    int selectedReminderMinutes = 1440; // Default: 1 day before as requested by user

    final List<Map<String, dynamic>> colorPalette = [
      {'name': 'Indigo', 'hex': '#6366F1', 'color': const Color(0xFF6366F1)},
      {'name': 'Rose', 'hex': '#EC4899', 'color': const Color(0xFFEC4899)},
      {'name': 'Emerald', 'hex': '#10B981', 'color': const Color(0xFF10B981)},
      {'name': 'Amber Gold', 'hex': '#F59E0B', 'color': const Color(0xFFF59E0B)},
      {'name': 'Purple', 'hex': '#8B5CF6', 'color': const Color(0xFF8B5CF6)},
      {'name': 'Cyan Sky', 'hex': '#06B6D4', 'color': const Color(0xFF06B6D4)},
      {'name': 'Crimson', 'hex': '#EF4444', 'color': const Color(0xFFEF4444)},
      {'name': 'Orange Fire', 'hex': '#F97316', 'color': const Color(0xFFF97316)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final theme = Theme.of(context);
            final dateStr = DateFormat('EEE, MMM d, yyyy').format(selectedEventDate);

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1), size: 28),
                        const SizedBox(width: 10),
                        const Text('Add Special Calendar Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date Picker Box
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedEventDate,
                          firstDate: DateTime(2025, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (picked != null) {
                          setDlgState(() {
                            selectedEventDate = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('EVENT DATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.edit_calendar_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'e.g. System Design Review, Oct 3rd Presentation',
                        prefixIcon: const Icon(Icons.title_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Time Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startController,
                            decoration: InputDecoration(
                              labelText: 'Start Time (HH:mm)',
                              prefixIcon: const Icon(Icons.access_time_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: endController,
                            decoration: InputDecoration(
                              labelText: 'End Time (HH:mm)',
                              prefixIcon: const Icon(Icons.timer_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Category & Color Header
                    Text(
                      'Event Color Theme (Special Highlight in Calendar)',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Color Palette Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: colorPalette.map((p) {
                        final isSel = selectedColorHex == p['hex'];
                        final Color c = p['color'];
                        return GestureDetector(
                          onTap: () {
                            setDlgState(() {
                              selectedColorHex = p['hex'];
                            });
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSel ? Colors.white : Colors.transparent,
                                width: isSel ? 3 : 1,
                              ),
                              boxShadow: [
                                if (isSel)
                                  BoxShadow(
                                    color: c.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child: isSel ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Category
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category / Tag',
                        hintText: 'e.g. Study, Work, Exam, Meeting, Personal',
                        prefixIcon: const Icon(Icons.label_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Reminder Before Selection Dropdown
                    DropdownButtonFormField<int>(
                      initialValue: selectedReminderMinutes,
                      decoration: InputDecoration(
                        labelText: '🔔 Remind me before date/time',
                        prefixIcon: const Icon(Icons.notification_add_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1440, child: Text('📅 1 day before (Day before alert)')),
                        DropdownMenuItem(value: 2880, child: Text('📅 2 days before')),
                        DropdownMenuItem(value: 60, child: Text('⏰ 1 hour before')),
                        DropdownMenuItem(value: 30, child: Text('⏰ 30 minutes before')),
                        DropdownMenuItem(value: 15, child: Text('⏰ 15 minutes before')),
                        DropdownMenuItem(value: 0, child: Text('🎯 At event start time')),
                        DropdownMenuItem(value: -1, child: Text('🔕 No reminder')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedReminderMinutes = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    CheckboxListTile(
                      title: const Text('Repeat weekly on this day'),
                      value: isRecurring,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onChanged: (val) {
                        setDlgState(() {
                          isRecurring = val ?? false;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          final formattedDate =
                              '${selectedEventDate.year}-${selectedEventDate.month.toString().padLeft(2, '0')}-${selectedEventDate.day.toString().padLeft(2, '0')}';

                          if (isRecurring) {
                            final rule = RecurrenceRule(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              title: title,
                              daysOfWeek: 'MON,TUE,WED,THU,FRI,SAT,SUN',
                              startTime: startController.text.trim(),
                              endTime: endController.text.trim(),
                              category: categoryController.text.trim(),
                            );
                            provider.addRecurrenceRule(rule);
                          } else {
                            final event = CalendarEvent(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              title: title,
                              date: formattedDate,
                              startTime: startController.text.trim(),
                              endTime: endController.text.trim(),
                              category: categoryController.text.trim(),
                              colorHex: selectedColorHex,
                              reminderMinutesBefore: selectedReminderMinutes,
                              notes: notesController.text.trim(),
                            );
                            provider.addEvent(event);
                          }
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save Event & Schedule Reminder'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

