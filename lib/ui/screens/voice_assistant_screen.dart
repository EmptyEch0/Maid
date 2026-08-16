import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Initial greeting out loud
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executeAssistantQuery("what is today schedule");
    });
  }

  @override
  void dispose() {
    _orbController.dispose();
    _ttsService.stop();
    _speechService.stop();
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

  void _executeAssistantQuery(String queryText) {
    if (queryText.trim().isEmpty) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final result = LocalQueryEngine.processQuery(queryText, provider);

    setState(() {
      _lastResult = result;
      _isSpeaking = true;
    });

    // Speak natural response out loud
    _ttsService.speak(result.spokenText).then((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Column(
            children: [
              // Wake Word Active Indicator Banner
              if (_isWakeWordActive)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                flex: 2,
                child: Center(
                  child: GestureDetector(
                    onTap: _toggleSpeechListening,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: _isListening ? 0.95 : 0.85,
                        end: _isListening ? 1.25 : 1.05,
                      ).animate(CurvedAnimation(parent: _orbController, curve: Curves.easeInOut)),
                      child: Container(
                        width: 140,
                        height: 140,
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
                              blurRadius: _isListening ? 40 : 25,
                              spreadRadius: _isListening ? 12 : 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.mic_rounded
                              : _isSpeaking
                                  ? Icons.graphic_eq_rounded
                                  : (_isWakeWordActive ? Icons.hearing_rounded : Icons.auto_awesome_rounded),
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Text(
                _isListening
                    ? 'Listening... Speak your question now'
                    : _isSpeaking
                        ? 'Speaking response out loud...'
                        : (_isWakeWordActive
                            ? 'Wake-word active: say "Hey Maid..." or tap orb'
                            : 'Tap the orb or speak "Hey Maid"'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isListening
                      ? Colors.redAccent
                      : (_isWakeWordActive ? Colors.green : colorScheme.primary),
                ),
              ),

              const SizedBox(height: 12),

              // Answer Card & Spoken Result Display
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_recognizedText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            borderRadius: 16,
                            child: Row(
                              children: [
                                Icon(Icons.record_voice_over_rounded, size: 18, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '"$_recognizedText"',
                                    style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_lastResult != null)
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getIntentIcon(_lastResult!.intentType),
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  GlassPillBadge(
                                    label: 'OFFLINE ASSISTANT RESPONSE',
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _lastResult!.displayText,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Quick Preset Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.schedule_send_rounded, size: 16, color: Colors.indigo),
                      label: const Text("Reschedule Any"),
                      onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: const Text("Today's Schedule"),
                      onPressed: () => _executeAssistantQuery("what is today schedule"),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.task_alt_rounded, size: 16),
                      label: const Text("My Tasks"),
                      onPressed: () => _executeAssistantQuery("what are my tasks"),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.alarm_rounded, size: 16),
                      label: const Text("Check Alarms"),
                      onPressed: () => _executeAssistantQuery("what alarms are set"),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.bolt_rounded, size: 16),
                      label: const Text("Habit Streaks"),
                      onPressed: () => _executeAssistantQuery("show habit streaks"),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Frosted Glass Text Input Box
              GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                borderRadius: 20,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textInputCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Type your offline query...',
                          hintStyle: TextStyle(fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: (text) => _executeAssistantQuery(text),
                      ),
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
    );
  }

  IconData _getIntentIcon(String intent) {
    switch (intent) {
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
        return Icons.auto_awesome_rounded;
    }
  }
}
