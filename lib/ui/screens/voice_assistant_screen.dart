import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../engine/local_query_engine.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/universal_reschedule_dialog.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> with SingleTickerProviderStateMixin {
  late AnimationController _orbController;
  final SpeechService _speechService = SpeechService.instance;
  final TtsService _ttsService = TtsService.instance;

  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isWakeWordActive = false;
  String _recognizedText = '';
  LocalQueryResult? _lastResult;

  final TextEditingController _textInputCtrl = TextEditingController();
  final TextEditingController _quickTaskCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Initial greeting / day overview out loud
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeAssistantQuery("tell my work and today tasks");
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    _ttsService.stop();
    _speechService.stop();
    _textInputCtrl.dispose();
    _quickTaskCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleSpeechListening() async {
    if (_isListening) {
      await _speechService.stop();
      setState(() => _isListening = false);
    } else {
      await _ttsService.stop();
      final ok = await _speechService.init();
      if (ok) {
        setState(() {
          _isListening = true;
          _recognizedText = '';
        });
        await _speechService.listen(
          onResult: (text) {
            setState(() {
              _recognizedText = text;
              _textInputCtrl.text = text;
            });
            // Execute query when user stops speaking or delivers text
            _executeAssistantQuery(text);
          },
        );
      }
    }
  }

  Future<void> _toggleWakeWordMonitoring() async {
    if (_isWakeWordActive) {
      await _speechService.stop();
      setState(() => _isWakeWordActive = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Always-listening "Hey Maid" disabled')),
        );
      }
    } else {
      final ok = await _speechService.init();
      if (ok) {
        setState(() => _isWakeWordActive = true);
        await _speechService.startWakeWordMonitoring(
          onQuery: (query) {
            if (mounted) {
              setState(() {
                _recognizedText = query;
                _textInputCtrl.text = query;
              });
              _executeAssistantQuery(query);
            }
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ "Hey Maid" Wake-Word listening is now active! Say "Hey Maid" anytime.')),
          );
        }
      }
    }
  }

  Future<void> _executeAssistantQuery(String queryText) async {
    if (queryText.trim().isEmpty) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final result = await LocalQueryEngine.processQuery(queryText, provider);

    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _isSpeaking = true;
    });

    // Speak natural response out loud
    await _ttsService.stop();
    await _ttsService.speak(result.spokenText);
    if (mounted) setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<AppProvider>(context);
    final pendingToday = provider.pendingTodayTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Maid Voice Assistant'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isWakeWordActive ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
              color: _isWakeWordActive ? Colors.green : Colors.grey,
            ),
            tooltip: _isWakeWordActive ? '"Hey Maid" Active (Tap to pause)' : 'Enable "Hey Maid" Wake-Word',
            onPressed: _toggleWakeWordMonitoring,
          ),
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Reschedule Anything',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
          IconButton(
            icon: Icon(_isSpeaking ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            tooltip: _isSpeaking ? 'Speaking...' : 'Mute TTS',
            onPressed: () {
              _ttsService.stop();
              setState(() => _isSpeaking = false);
            },
          ),
        ],
      ),
      body: GlassBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Column(
            children: [
              // Wake Word Active Banner
              if (_isWakeWordActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hearing_rounded, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Background Wake-Word Active: Say "Hey Maid..." anytime',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

              // Animated Glowing Voice Orb
              Expanded(
                flex: 3,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _toggleSpeechListening,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: _isListening ? 0.95 : 0.88,
                            end: _isListening ? 1.25 : 1.05,
                          ).animate(CurvedAnimation(parent: _orbController, curve: Curves.easeInOut)),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: _isListening
                                    ? [Colors.redAccent, colorScheme.primary]
                                    : _isSpeaking
                                        ? [Colors.cyanAccent, colorScheme.primary]
                                        : (_isWakeWordActive
                                            ? [Colors.green, colorScheme.primary]
                                            : [colorScheme.primary, colorScheme.secondary]),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening
                                          ? Colors.redAccent
                                          : (_isWakeWordActive ? Colors.green : colorScheme.primary))
                                      .withValues(alpha: 0.4),
                                  blurRadius: _isListening ? 36 : 22,
                                  spreadRadius: _isListening ? 10 : 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening
                                  ? Icons.mic_rounded
                                  : _isSpeaking
                                      ? Icons.graphic_eq_rounded
                                      : (_isWakeWordActive ? Icons.hearing_rounded : Icons.auto_awesome_rounded),
                              size: 54,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isListening
                            ? 'Listening... Speak your request now'
                            : _isSpeaking
                                ? 'Speaking response out loud...'
                                : (_isWakeWordActive
                                    ? 'Wake-word active: say "Hey Maid..." or tap orb'
                                    : 'Tap orb or speak "Hey Maid"'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isListening
                              ? Colors.redAccent
                              : (_isWakeWordActive ? Colors.green : colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // PROMINENT "TELL MY WORK & TODAY'S TASKS" TRIGGER BUTTON
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 3,
                  ),
                  onPressed: () => _executeAssistantQuery("tell my work and today's tasks"),
                  icon: const Icon(Icons.record_voice_over_rounded, size: 20),
                  label: const Text(
                    "Tell My Work & Today's Tasks (TTS)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.3),
                  ),
                ),
              ),

              // Spoken Result Display & Quick Tasks Card
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_recognizedText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            borderRadius: 14,
                            child: Row(
                              children: [
                                Icon(Icons.mic_rounded, size: 16, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '"$_recognizedText"',
                                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_lastResult != null)
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getIntentIcon(_lastResult!.intentType),
                                    color: colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  GlassPillBadge(
                                    label: 'ASSISTANT SPOKEN ANSWER',
                                    color: colorScheme.primary,
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.replay_rounded, size: 18),
                                    tooltip: 'Speak Again',
                                    onPressed: () => _ttsService.speak(_lastResult!.spokenText),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _lastResult!.displayText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Quick Today's To-Do Preview Box
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.checklist_rounded, color: Color(0xFF6366F1), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  "Today's Quick To-Do List (${pendingToday.length} left)",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const Spacer(),
                                TextButton(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                  onPressed: () => _executeAssistantQuery("what are today's tasks"),
                                  child: const Text('Ask Assistant', style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (pendingToday.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text('✨ No pending tasks for today! Great job.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              )
                            else
                              ...pendingToday.take(3).map((task) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: task.status == 'completed',
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (_) => provider.toggleTaskStatus(task),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 6),
                            // Quick Add Line
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _quickTaskCtrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Quick add a task for today...',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onSubmitted: (val) {
                                      if (val.trim().isNotEmpty) {
                                        provider.addTask(TaskItem(
                                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                                          title: val.trim(),
                                          dueDate: provider.selectedDateStr,
                                          priority: 2,
                                        ));
                                        _quickTaskCtrl.clear();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton.filledTonal(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: () {
                                    final val = _quickTaskCtrl.text.trim();
                                    if (val.isNotEmpty) {
                                      provider.addTask(TaskItem(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        title: val,
                                        dueDate: provider.selectedDateStr,
                                        priority: 2,
                                      ));
                                      _quickTaskCtrl.clear();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Quick Action Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.record_voice_over_rounded, size: 16, color: Colors.indigo),
                      label: const Text("Tell My Work"),
                      onPressed: () => _executeAssistantQuery("tell my work and today's tasks"),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.task_alt_rounded, size: 16, color: Colors.green),
                      label: const Text("What's Today's Task?"),
                      onPressed: () => _executeAssistantQuery("what is today task"),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.alarm_rounded, size: 16, color: Colors.orange),
                      label: const Text("Check Alarms"),
                      onPressed: () => _executeAssistantQuery("what alarms are set"),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: const Text("Today's Schedule"),
                      onPressed: () => _executeAssistantQuery("what is today schedule"),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 16, color: Colors.amber),
                      label: const Text("Habit Streaks"),
                      onPressed: () => _executeAssistantQuery("show habit streaks"),
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.schedule_send_rounded, size: 16, color: Colors.purple),
                      label: const Text("Reschedule Any"),
                      onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Text Input Box
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                borderRadius: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textInputCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Ask "what\'s today\'s task", "tell my work"...',
                          hintStyle: TextStyle(fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (text) => _executeAssistantQuery(text),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isListening ? Colors.redAccent : colorScheme.primary,
                      ),
                      onPressed: _toggleSpeechListening,
                    ),
                    IconButton.filled(
                      onPressed: () => _executeAssistantQuery(_textInputCtrl.text),
                      icon: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  IconData _getIntentIcon(String intent) {
    switch (intent) {
      case 'today_work':
        return Icons.auto_awesome_rounded;
      case 'schedule':
        return Icons.calendar_month_rounded;
      case 'tasks':
        return Icons.task_alt_rounded;
      case 'alarms':
        return Icons.alarm_rounded;
      case 'habits':
        return Icons.bolt_rounded;
      case 'notes':
        return Icons.search_rounded;
      default:
        return Icons.chat_bubble_outline_rounded;
    }
  }
}
