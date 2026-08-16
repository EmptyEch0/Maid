import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/app_models.dart';
import '../../services/speech_service.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/animated_entry.dart';
import '../widgets/universal_reschedule_dialog.dart';

class TasksInboxScreen extends StatefulWidget {
  const TasksInboxScreen({super.key});

  @override
  State<TasksInboxScreen> createState() => _TasksInboxScreenState();
}

class _TasksInboxScreenState extends State<TasksInboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _quickCaptureController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickCaptureController.dispose();
    super.dispose();
  }

  void _onQuickCaptureSubmit() {
    final text = _quickCaptureController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.processQuickCapture(text);
    _quickCaptureController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quick capture processed & saved! 🚀')),
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
            Icon(Icons.task_alt_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Tasks & Quick Inbox'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Reschedule Anything',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('Tasks (${provider.tasks.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('Inbox Log (${provider.inboxItems.length})'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Frosted Glass NLP Quick Capture Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              borderRadius: 24,
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _quickCaptureController,
                      onSubmitted: (_) => _onQuickCaptureSubmit(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. "Math study tomorrow 4pm", "Set alarm 7am"',
                        hintStyle: TextStyle(fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      SpeechService.instance.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: SpeechService.instance.isListening ? Colors.redAccent : colorScheme.primary,
                    ),
                    onPressed: () async {
                      if (SpeechService.instance.isListening) {
                        await SpeechService.instance.stop();
                        setState(() {});
                      } else {
                        await SpeechService.instance.listen(onResult: (text) {
                          setState(() {
                            _quickCaptureController.text = text;
                          });
                        });
                        setState(() {});
                      }
                    },
                  ),
                  IconButton.filled(
                    onPressed: _onQuickCaptureSubmit,
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Tasks List
                _buildTasksList(context, provider, isDark),
                // TAB 2: Quick Inbox Log
                _buildInboxList(context, provider, isDark),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildTasksList(BuildContext context, AppProvider provider, bool isDark) {
    final tasks = provider.tasks;
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No tasks found. Create one above!', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isCompleted = task.status == 'completed';

        Color priorityColor = Colors.grey;
        String priorityLabel = 'P3';
        if (task.priority == 3) {
          priorityColor = Colors.redAccent;
          priorityLabel = 'P1 High';
        } else if (task.priority == 2) {
          priorityColor = Colors.orangeAccent;
          priorityLabel = 'P2 Med';
        }

        return AnimatedEntry(
          index: index,
          child: GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Checkbox(
                  value: isCompleted,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (_) => provider.toggleTaskStatus(task),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? (isDark ? Colors.white38 : Colors.grey) : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (task.dueDate != null) ...[
                            Icon(Icons.event_outlined, size: 13, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              task.dueDate!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          GlassPillBadge(
                            label: priorityLabel,
                            color: priorityColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Direct Quick Reschedule Button
                IconButton(
                  icon: const Icon(Icons.schedule_send_rounded, color: Color(0xFF6366F1), size: 20),
                  tooltip: 'Reschedule Task Due Date',
                  onPressed: () {
                    UniversalRescheduleDialog.showForTask(context, task);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  tooltip: 'Delete Task',
                  onPressed: () => provider.deleteTask(task.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInboxList(BuildContext context, AppProvider provider, bool isDark) {
    final inbox = provider.inboxItems;
    if (inbox.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('Inbox is clean! Capture thoughts anytime.', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: inbox.length,
      itemBuilder: (context, index) {
        final item = inbox[index];
        return AnimatedEntry(
          index: index,
          child: GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notes_rounded, color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Captured: ${item.createdAt.split('T').first}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final dateController = TextEditingController(
      text: Provider.of<AppProvider>(context, listen: false).selectedDateStr,
    );
    int priority = 2;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
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
                  Row(
                    children: [
                      const Icon(Icons.add_task_rounded, color: Color(0xFF6366F1), size: 28),
                      const SizedBox(width: 10),
                      const Text('Add New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'e.g. Solve LeetCode DP problem, Review lecture notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                      labelText: 'Due Date (YYYY-MM-DD)',
                      prefixIcon: const Icon(Icons.calendar_month_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: priority,
                    decoration: InputDecoration(
                      labelText: 'Priority Level',
                      prefixIcon: const Icon(Icons.flag_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('P1 - High Priority 🔴')),
                      DropdownMenuItem(value: 2, child: Text('P2 - Medium Priority 🟡')),
                      DropdownMenuItem(value: 1, child: Text('P3 - Low Priority ⚪')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => priority = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        final title = titleController.text.trim();
                        if (title.isEmpty) return;
                        final provider = Provider.of<AppProvider>(context, listen: false);
                        final task = TaskItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          dueDate: dateController.text.trim(),
                          priority: priority,
                        );
                        provider.addTask(task);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Save Task'),
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
}
