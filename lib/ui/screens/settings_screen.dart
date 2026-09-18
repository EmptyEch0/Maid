import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/app_provider.dart';
import '../../services/database_helper.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/animated_entry.dart';
import '../widgets/universal_reschedule_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showAddCustomToneDialog(BuildContext context, AppProvider provider, {required bool isAlarmTone}) {
    final textCtrl = TextEditingController();
    String? selectedFilePath;
    final presets = isAlarmTone
        ? ['Morning Sunrise', 'Birds Chirping', 'Digital Beep', 'Guitar Strum', 'Loud Siren', 'Zen Bell']
        : ['Soft Chime', 'Double Pulse', 'Marimba Note', 'Triple Ping', 'Gentle Alert'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isAlarmTone ? 'Add Custom Alarm Tone' : 'Add Custom Reminder Tone'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tone Name / Audio Label',
                      hintText: 'e.g. Energetic Beat, Peaceful Flute',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pick from Device button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac', 'flac'],
                            dialogTitle: 'Select Alarm Ringtone',
                          );
                          if (result != null && result.files.single.path != null) {
                            final path = result.files.single.path!;
                            final fileName = result.files.single.name;
                            setDialogState(() {
                              selectedFilePath = path;
                              if (textCtrl.text.trim().isEmpty) {
                                // Auto-fill name from file name (without extension)
                                textCtrl.text = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
                              }
                            });
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open file picker')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Pick Audio from Device'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  // Show selected file path
                  if (selectedFilePath != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.music_note_rounded, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedFilePath!.split('/').last,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => setDialogState(() => selectedFilePath = null),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text('Or pick a preset:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((p) {
                      return ActionChip(
                        label: Text(p),
                        onPressed: () {
                          textCtrl.text = p;
                          setDialogState(() => selectedFilePath = null);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = textCtrl.text.trim();
                  if (name.isNotEmpty) {
                    if (isAlarmTone) {
                      provider.addCustomAlarmTone(name, filePath: selectedFilePath);
                    } else {
                      provider.addCustomReminderTone(name, filePath: selectedFilePath);
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(selectedFilePath != null
                            ? 'Added custom tone: "$name" with audio file'
                            : 'Added custom tone: "$name"'),
                      ),
                    );
                  }
                },
                child: const Text('Add Tone'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.settings_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Maid Settings & Security'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Reschedule Anything',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
        ],
      ),
      body: GlassBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
        children: [
          // App Logo Header Glass Card
          AnimatedEntry(
            index: 0,
            child: GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Maid Assistant v1.0', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(
                          '100% Offline-First Smart Calendar & Productivity',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // TONE MANAGEMENT SECTION
          AnimatedEntry(
            index: 1,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.music_note_rounded, color: colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Alarm & Reminder Tone Manager',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Default Alarm Tone
                  DropdownButtonFormField<String>(
                    initialValue: provider.availableAlarmTones.contains(provider.defaultAlarmTone)
                        ? provider.defaultAlarmTone
                        : provider.availableAlarmTones.first,
                    decoration: InputDecoration(
                      labelText: 'Default Wake-Up Alarm Tone',
                      prefixIcon: const Icon(Icons.alarm_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.orangeAccent),
                        tooltip: 'Test Sound & Vibration',
                        onPressed: () => provider.previewPlayTone(provider.defaultAlarmTone),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: provider.availableAlarmTones.map((tone) {
                      return DropdownMenuItem<String>(
                        value: tone,
                        child: Text(tone),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) provider.setDefaultAlarmTone(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showAddCustomToneDialog(context, provider, isAlarmTone: true),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Custom Alarm Tone'),
                    ),
                  ),

                  const Divider(height: 20),

                  // Default Reminder Tone
                  DropdownButtonFormField<String>(
                    initialValue: provider.availableReminderTones.contains(provider.defaultReminderTone)
                        ? provider.defaultReminderTone
                        : provider.availableReminderTones.first,
                    decoration: InputDecoration(
                      labelText: 'Default Event Reminder Tone',
                      prefixIcon: const Icon(Icons.notifications_active_rounded),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.orangeAccent),
                        tooltip: 'Test Sound & Vibration',
                        onPressed: () => provider.previewPlayTone(provider.defaultReminderTone),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: provider.availableReminderTones.map((tone) {
                      return DropdownMenuItem<String>(
                        value: tone,
                        child: Text(tone),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) provider.setDefaultReminderTone(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showAddCustomToneDialog(context, provider, isAlarmTone: false),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Custom Reminder Tone'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // APPEARANCE & GLASSMORPHIC THEME MANAGER
          AnimatedEntry(
            index: 2,
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette_rounded, color: Color(0xFF6366F1), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Appearance & Glassmorphism',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose your preferred aesthetic. All widgets and dialogs adapt with frosted blur and high-contrast styling.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  // 3-Way Mode Segmented Selector
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Light Glass'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Dark Glass'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.auto_mode_rounded),
                            label: Text('Auto System'),
                          ),
                        ],
                        selected: {provider.themeMode},
                        onSelectionChanged: (newSelection) {
                          if (newSelection.isNotEmpty) {
                            provider.setThemeMode(newSelection.first);
                          }
                        },
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Live Glass Preview Tile
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF4F46E5).withValues(alpha: 0.05),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.15),
                          ),
                          child: Icon(
                            provider.themeMode == ThemeMode.light
                                ? Icons.wb_sunny_rounded
                                : (provider.themeMode == ThemeMode.dark
                                    ? Icons.nightlight_round
                                    : Icons.brightness_auto_rounded),
                            color: const Color(0xFF6366F1),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.themeMode == ThemeMode.light
                                    ? 'Light Frosted Glass Active'
                                    : (provider.themeMode == ThemeMode.dark
                                        ? 'Midnight Obsidian Glass Active'
                                        : 'System Auto Mode Active'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Supports Transparent Android Home Widget with Mic read-out',
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Security Section
          AnimatedEntry(
            index: 3,
            child: GlassCard(
              onTap: () => _showPinConfigDialog(context, provider),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.security_rounded, color: Colors.blue),
                title: const Text('App PIN Security Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(provider.isPinSet ? 'PIN Enabled (Tap to change/remove)' : 'No PIN Set'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Local Backup Section
          AnimatedEntry(
            index: 4,
            child: GlassCard(
              onTap: () async {
                final data = await DatabaseHelper.instance.exportAllData();
                final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Offline JSON Backup Preview'),
                      content: SizedBox(
                        width: double.maxFinite,
                        height: 220,
                        child: SingleChildScrollView(
                          child: SelectableText(jsonStr, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      ],
                    ),
                  );
                }
              },
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.download_rounded, color: Colors.green),
                title: Text('Export Local Database (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Save offline backup file to device storage'),
                trailing: Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  void _showPinConfigDialog(BuildContext context, AppProvider provider) {
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(provider.isPinSet ? 'Change / Remove PIN' : 'Set 4-Digit PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Enter 4-Digit PIN', border: OutlineInputBorder()),
        ),
        actions: [
          if (provider.isPinSet)
            TextButton(
              onPressed: () {
                provider.removePin();
                Navigator.pop(ctx);
              },
              child: const Text('Remove PIN', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final pin = pinController.text.trim();
              if (pin.length == 4) {
                provider.setPin(pin);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
  }
}
