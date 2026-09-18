import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../services/alarm_sound_service.dart';
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

  /// Calculates the time left until the alarm rings
  static String calculateTimeRemaining(String alarmTime, List<String> repeatDays, {bool isEnabled = true}) {
    if (!isEnabled) return 'Alarm is off';

    final parts = alarmTime.split(':');
    if (parts.length != 2) return '';
    final alarmHour = int.tryParse(parts[0]) ?? 0;
    final alarmMinute = int.tryParse(parts[1]) ?? 0;

    final now = DateTime.now();

    // If no repeat days, it's a one-time alarm for today or tomorrow
    if (repeatDays.isEmpty) {
      var target = DateTime(now.year, now.month, now.day, alarmHour, alarmMinute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      return _formatDuration(target.difference(now));
    }

    // Repeat days: 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    const dayMap = {
      'Mon': DateTime.monday,
      'Tue': DateTime.tuesday,
      'Wed': DateTime.wednesday,
      'Thu': DateTime.thursday,
      'Fri': DateTime.friday,
      'Sat': DateTime.saturday,
      'Sun': DateTime.sunday,
    };

    DateTime? closestTarget;
    for (int i = 0; i < 8; i++) {
      final checkDate = now.add(Duration(days: i));
      final checkTarget = DateTime(checkDate.year, checkDate.month, checkDate.day, alarmHour, alarmMinute);
      if (checkTarget.isBefore(now)) continue;

      final weekdayName = dayMap.entries
          .firstWhere((e) => e.value == checkDate.weekday, orElse: () => const MapEntry('', 0))
          .key;
      if (repeatDays.contains(weekdayName)) {
        closestTarget = checkTarget;
        break;
      }
    }

    if (closestTarget == null) {
      var target = DateTime(now.year, now.month, now.day, alarmHour, alarmMinute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      return _formatDuration(target.difference(now));
    }

    return _formatDuration(closestTarget.difference(now));
  }

  static String _formatDuration(Duration diff) {
    final totalMinutes = diff.inMinutes;
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = totalMinutes % 60;

    if (totalMinutes <= 0) {
      return 'in less than 1 min';
    }

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0 || (days == 0 && hours == 0)) parts.add('${minutes}m');

    return 'in ${parts.join(' ')}';
  }

  void _testAlarm(BuildContext context, [AlarmItem? alarm]) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final targetAlarm = alarm ??
        AlarmItem(
          id: 'test_meeting_alarm',
          title: 'Meeting with Team',
          time: '03:00 PM',
          description: 'Project sprint planning and presentation review.',
          isEnabled: true,
          soundRingtone: provider.defaultAlarmTone,
        );
    AlarmRingingDialog.show(context, targetAlarm);
  }

  void _showManageTonesBottomSheet(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.library_music_rounded, color: Color(0xFF6366F1), size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Manage Alarm Tones & Sounds',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          AlarmSoundService.instance.stopAlarmSound();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview, select default tones, or import audio files (.mp3, .wav) from your device.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),

                  // Pick Audio From Device Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                      ),
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
                            dialogTitle: 'Select Custom Alarm Tone',
                          );
                          if (result != null && result.files.single.path != null) {
                            final path = result.files.single.path!;
                            final fileName = result.files.single.name.replaceAll(RegExp(r'\.[^.]+$'), '');
                            await provider.addCustomAlarmTone(fileName, filePath: path);
                            setSheetState(() {});
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added custom tone: "$fileName"')),
                              );
                            }
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open file picker')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.audio_file_rounded, color: Color(0xFF6366F1)),
                      label: const Text(
                        'Import Audio File from Device',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Tones List
                  Expanded(
                    child: ListView.builder(
                      itemCount: provider.availableAlarmTones.length,
                      itemBuilder: (context, index) {
                        final tone = provider.availableAlarmTones[index];
                        final isDefault = tone == provider.defaultAlarmTone;
                        final filePath = provider.getToneFilePath(tone);
                        final isCustom = filePath != null;
                        final isPlaying = AlarmSoundService.instance.isPlaying &&
                            AlarmSoundService.instance.currentPlayingTone == tone;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDefault
                                ? colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDefault
                                  ? colorScheme.primary.withValues(alpha: 0.4)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Play / Stop Preview Button
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                  color: isPlaying ? Colors.redAccent : const Color(0xFF6366F1),
                                  size: 32,
                                ),
                                tooltip: isPlaying ? 'Stop Preview' : 'Play Preview',
                                onPressed: () {
                                  if (isPlaying) {
                                    AlarmSoundService.instance.stopAlarmSound();
                                  } else {
                                    provider.previewPlayTone(tone);
                                  }
                                  setSheetState(() {});
                                },
                              ),
                              const SizedBox(width: 8),

                              // Tone Title & Badges
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          tone,
                                          style: TextStyle(
                                            fontWeight: isDefault ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 15,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        if (isDefault) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'DEFAULT',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isCustom ? 'Custom imported audio file' : 'Built-in manageable preset',
                                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),

                              // Set Default Button
                              if (!isDefault)
                                TextButton(
                                  onPressed: () async {
                                    await provider.setDefaultAlarmTone(tone);
                                    setSheetState(() {});
                                  },
                                  child: const Text('Set Default'),
                                ),

                              // Delete button for custom tones
                              if (isCustom)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () async {
                                    await provider.removeCustomAlarmTone(tone);
                                    setSheetState(() {});
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      AlarmSoundService.instance.stopAlarmSound();
    });
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
    String ringtone = alarm?.soundRingtone ?? provider.defaultAlarmTone;
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

            final h = selectedTime.hour.toString().padLeft(2, '0');
            final m = selectedTime.minute.toString().padLeft(2, '0');
            final timeStr = '$h:$m';
            final timeRemainingPreview = calculateTimeRemaining(timeStr, selectedDays.toList());

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
                          onPressed: () {
                            AlarmSoundService.instance.stopAlarmSound();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Big Time Selector Box with Live Remaining Time Preview
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
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ALARM TIME',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formattedTimeStr,
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(Icons.access_time_rounded, color: colorScheme.primary, size: 32),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Rings $timeRemainingPreview',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Alarm Title / Work Name',
                        hintText: 'e.g. Meeting with Team, DSA Practice, Math Exam',
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
                        labelText: 'Unique Description / Work Notes for Alarm',
                        hintText: 'e.g. Discuss Q3 deliverables and bring laptop.',
                        alignLabelWithHint: true,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.description_rounded),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        helperText: 'This will be displayed prominently when the alarm rings.',
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
                      runSpacing: 8,
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

                    // Ringtone & Snooze with Tone Preview Button
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: provider.availableAlarmTones.contains(ringtone)
                                ? ringtone
                                : provider.availableAlarmTones.first,
                            decoration: InputDecoration(
                              labelText: 'Ringtone',
                              prefixIcon: const Icon(Icons.music_note_rounded),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.orangeAccent, size: 20),
                                tooltip: 'Preview Sound',
                                onPressed: () => provider.previewPlayTone(ringtone),
                              ),
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
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<int>(
                            initialValue: snoozeMins,
                            decoration: InputDecoration(
                              labelText: 'Snooze',
                              prefixIcon: const Icon(Icons.snooze_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 3, child: Text('3m')),
                              DropdownMenuItem(value: 5, child: Text('5m')),
                              DropdownMenuItem(value: 10, child: Text('10m')),
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
                          final scaffold = ScaffoldMessenger.of(context);
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
                          AlarmSoundService.instance.stopAlarmSound();
                          nav.pop();

                          final remaining = calculateTimeRemaining(timeStr, selectedDays.toList());
                          scaffold.showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('Alarm set for $timeStr ($remaining)'),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                            ),
                          );
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
    ).whenComplete(() {
      AlarmSoundService.instance.stopAlarmSound();
    });
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
                  Text('New Daily Habit', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Habit Title',
                      hintText: 'e.g. Read 15 mins, Drink 2L water',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText: 'Description / Purpose',
                      hintText: 'e.g. Improve focus and hydration',
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
          // Manage Alarm Tones Button
          IconButton(
            icon: const Icon(Icons.library_music_rounded),
            tooltip: 'Manage Alarm Sounds & Tones',
            onPressed: () => _showManageTonesBottomSheet(context),
          ),
          // Test Alarm Ringing Button
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded, color: Colors.orangeAccent),
            tooltip: 'Test Alarm Ringing & Sounds',
            onPressed: () => _testAlarm(context),
          ),
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
      body: GlassBackground(
        child: TabBarView(
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
    final timeRemaining = calculateTimeRemaining(alarm.time, alarm.repeatDays, isEnabled: alarm.isEnabled);

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
              Expanded(
                child: Column(
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: alarm.isEnabled,
                onChanged: (_) {
                  provider.toggleAlarmStatus(alarm);
                  if (!alarm.isEnabled) {
                    final remaining = calculateTimeRemaining(alarm.time, alarm.repeatDays, isEnabled: true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.alarm_on_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Text('Alarm enabled (rings $remaining)'),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Time Remaining Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: alarm.isEnabled
                  ? colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.1)
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: alarm.isEnabled
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  alarm.isEnabled ? Icons.schedule_rounded : Icons.alarm_off_rounded,
                  size: 14,
                  color: alarm.isEnabled ? colorScheme.primary : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  alarm.isEnabled ? 'Rings $timeRemaining' : 'Alarm is turned off',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: alarm.isEnabled
                        ? (isDark ? colorScheme.primary : const Color(0xFF4F46E5))
                        : Colors.grey,
                  ),
                ),
              ],
            ),
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

          // Repeat Days and Ringtone Info (Bounded with Expanded / Wrap to prevent overflow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Repeat Days Chips or One-time Alarm label
              if (alarm.repeatDays.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: alarm.repeatDays.map((d) {
                      return GlassPillBadge(
                        label: d,
                        color: colorScheme.secondary,
                      );
                    }).toList(),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'One-time Alarm',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                  ),
                ),

              const SizedBox(width: 8),

              // Ringtone info badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.music_note_rounded, size: 12, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: Text(
                        alarm.soundRingtone,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          const Divider(height: 12, thickness: 0.5),

          // Action Buttons Toolbar Row (Clean, responsive, compact)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Quick Reschedule / Delay Button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.schedule_send_rounded, color: Color(0xFF6366F1), size: 20),
                tooltip: 'Reschedule / Delay Alarm',
                onPressed: () {
                  UniversalRescheduleDialog.showForAlarm(context, alarm);
                },
              ),
              // Test Ring Button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.notifications_active_rounded, color: Colors.orangeAccent, size: 20),
                tooltip: 'Test Ring Alarm & Wake Up Screen',
                onPressed: () {
                  _testAlarm(context, alarm);
                },
              ),
              // Edit Button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_rounded, size: 20),
                tooltip: 'Edit Alarm',
                onPressed: () => _showAddEditAlarmDialog(context, alarm),
              ),
              // Delete Button
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                tooltip: 'Delete Alarm',
                onPressed: () => provider.deleteAlarm(alarm.id),
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
