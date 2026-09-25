import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/tts_service.dart';
import 'glass_widgets.dart';

class DailyBriefingDialog extends StatefulWidget {
  final bool isEvening;
  final bool autoPlaySpeech;

  const DailyBriefingDialog({
    super.key,
    this.isEvening = false,
    this.autoPlaySpeech = true,
  });

  static void show(BuildContext context, {bool isEvening = false, bool autoPlaySpeech = true}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DailyBriefingDialog(
        isEvening: isEvening,
        autoPlaySpeech: autoPlaySpeech,
      ),
    );
  }

  @override
  State<DailyBriefingDialog> createState() => _DailyBriefingDialogState();
}

class _DailyBriefingDialogState extends State<DailyBriefingDialog>
    with SingleTickerProviderStateMixin {
  bool _isSpeaking = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.autoPlaySpeech) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playSpeechBriefing();
      });
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _playSpeechBriefing() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final speechText = provider.generateDailyBriefingSpeech(isEvening: widget.isEvening);

    setState(() => _isSpeaking = true);
    _waveController.repeat(reverse: true);

    await TtsService.instance.speak(speechText);

    if (mounted) {
      // Allow speech to complete before stopping wave animation
      Future.delayed(Duration(milliseconds: (speechText.length * 75).clamp(2000, 20000)), () {
        if (mounted) {
          setState(() => _isSpeaking = false);
          _waveController.stop();
        }
      });
    }
  }

  Future<void> _stopSpeech() async {
    await TtsService.instance.stop();
    if (mounted) {
      setState(() => _isSpeaking = false);
      _waveController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = provider.userName;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final formattedDate = DateFormat('EEEE, MMMM d').format(now);

    final allTasks = provider.tasks;
    final pendingTasks = allTasks.where((t) {
      final isDueTodayOrUnset = t.dueDate == null || t.dueDate == todayStr;
      return isDueTodayOrUnset && t.status != 'completed';
    }).toList();

    final todaySlots = provider.getResolvedSchedule(todayStr);

    final themeColor = widget.isEvening ? const Color(0xFF8B5CF6) : const Color(0xFFF59E0B);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.isEvening ? '🌙' : '☀️',
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isEvening
                            ? 'Good Evening, $userName!'
                            : 'Good Morning, $userName!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                      ),
                      Text(
                        '$formattedDate • Maid Briefing',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _stopSpeech();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Voice Speech Card with Wave Animation
            GlassContainer(
              padding: const EdgeInsets.all(14),
              borderRadius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.record_voice_over_rounded, size: 14, color: Color(0xFF6366F1)),
                            SizedBox(width: 4),
                            Text(
                              'MAID VOICE BRIEFING',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (_isSpeaking)
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            return Row(
                              children: List.generate(4, (i) {
                                final h = 6.0 + (_waveController.value * (12.0 + (i * 4.0)) % 16.0);
                                return Container(
                                  width: 3,
                                  height: h,
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    provider.generateDailyBriefingSpeech(isEvening: widget.isEvening),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_isSpeaking)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: const Icon(Icons.stop_circle_rounded, size: 18),
                          label: const Text('Stop Voice', style: TextStyle(fontSize: 12)),
                          onPressed: _stopSpeech,
                        )
                      else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.volume_up_rounded, size: 16),
                          label: const Text('Play Aloud', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _playSpeechBriefing,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pending Tasks Section
            Row(
              children: [
                const Icon(Icons.checklist_rounded, size: 18, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(
                  widget.isEvening
                      ? 'Remaining Tasks (${pendingTasks.length})'
                      : 'Today\'s Pending Tasks (${pendingTasks.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (pendingTasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Text('🎉', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All caught up! You have no pending tasks right now.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...pendingTasks.map((task) {
                final pColor = task.priority == 3
                    ? Colors.redAccent
                    : (task.priority == 2 ? Colors.amber : Colors.blueGrey);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: false,
                        activeColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        onChanged: (val) {
                          if (val == true) {
                            provider.toggleTaskStatus(task);
                          }
                        },
                      ),
                      Container(
                        width: 4,
                        height: 20,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: pColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                        ),
                      ),
                      if (task.priority == 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'High',
                            style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 14),

            // Scheduled Events Section (if morning)
            if (todaySlots.isNotEmpty) ...[
              const Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF0EA5E9)),
                  SizedBox(width: 8),
                  Text(
                    'Scheduled Routines & Events',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...todaySlots.map((slot) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: isDark ? 0.08 : 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 8),
                      Text(
                        '${slot.startTime} - ${slot.endTime}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          slot.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),

            // Done / Dismiss Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  _stopSpeech();
                  Navigator.pop(context);
                },
                child: const Text('Got it, let\'s go!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
