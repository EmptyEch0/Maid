import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../services/audio_haptics_service.dart';

class AlarmRingingDialog extends StatefulWidget {
  final AlarmItem alarm;

  const AlarmRingingDialog({
    super.key,
    required this.alarm,
  });

  static Future<void> show(BuildContext context, AlarmItem alarm) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlarmRingingDialog(alarm: alarm),
    );
  }

  @override
  State<AlarmRingingDialog> createState() => _AlarmRingingDialogState();
}

class _AlarmRingingDialogState extends State<AlarmRingingDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _soundHapticTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Play periodic alert ring haptics
    AudioHapticsService.playPhaseTransitionAlert(isBreakStarting: false);
    _soundHapticTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      AudioHapticsService.playPhaseTransitionAlert(isBreakStarting: false);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _soundHapticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog.fullscreen(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.alarm_on_rounded, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'WAKE UP ALARM',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),

              // Animated Pulsing Clock Icon & Time Display
              Column(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.alarm_rounded,
                        size: 80,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Digital Time
                  Text(
                    widget.alarm.time,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 64,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    widget.alarm.title.isNotEmpty ? widget.alarm.title : 'Alarm',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Unique Description Highlight Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.notes_rounded, size: 20, color: colorScheme.onSecondaryContainer),
                            const SizedBox(width: 8),
                            Text(
                              'ALARM NOTE & DESCRIPTION',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: colorScheme.onSecondaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.alarm.description.isNotEmpty
                              ? widget.alarm.description
                              : 'No description added for this alarm.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                            height: 1.4,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action Buttons: Snooze & Dismiss
              Column(
                children: [
                  Row(
                    children: [
                      // Snooze Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Provider.of<AppProvider>(context, listen: false).snoozeAlarm(widget.alarm);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.snooze_rounded),
                          label: Text(
                            'Snooze (${widget.alarm.snoozeDurationMinutes}m)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Dismiss Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          onPressed: () {
                            Provider.of<AppProvider>(context, listen: false).dismissAlarm(widget.alarm);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text(
                            'Wake Up!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
