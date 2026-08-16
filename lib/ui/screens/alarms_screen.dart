import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../widgets/alarm_ringing_dialog.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/animated_entry.dart';
import '../widgets/universal_reschedule_dialog.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddEditAlarmDialog(BuildContext context, [AlarmItem? alarm]) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    TimeOfDay selectedTime = TimeOfDay.now();
    if (alarm != null) {
      final parts = alarm.time.split(':');
      if (parts.length == 2) {
        selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }

    final titleController = TextEditingController(text: alarm?.title ?? 'Wake Up Alarm');
    final descController = TextEditingController(text: alarm?.description ?? '');
    final List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final Set<String> selectedDays = Set.from(alarm?.repeatDays ?? []);
    String ringtone = alarm?.soundRingtone ?? 'Gentle Chime';
    int snoozeMins = alarm?.snoozeDurationMinutes ?? 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final formattedTimeStr = selectedTime.format(context);

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
                        Icon(Icons.alarm_add_rounded, color: colorScheme.primary, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          alarm == null ? 'New Unique Alarm' : 'Edit Alarm',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Big Time Selector Box
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ALARM TIME',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  formattedTimeStr,
                                  style: theme.textTheme.displayMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.access_time_filled_rounded, size: 36, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Alarm Title / Label',
                        hintText: 'e.g. Morning Wakeup, LeetCode Session',
                        prefixIcon: const Icon(Icons.label_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Unique Description Text Field
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Unique Description / Notes for Alarm',
                        hintText: 'e.g. Wake up! Drink 500ml water, solve 2 DSA problems.',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.description_rounded),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        helperText: 'This description will be displayed when the alarm rings.',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Repeat Days Chips
                    Text(
                      'Repeat Days',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: weekDays.map((day) {
                        final isSel = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSel,
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Ringtone & Snooze
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: provider.availableAlarmTones.contains(ringtone) ? ringtone : provider.availableAlarmTones.first,
                            decoration: InputDecoration(
                              labelText: 'Ringtone',
                              prefixIcon: const Icon(Icons.music_note_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            items: provider.availableAlarmTones.map((tone) {
                              return DropdownMenuItem<String>(
                                value: tone,
                                child: Text(tone, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setModalState(() => ringtone = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: snoozeMins,
                            decoration: InputDecoration(
                              labelText: 'Snooze',
                              prefixIcon: const Icon(Icons.snooze_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 3, child: Text('3 mins')),
                              DropdownMenuItem(value: 5, child: Text('5 mins')),
                              DropdownMenuItem(value: 10, child: Text('10 mins')),
                            ],
                            onChanged: (val) {
                              if (val != null) setModalState(() => snoozeMins = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final h = selectedTime.hour.toString().padLeft(2, '0');
                          final m = selectedTime.minute.toString().padLeft(2, '0');
                          final timeStr = '$h:$m';

                          final nav = Navigator.of(context);
                          final newAlarm = AlarmItem(
                            id: alarm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleController.text.trim().isNotEmpty
                                ? titleController.text.trim()
                                : 'Wake Up Alarm',
                            time: timeStr,
                            description: descController.text.trim(),
                            isEnabled: alarm?.isEnabled ?? true,
                            repeatDays: selectedDays.toList(),
                            soundRingtone: ringtone,
                            snoozeDurationMinutes: snoozeMins,
                          );

                          await provider.addAlarm(newAlarm);
                          nav.pop();
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(alarm == null ? 'Save Alarm' : 'Update Alarm'),
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

  void _showAddHabitDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'Health';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: colorScheme.primary, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'New Daily Habit',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Habit Title',
                      hintText: 'e.g. Drink 2L Water, Morning Run, Solve 2 LeetCode',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Goal Description (optional)',
                      hintText: 'e.g. Morning 10am + Evening 8pm problems',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Health', child: Text('Health & Fitness')),
                      DropdownMenuItem(value: 'Study', child: Text('Study & Learning')),
                      DropdownMenuItem(value: 'Mindset', child: Text('Mindset & Wellness')),
                      DropdownMenuItem(value: 'Work', child: Text('Work & Productivity')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (titleCtrl.text.trim().isNotEmpty) {
                          final nav = Navigator.of(context);
                          final habit = HabitItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            category: category,
                          );
                          await Provider.of<AppProvider>(context, listen: false).addHabit(habit);
                          nav.pop();
                        }
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Habit'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.alarm_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Alarms & Daily Habits'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Reschedule Anything',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.alarm_rounded), text: 'Alarms (${provider.alarms.length})'),
            Tab(icon: const Icon(Icons.bolt_rounded), text: 'Habits (${provider.habits.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Alarms
          provider.alarms.isEmpty
              ? _buildEmptyState(
                  context,
                  icon: Icons.alarm_off_rounded,
                  title: 'No Alarms Set',
                  subtitle: 'Tap the + button to create a wake-up alarm with a unique description.',
                  buttonText: 'Add Alarm',
                  onTap: () => _showAddEditAlarmDialog(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = provider.alarms[index];
                    return AnimatedEntry(
                      index: index,
                      child: _buildAlarmCard(context, alarm, provider),
                    );
                  },
                ),

          // Tab 2: Daily Habits
          provider.habits.isEmpty
              ? _buildEmptyState(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  title: 'No Habits Tracked',
                  subtitle: 'Start building positive daily routines and track your streaks.',
                  buttonText: 'Add Habit',
                  onTap: () => _showAddHabitDialog(context),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.habits.length,
                  itemBuilder: (context, index) {
                    final habit = provider.habits[index];
                    return AnimatedEntry(
                      index: index,
                      child: _buildHabitCard(context, habit, provider),
                    );
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddEditAlarmDialog(context);
          } else {
            _showAddHabitDialog(context);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_tabController.index == 0 ? 'Add Alarm' : 'Add Habit'),
      ),
    );
  }

  Widget _buildAlarmCard(BuildContext context, AlarmItem alarm, AppProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      accentColor: alarm.isEnabled ? colorScheme.primary : Colors.grey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Time, Title, Switch Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.time,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: alarm.isEnabled
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? Colors.white38 : Colors.grey),
                    ),
                  ),
                  Text(
                    alarm.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: alarm.isEnabled ? colorScheme.primary : Colors.grey,
                    ),
                  ),
                ],
              ),
              Switch(
                value: alarm.isEnabled,
                onChanged: (_) {
                  provider.toggleAlarmStatus(alarm);
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Prominent Unique Description Container
          if (alarm.description.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 16, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alarm.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Repeat Days & Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Repeat Days Chips
              if (alarm.repeatDays.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: alarm.repeatDays.map((d) {
                    return GlassPillBadge(
                      label: d,
                      color: colorScheme.secondary,
                    );
                  }).toList(),
                )
              else
                Text(
                  'One-time Alarm',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                ),

              // Action Buttons
              Row(
                children: [
                  // Quick Reschedule / Delay Button
                  IconButton(
                    icon: const Icon(Icons.schedule_send_rounded, color: Color(0xFF6366F1)),
                    tooltip: 'Reschedule / Delay Alarm',
                    onPressed: () {
                      UniversalRescheduleDialog.showForAlarm(context, alarm);
                    },
                  ),
                  // Test Ring Button
                  IconButton(
                    icon: const Icon(Icons.notifications_active_rounded, color: Colors.orangeAccent),
                    tooltip: 'Test Ring Alarm',
                    onPressed: () {
                      AlarmRingingDialog.show(context, alarm);
                    },
                  ),
                  // Edit Button
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Edit Alarm',
                    onPressed: () => _showAddEditAlarmDialog(context, alarm),
                  ),
                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: 'Delete Alarm',
                    onPressed: () => provider.deleteAlarm(alarm.id),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(BuildContext context, HabitItem habit, AppProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDoneToday = habit.lastCompletedDate == provider.selectedDateStr;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: IconButton(
          icon: Icon(
            isDoneToday ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: isDoneToday ? Colors.green : colorScheme.outline,
            size: 32,
          ),
          onPressed: () => provider.toggleHabitCompletion(habit),
        ),
        title: Text(
          habit.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            decoration: isDoneToday ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: habit.description != null && habit.description!.isNotEmpty
            ? Text(habit.description!)
            : Text('Category: ${habit.category}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('🔥 ', style: TextStyle(fontSize: 14)),
                  Text(
                    '${habit.streak}d',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => provider.deleteHabit(habit.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GlassButton(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded),
              label: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
