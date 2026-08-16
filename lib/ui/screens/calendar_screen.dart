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
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();

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
      body: Column(
        children: [
          // TableCalendar in Frosted Glass Container
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              borderRadius: 24,
              child: TableCalendar(
                firstDay: DateTime.utc(2025, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
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
                  ),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(provider.selectedDate),
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
                  onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
                  icon: const Icon(Icons.schedule_send_rounded, size: 16),
                  label: const Text('Reschedule Any'),
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
                            label: const Text('Add Event'),
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

                      final accentColor = isException
                          ? Colors.amber
                          : (isRecurring ? const Color(0xFF0EA5E9) : const Color(0xFF6366F1));

                      return AnimatedEntry(
                        index: index,
                        child: GlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          accentColor: accentColor,
                          child: Row(
                            children: [
                              // Time & Category Pillar
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                                ),
                                child: Icon(
                                  isException
                                      ? Icons.update_rounded
                                      : (isRecurring ? Icons.repeat_rounded : Icons.event_rounded),
                                  color: accentColor,
                                  size: 24,
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
                                    Row(
                                      children: [
                                        Text(
                                          '${slot.startTime} - ${slot.endTime}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '• ${slot.category}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                                          ),
                                        ),
                                        if (isException) ...[
                                          const SizedBox(width: 6),
                                          const Text('(Shifted)', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                                        ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Event'),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final startController = TextEditingController(text: '09:00');
    final endController = TextEditingController(text: '10:00');
    final categoryController = TextEditingController(text: 'General');
    bool isRecurring = false;

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
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1), size: 28),
                        const SizedBox(width: 10),
                        const Text('Add Calendar Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'e.g. System Design Review, Math Session',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category / Tag',
                        hintText: 'e.g. Study, Work, Personal',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;
                          final provider = Provider.of<AppProvider>(context, listen: false);

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
                              date: provider.selectedDateStr,
                              startTime: startController.text.trim(),
                              endTime: endController.text.trim(),
                              category: categoryController.text.trim(),
                            );
                            provider.addEvent(event);
                          }
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save Event'),
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
