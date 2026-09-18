import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../engine/study_timer_engine.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/universal_reschedule_dialog.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  final StudyTimerEngine _engine = StudyTimerEngine();
  final List<String> _subjects = ['General', 'Mathematics', 'Physics', 'Programming', 'Language', 'Reading'];

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final absSec = totalSeconds.abs();
    final minutes = absSec ~/ 60;
    final seconds = absSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ChangeNotifierProvider.value(
      value: _engine,
      child: Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.timer_rounded, color: Color(0xFF6366F1)),
              SizedBox(width: 8),
              Text('Study Tracker & Focus'),
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
          child: Consumer<StudyTimerEngine>(
            builder: (context, engine, child) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Mode Toggle
                    SegmentedButton<TimerMode>(
                      segments: const [
                        ButtonSegment(value: TimerMode.stopwatch, label: Text('Stopwatch'), icon: Icon(Icons.timer_rounded)),
                        ButtonSegment(value: TimerMode.pomodoro, label: Text('Pomodoro'), icon: Icon(Icons.psychology_rounded)),
                      ],
                      selected: {engine.mode},
                      onSelectionChanged: (set) => engine.setMode(set.first),
                    ),
                    const SizedBox(height: 18),

                    // Subject Selector Card
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.menu_book_rounded, color: colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text('Focus Subject:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                          DropdownButton<String>(
                            value: engine.currentSubject,
                            underline: const SizedBox.shrink(),
                            items: _subjects
                                .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.primary))))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) engine.setSubject(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Main Frosted Glass Timer Circle
                    GlassContainer(
                      width: 270,
                      height: 270,
                      borderRadius: 135,
                      blurSigma: 16,
                      shadows: [
                        BoxShadow(
                          color: engine.isRunning
                              ? colorScheme.primary.withValues(alpha: isDark ? 0.4 : 0.25)
                              : (isDark ? Colors.black38 : Colors.grey.withValues(alpha: 0.1)),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (engine.mode == TimerMode.pomodoro) ...[
                              GlassPillBadge(
                                label: engine.phase == PomodoroPhase.work
                                    ? '🔥 WORK CYCLE ${engine.currentCycle}'
                                    : (engine.phase == PomodoroPhase.shortBreak ? '☕ SHORT BREAK' : '🌴 LONG BREAK'),
                                color: engine.phase == PomodoroPhase.work ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              _formatTime(engine.mode == TimerMode.stopwatch ? engine.elapsedSeconds : engine.remainingSeconds),
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Target: ${engine.targetMinutes} mins',
                              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!engine.isRunning && !engine.isPaused)
                          GlassButton(
                            onPressed: () => engine.start(),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start Focus'),
                          ),
                        if (engine.isRunning)
                          GlassButton(
                            backgroundColor: Colors.amber.shade700,
                            onPressed: () => engine.pause(),
                            icon: const Icon(Icons.pause_rounded),
                            label: const Text('Pause'),
                          ),
                        if (engine.isPaused)
                          GlassButton(
                            backgroundColor: Colors.green.shade600,
                            onPressed: () => engine.resume(),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Resume'),
                          ),
                        const SizedBox(width: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (engine.elapsedSeconds > 0) {
                              final session = engine.completeSession();
                              Provider.of<AppProvider>(context, listen: false).saveStudySession(session);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Recorded ${session.actualMinutes} mins of study for ${session.subject}! 📚')),
                              );
                            } else {
                              engine.reset();
                            }
                          },
                          icon: const Icon(Icons.stop_rounded),
                          label: const Text('Finish & Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Target Minutes Slider in Glass Card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Planned Duration Goal', style: TextStyle(fontWeight: FontWeight.bold)),
                              GlassPillBadge(label: '${engine.targetMinutes}m', color: colorScheme.primary),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: engine.targetMinutes.toDouble(),
                            min: 5,
                            max: 180,
                            divisions: 35,
                            label: '${engine.targetMinutes}m',
                            onChanged: (val) => engine.setTargetMinutes(val.round()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
