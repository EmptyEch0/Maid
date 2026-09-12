import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/app_models.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import '../../engine/local_query_engine.dart';
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
  final TextEditingController _topAddController = TextEditingController();
  String _filterMode = 'today'; // 'today', 'pending', 'all', 'completed'
  int _selectedPriority = 2; // 3 = High, 2 = Med, 1 = Low

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickCaptureController.dispose();
    _topAddController.dispose();
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

  void _quickAddTopTask() {
    final text = _topAddController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final task = TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: text,
      dueDate: provider.selectedDateStr,
      priority: _selectedPriority,
    );
    provider.addTask(task);
    _topAddController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Task added: "$text"')),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _speakTasksOutLoud() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final result = LocalQueryEngine.processQuery("tell my work and today's tasks", provider);
    TtsService.instance.stop().then((_) {
      TtsService.instance.speak(result.spokenText);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(result.spokenText)),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
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
            Icon(Icons.task_alt_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Tasks & To-Do List'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.record_voice_over_rounded, color: Color(0xFF4F46E5)),
            tooltip: 'Tell My Work & Read Tasks Out Loud (TTS)',
            onPressed: _speakTasksOutLoud,
          ),
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
                  const Icon(Icons.checklist_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('To-Do List (${provider.tasks.length})'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              borderRadius: 20,
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _quickCaptureController,
                      onSubmitted: (_) => _onQuickCaptureSubmit(),
                      decoration: const InputDecoration(
                        hintText: 'Smart capture: "Study math tomorrow 4pm", "Set alarm 7am"',
                        hintStyle: TextStyle(fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      SpeechService.instance.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: SpeechService.instance.isListening ? Colors.redAccent : colorScheme.primary,
                      size: 20,
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
                    icon: const Icon(Icons.send_rounded, size: 16),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Top To-Do List
                _buildTopTodoList(context, provider, isDark),
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
        label: const Text('Detailed Task'),
      ),
    );
  }

  Widget _buildTopTodoList(BuildContext context, AppProvider provider, bool isDark) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allTasks = provider.tasks;
    final todayStr = provider.selectedDateStr;

    // Filter tasks based on selected filter
    List<TaskItem> filteredList;
    if (_filterMode == 'today') {
      filteredList = allTasks.where((t) => t.dueDate == null || t.dueDate == todayStr).toList();
    } else if (_filterMode == 'pending') {
      filteredList = allTasks.where((t) => t.status != 'completed').toList();
    } else if (_filterMode == 'completed') {
      filteredList = allTasks.where((t) => t.status == 'completed').toList();
    } else {
      filteredList = allTasks;
    }

    final totalCount = allTasks.length;
    final completedCount = allTasks.where((t) => t.status == 'completed').length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Column(
      children: [
        // 1. TOP INSTANT ADD TASK BAR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    const Text('Top To-Do Fast Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    // Priority selector chips
                    Wrap(
                      spacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('P1 🔴', style: TextStyle(fontSize: 10)),
                          selected: _selectedPriority == 3,
                          onSelected: (val) {
                            if (val) setState(() => _selectedPriority = 3);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        ChoiceChip(
                          label: const Text('P2 🟡', style: TextStyle(fontSize: 10)),
                          selected: _selectedPriority == 2,
                          onSelected: (val) {
                            if (val) setState(() => _selectedPriority = 2);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                        ChoiceChip(
                          label: const Text('P3 ⚪', style: TextStyle(fontSize: 10)),
                          selected: _selectedPriority == 1,
                          onSelected: (val) {
                            if (val) setState(() => _selectedPriority = 1);
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topAddController,
                        onSubmitted: (_) => _quickAddTopTask(),
                        decoration: InputDecoration(
                          hintText: 'Type task title and press enter...',
                          hintStyle: const TextStyle(fontSize: 13),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _quickAddTopTask,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      tooltip: 'Instant Add Task',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 2. PROGRESS & STATS HEADER BAR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Task Progress: $completedCount of $totalCount completed (${(progress * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        InkWell(
                          onTap: _speakTasksOutLoud,
                          child: const Row(
                            children: [
                              Icon(Icons.volume_up_rounded, size: 14, color: Color(0xFF6366F1)),
                              SizedBox(width: 4),
                              Text('Tell My Work', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. FILTER CHIPS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text("Today's Tasks (${provider.todayTasks.length})"),
                  selected: _filterMode == 'today',
                  onSelected: (val) {
                    if (val) setState(() => _filterMode = 'today');
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: Text("Pending (${provider.pendingAllTasks.length})"),
                  selected: _filterMode == 'pending',
                  onSelected: (val) {
                    if (val) setState(() => _filterMode = 'pending');
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: Text("All Tasks ($totalCount)"),
                  selected: _filterMode == 'all',
                  onSelected: (val) {
                    if (val) setState(() => _filterMode = 'all');
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: Text("Completed ($completedCount)"),
                  selected: _filterMode == 'completed',
                  onSelected: (val) {
                    if (val) setState(() => _filterMode = 'completed');
                  },
                ),
              ],
            ),
          ),
        ),

        // 4. TASK ITEMS LIST (WITH DISMISSIBLE SWIPE & CHECKBOX)
        Expanded(
          child: filteredList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 56, color: isDark ? Colors.white24 : Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          _filterMode == 'today'
                              ? 'No tasks due for today! Add one above.'
                              : (_filterMode == 'pending'
                                  ? '🎉 All caught up! No pending tasks.'
                                  : 'No tasks found in this view.'),
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final task = filteredList[index];
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

                    return Dismissible(
                      key: Key(task.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                      onDismissed: (_) {
                        final removedTask = task;
                        provider.deleteTask(task.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted "${removedTask.title}"'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => provider.addTask(removedTask),
                            ),
                          ),
                        );
                      },
                      child: AnimatedEntry(
                        index: index,
                        child: GlassCard(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              // Checkbox to check/uncheck tasks
                              Checkbox(
                                value: isCompleted,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                onChanged: (_) => provider.toggleTaskStatus(task),
                              ),
                              const SizedBox(width: 4),
                              // Task details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                        color: isCompleted ? (isDark ? Colors.white38 : Colors.grey) : null,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        if (task.dueDate != null) ...[
                                          Icon(Icons.event_outlined, size: 12, color: theme.colorScheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            task.dueDate!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
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
                              // Reschedule button
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.schedule_send_rounded, color: Color(0xFF6366F1), size: 18),
                                tooltip: 'Reschedule Task Due Date',
                                onPressed: () {
                                  UniversalRescheduleDialog.showForTask(context, task);
                                },
                              ),
                              // Delete button
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                tooltip: 'Delete Task',
                                onPressed: () => provider.deleteTask(task.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
                      const Text('Add Detailed Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Task Title',
                      hintText: 'e.g. Solve problem, Review lecture notes',
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
