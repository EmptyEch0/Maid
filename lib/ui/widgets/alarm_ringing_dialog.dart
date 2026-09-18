import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../services/alarm_sound_service.dart';
import '../../services/tts_service.dart';

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

class _AlarmRingingDialogState extends State<AlarmRingingDialog> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Play actual alarm sound
    final provider = Provider.of<AppProvider>(context, listen: false);
    final filePath = provider.getToneFilePath(widget.alarm.soundRingtone);
    AlarmSoundService.instance.playAlarmSound(
      filePath: filePath,
      toneName: widget.alarm.soundRingtone,
      loop: true,
    );

    // Speak announcement once
    final workName = widget.alarm.title.isNotEmpty ? widget.alarm.title : 'Alarm';
    TtsService.instance.speak('Wake up! You have an alarm for $workName.');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    AlarmSoundService.instance.stopAlarmSound();
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workTitle = widget.alarm.title.isNotEmpty ? widget.alarm.title : 'Wake Up Alarm';

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0B0F19), // Deep immersive dark background
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Incoming Call / Alarm Banner
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm_on_rounded, color: Color(0xFF818CF8), size: 20),
                        SizedBox(width: 8),
                        Text(
                          '⏰ INCOMING WAKE-UP ALARM',
                          style: TextStyle(
                            color: Color(0xFFC7D2FE),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Maid Assistant Alarm',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // Center Visual: Animated Rippling Rings, Time & Work Name
              Column(
                children: [
                  // Animated Rippling Rings Icon
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer animated ripple ring
                      AnimatedBuilder(
                        animation: _rippleController,
                        builder: (context, child) {
                          return Container(
                            width: 140 + (_rippleController.value * 60),
                            height: 140 + (_rippleController.value * 60),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF6366F1).withValues(alpha: 1.0 - _rippleController.value),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      // Inner Pulsing Core
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.12).animate(
                          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                                blurRadius: 36,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.alarm_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Digital Time Display
                  Text(
                    widget.alarm.time,
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Prominent Work / Task Name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      workTitle,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tone Indicator Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note_rounded, size: 16, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 6),
                      Text(
                        'Ringtone: ${widget.alarm.soundRingtone}',
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  if (widget.alarm.description.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    // Work Description Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_rounded, color: Color(0xFF818CF8), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.alarm.description,
                              style: const TextStyle(
                                color: Color(0xFFE2E8F0),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              // Bottom Action Buttons: Snooze & Dismiss
              Column(
                children: [
                  Row(
                    children: [
                      // Snooze Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {
                            AlarmSoundService.instance.stopAlarmSound();
                            TtsService.instance.stop();
                            Provider.of<AppProvider>(context, listen: false).snoozeAlarm(widget.alarm);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.snooze_rounded, color: Color(0xFFFBBF24)),
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
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 6,
                            shadowColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                          ),
                          onPressed: () {
                            AlarmSoundService.instance.stopAlarmSound();
                            TtsService.instance.stop();
                            Provider.of<AppProvider>(context, listen: false).dismissAlarm(widget.alarm);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 22),
                          label: const Text(
                            'Dismiss / Wake',
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
