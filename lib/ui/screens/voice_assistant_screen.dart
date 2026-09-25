import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../engine/local_query_engine.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/daily_briefing_dialog.dart';
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

    _ttsService.onSpeechStarted = () {
      if (mounted) setState(() => _isSpeaking = true);
    };
    _ttsService.onSpeechStopped = () {
      if (mounted) setState(() => _isSpeaking = false);
    };

    // Auto-enable Wake-Word & Stop listener on screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _autoStartWakeWordMonitoring();
      // Greet and read today overview
      _executeAssistantQuery("tell my work and today tasks");
    });
  }

  Future<void> _autoStartWakeWordMonitoring() async {
    final ok = await _speechService.init();
    if (ok && mounted) {
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
        onStop: () {
          _handleStopAction();
        },
      );
    }
  }

  void _handleStopAction() {
    _ttsService.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _isListening = false;
        _recognizedText = 'Stop (Silenced)';
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 Assistant speech stopped by "Stop" command'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    _ttsService.onSpeechStarted = null;
    _ttsService.onSpeechStopped = null;
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
            _executeAssistantQuery(text);
          },
          onStop: () {
            _handleStopAction();
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
      await _autoStartWakeWordMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ "Hey Maid" active! Say "Hey Maid" to talk, or "Stop" anytime to cancel speech.')),
        );
      }
    }
  }

  Future<void> _executeAssistantQuery(String queryText) async {
    if (queryText.trim().isEmpty) return;

    if (SpeechService.isStopCommand(queryText.trim())) {
      _handleStopAction();
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    final result = await LocalQueryEngine.processQuery(queryText, provider);

    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _isSpeaking = result.spokenText.isNotEmpty;
    });

    // Speak natural response out loud only if spokenText is provided
    await _ttsService.stop();
    if (result.spokenText.isNotEmpty) {
      await _ttsService.speak(result.spokenText);
    }
    if (mounted && result.spokenText.isEmpty) {
      setState(() => _isSpeaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<AppProvider>(context);
    final pendingToday = provider.pendingTodayTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 24),
            SizedBox(width: 8),
            Text('Maid Voice Assistant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Daily Briefing',
            icon: const Icon(Icons.wb_sunny_rounded, color: Colors.amber),
            onPressed: () => DailyBriefingDialog.show(context, isEvening: false, autoPlaySpeech: true),
          ),
          IconButton(
            tooltip: _isWakeWordActive ? 'Wake-word Active ("Hey Maid" / "Stop")' : 'Enable Wake-word',
            icon: Icon(
              _isWakeWordActive ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
              color: _isWakeWordActive ? Colors.green : Colors.grey,
            ),
            onPressed: _toggleWakeWordMonitoring,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                : [const Color(0xFFF8FAFC), const Color(0xFFEEF2F6)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Top Active Wake-word & Stop Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isSpeaking
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : (_isWakeWordActive
                            ? Colors.green.withValues(alpha: 0.12)
                            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isSpeaking
                          ? Colors.redAccent.withValues(alpha: 0.4)
                          : (_isWakeWordActive
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.transparent),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSpeaking
                            ? Icons.volume_up_rounded
                            : (_isWakeWordActive ? Icons.hearing_rounded : Icons.mic_none_rounded),
                        color: _isSpeaking
                            ? Colors.redAccent
                            : (_isWakeWordActive ? Colors.green : Colors.grey),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isSpeaking
                            ? 'Speaking... Say "Stop" or tap Orb to silence'
                            : (_isWakeWordActive
                                ? 'Active: Say "Hey Maid..." or "Stop" anytime'
                                : 'Tap mic or enable wake word'),
                        style: TextStyle(
                          color: _isSpeaking
                              ? Colors.redAccent
                              : (_isWakeWordActive ? Colors.green : colorScheme.onSurfaceVariant),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (_isSpeaking) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _handleStopAction,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.stop_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 2),
                                Text('STOP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Center Glowing Voice Orb
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_isSpeaking) {
                            _handleStopAction();
                          } else {
                            _toggleSpeechListening();
                          }
                        },
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: _isListening ? 0.95 : 0.88,
                            end: _isListening ? 1.08 : 1.0,
                          ).animate(CurvedAnimation(parent: _orbController, curve: Curves.easeInOut)),
                          child: Container(
                            width: 105,
                            height: 105,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _isListening
                                    ? [Colors.redAccent, colorScheme.primary]
                                    : _isSpeaking
                                        ? [Colors.amberAccent, Colors.redAccent]
                                        : (_isWakeWordActive
                                            ? [Colors.green, colorScheme.primary]
                                            : [colorScheme.primary, colorScheme.secondary]),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening
                                          ? Colors.redAccent
                                          : (_isSpeaking
                                              ? Colors.redAccent
                                              : (_isWakeWordActive ? Colors.green : colorScheme.primary)))
                                      .withValues(alpha: 0.4),
                                  blurRadius: _isListening || _isSpeaking ? 36 : 22,
                                  spreadRadius: _isListening || _isSpeaking ? 10 : 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isListening
                                  ? Icons.mic_rounded
                                  : _isSpeaking
                                      ? Icons.stop_circle_rounded
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
                            ? 'Listening... Speak your request or say "Stop"'
                            : _isSpeaking
                                ? 'Speaking... (Say "Stop" or tap orb to silence)'
                                : (_isWakeWordActive
                                    ? 'Wake-word active: say "Hey Maid..." or "Stop"'
                                    : 'Tap orb or speak "Hey Maid"'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _isListening
                              ? Colors.redAccent
                              : (_isSpeaking
                                  ? Colors.redAccent
                                  : (_isWakeWordActive ? Colors.green : colorScheme.primary)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Main Result & Fast Interaction Area
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.all(12),
                    borderRadius: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header with intent icon & result title
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(
                                _getIntentIcon(_lastResult?.intentType ?? 'none'),
                                size: 16,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _recognizedText.isNotEmpty
                                    ? 'Query: "$_recognizedText"'
                                    : 'Assistant Response',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_isSpeaking)
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 20),
                                tooltip: 'Stop Audio',
                                onPressed: _handleStopAction,
                              )
                            else if (_lastResult?.spokenText.isNotEmpty ?? false)
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.volume_up_rounded, size: 18),
                                tooltip: 'Replay Aloud',
                                onPressed: () {
                                  _ttsService.stop();
                                  _ttsService.speak(_lastResult!.spokenText);
                                },
                              ),
                          ],
                        ),
                        const Divider(height: 12),

                        // Scrollable Main Content & Pending Summary
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_lastResult != null)
                                  SelectableText(
                                    _lastResult!.displayText,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                else
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                                      child: Text(
                                        'Say "Hey Maid tell my work", "Meeting at 4pm as alarm", or say "Stop" to silence.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 10),

                                // Top 3 Quick Pending Tasks Inline
                                if (pendingToday.isNotEmpty) ...[
                                  Text(
                                    'Today\'s Pending Tasks (${pendingToday.length}):',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ...pendingToday.take(3).map((task) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: task.priority == 3
                                                ? Colors.redAccent
                                                : (task.priority == 2 ? Colors.amber : Colors.blueGrey),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: const TextStyle(fontSize: 12.5),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                                            onPressed: () => provider.toggleTaskStatus(task),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],

                                const SizedBox(height: 6),
                                // Quick Add Task Line
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
                        avatar: const Icon(Icons.stop_circle_rounded, size: 16, color: Colors.redAccent),
                        label: const Text("Stop Audio", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                        onPressed: _handleStopAction,
                      ),
                      const SizedBox(width: 6),
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
                            hintText: 'Ask "what\'s today\'s task", "stop"...',
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
      case 'stop':
        return Icons.stop_circle_rounded;
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
