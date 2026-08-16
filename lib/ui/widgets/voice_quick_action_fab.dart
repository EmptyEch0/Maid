import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/speech_service.dart';
import 'universal_reschedule_dialog.dart';

class VoiceQuickActionFab extends StatefulWidget {
  final VoidCallback? onOpenAddAlarm;
  final VoidCallback? onOpenAddHabit;

  const VoiceQuickActionFab({
    super.key,
    this.onOpenAddAlarm,
    this.onOpenAddHabit,
  });

  @override
  State<VoiceQuickActionFab> createState() => _VoiceQuickActionFabState();
}

class _VoiceQuickActionFabState extends State<VoiceQuickActionFab> {
  final SpeechService _speechService = SpeechService.instance;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  void _showQuickAssistantDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Maid Voice & Quick Assistant',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Speak or type commands like:\n• "Set alarm at 7:00 AM description Go for a morning run"\n• "Habit: Drink 2L Water"\n• "Buy groceries tomorrow"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Listening...' : 'Type or speak a command...',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: _isListening ? Colors.redAccent : colorScheme.primary,
                        ),
                        onPressed: () async {
                          if (_isListening) {
                            await _speechService.stop();
                            setModalState(() => _isListening = false);
                          } else {
                            final initOk = await _speechService.init();
                            if (initOk) {
                              setModalState(() => _isListening = true);
                              await _speechService.listen(
                                onResult: (recognizedText) {
                                  setModalState(() {
                                    _textController.text = recognizedText;
                                  });
                                },
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Preset buttons
                      Wrap(
                        spacing: 8,
                        children: [
                          if (widget.onOpenAddAlarm != null)
                            ActionChip(
                              avatar: const Icon(Icons.alarm_add_rounded, size: 18),
                              label: const Text('Alarm'),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onOpenAddAlarm!();
                              },
                            ),
                          if (widget.onOpenAddHabit != null)
                            ActionChip(
                              avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
                              label: const Text('Habit'),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onOpenAddHabit!();
                              },
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.schedule_send_rounded, size: 18, color: Colors.indigo),
                            label: const Text('Reschedule'),
                            onPressed: () {
                              Navigator.pop(context);
                              UniversalRescheduleDialog.showUniversalPicker(context);
                            },
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () async {
                          final text = _textController.text.trim();
                          if (text.isNotEmpty) {
                            final nav = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            await Provider.of<AppProvider>(context, listen: false).processQuickCapture(text);
                            _textController.clear();
                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(content: Text('Processed: "$text"')),
                            );
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('Execute'),
                      ),
                    ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FloatingActionButton(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 4,
      onPressed: _showQuickAssistantDialog,
      tooltip: 'Quick Assistant',
      child: const Icon(Icons.auto_awesome_rounded),
    );
  }
}
