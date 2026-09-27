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

  Future<void> _speakTasksOutLoud() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final result = await LocalQueryEngine.processQuery("tell my work and today's tasks", provider);
    await TtsService.instance.stop();
    await TtsService.instance.speak(result.spokenText);

    if (mounted) {
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
      body: GlassBackground(
        child: Column(
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

    // Filter tasks based on selected filter
    List<TaskItem> filteredList;
    if (_filterMode == 'today') {
      filteredList = provider.todayTasks;
    } else if (_filterMode == 'pending') {
      filteredList = provider.pendingAllTasks;
    } else if (_filterMode == 'completed') {
      filteredList = allTasks.where((t) => t.status == 'completed').toList();
    } else {
      filteredList = allTasks;
    }

    final totalCount = allTasks.length;
    final completedCount = allTasks.where((t) => t.status == 'completed').length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;
    final autoRescheduledCount = allTasks.where((t) => t.isAutoRescheduled && t.status != 'completed').length;

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

        // Auto-Rollover Info Banner (if any tasks were rolled over from yesterday)
        if (autoRescheduledCount > 0 && _filterMode == 'today')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_mode_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚡ $autoRescheduledCount uncompleted task(s) auto-rescheduled from previous days to today!',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 2. ENHANCED PRODUCTIVITY PROGRESS & STATS CARD
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.insights_rounded, color: Color(0xFF6366F1), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Productivity Tracker',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    // Motivational Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: progress == 1.0
                            ? Colors.green.withValues(alpha: 0.18)
                            : (progress >= 0.5
                                ? const Color(0xFF6366F1).withValues(alpha: 0.18)
                                : Colors.amber.withValues(alpha: 0.18)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: progress == 1.0
                              ? Colors.green.withValues(alpha: 0.4)
                              : (progress >= 0.5
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                                  : Colors.amber.withValues(alpha: 0.4)),
                        ),
                      ),
                      child: Text(
                        totalCount == 0
                            ? '🎯 No Tasks'
                            : (progress == 1.0
                                ? '🎉 All Done!'
                                : (progress >= 0.75
                                    ? '🔥 Crushing It!'
                                    : (progress >= 0.5
                                        ? '⚡ High Momentum'
                                        : '🎯 Getting Started'))),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: progress == 1.0
                              ? Colors.green
                              : (progress >= 0.5 ? const Color(0xFF6366F1) : Colors.amber.shade700),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Progress Bar with Percentage
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 1.0
                                ? const Color(0xFF10B981)
                                : (progress >= 0.5 ? const Color(0xFF6366F1) : const Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 3 Stats Pills Row (Completed, Pending, Today)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '$completedCount Done',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${totalCount - completedCount} Pending',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF6366F1), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${provider.todayTasks.length} Today',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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

        // 4. TASK ITEMS LIST (WITH TAP TO EDIT, DISMISSIBLE SWIPE & CHECKBOX)
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
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showEditTaskDialog(context, task),
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
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (task.dueDate != null) ...[
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.event_outlined, size: 12, color: theme.colorScheme.primary),
                                                const SizedBox(width: 3),
                                                Text(
                                                  task.dueDate!,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          GlassPillBadge(
                                            label: priorityLabel,
                                            color: priorityColor,
                                          ),
                                          if (task.isAutoRescheduled)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 0.8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.auto_mode_rounded, size: 10, color: Colors.amber),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    task.originalDueDate != null
                                                        ? 'Rolled over (${task.originalDueDate})'
                                                        : 'Rolled to Today',
                                                    style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Edit Task button
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF6366F1), size: 18),
                                  tooltip: 'Edit Task (Title, Due Date, Priority)',
                                  onPressed: () => _showEditTaskDialog(context, task),
                                ),
                                // Reschedule button
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.schedule_send_rounded, color: Colors.blueAccent, size: 18),
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
                                  onPressed: () {
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
                                ),
                              ],
                            ),
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
    final provider = Provider.of<AppProvider>(context, listen: false);
    final dateController = TextEditingController(text: provider.selectedDateStr);
    int priority = 2;
    bool isListening = false;

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
              child: SingleChildScrollView(
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
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        hintText: 'e.g. Solve problem, Review lecture notes',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: isListening ? Colors.redAccent : const Color(0xFF6366F1),
                          ),
                          tooltip: 'Speak Task Title (STT)',
                          onPressed: () async {
                            if (isListening) {
                              await SpeechService.instance.stop();
                              setDlgState(() => isListening = false);
                            } else {
                              setDlgState(() => isListening = true);
                              await SpeechService.instance.listen(onResult: (text) {
                                setDlgState(() {
                                  titleController.text = text;
                                });
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dateController,
                            readOnly: true,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                final formatted = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                setDlgState(() => dateController.text = formatted);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Due Date',
                              prefixIcon: const Icon(Icons.calendar_month_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final now = DateTime.now();
                            final formatted = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            setDlgState(() => dateController.text = formatted);
                          },
                          child: const Text('Today'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final tmrw = DateTime.now().add(const Duration(days: 1));
                            final formatted = "${tmrw.year.toString().padLeft(4, '0')}-${tmrw.month.toString().padLeft(2, '0')}-${tmrw.day.toString().padLeft(2, '0')}";
                            setDlgState(() => dateController.text = formatted);
                          },
                          child: const Text('Tmrw'),
                        ),
                      ],
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
                          final task = TaskItem(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            title: title,
                            dueDate: dateController.text.trim().isEmpty ? provider.selectedDateStr : dateController.text.trim(),
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
              ),
            );
          },
        );
      },
    );
  }

  void _showEditTaskDialog(BuildContext context, TaskItem task) {
    final titleController = TextEditingController(text: task.title);
    final dateController = TextEditingController(text: task.dueDate ?? '');
    int priority = task.priority;
    String status = task.status;
    bool isListening = false;

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1), size: 28),
                        const SizedBox(width: 10),
                        const Text('Edit Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          tooltip: 'Delete Task',
                          onPressed: () {
                            Provider.of<AppProvider>(context, listen: false).deleteTask(task.id);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Deleted "${task.title}"'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    Provider.of<AppProvider>(context, listen: false).addTask(task);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        hintText: 'Enter task description',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: isListening ? Colors.redAccent : const Color(0xFF6366F1),
                          ),
                          tooltip: 'Speak to edit (STT)',
                          onPressed: () async {
                            if (isListening) {
                              await SpeechService.instance.stop();
                              setDlgState(() => isListening = false);
                            } else {
                              setDlgState(() => isListening = true);
                              await SpeechService.instance.listen(onResult: (text) {
                                setDlgState(() {
                                  titleController.text = text;
                                });
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dateController,
                            readOnly: true,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                final formatted = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                setDlgState(() => dateController.text = formatted);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Due Date',
                              prefixIcon: const Icon(Icons.calendar_month_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final now = DateTime.now();
                            final formatted = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                            setDlgState(() => dateController.text = formatted);
                          },
                          child: const Text('Today'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            final tmrw = DateTime.now().add(const Duration(days: 1));
                            final formatted = "${tmrw.year.toString().padLeft(4, '0')}-${tmrw.month.toString().padLeft(2, '0')}-${tmrw.day.toString().padLeft(2, '0')}";
                            setDlgState(() => dateController.text = formatted);
                          },
                          child: const Text('Tmrw'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: priority,
                            decoration: InputDecoration(
                              labelText: 'Priority Level',
                              prefixIcon: const Icon(Icons.flag_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 3, child: Text('P1 High 🔴')),
                              DropdownMenuItem(value: 2, child: Text('P2 Med 🟡')),
                              DropdownMenuItem(value: 1, child: Text('P3 Low ⚪')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => priority = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: status,
                            decoration: InputDecoration(
                              labelText: 'Status',
                              prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                              DropdownMenuItem(value: 'completed', child: Text('✅ Completed')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => status = val);
                              }
                            },
                          ),
                        ),
                      ],
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
                          final newTitle = titleController.text.trim();
                          if (newTitle.isEmpty) return;
                          final updatedTask = task.copyWith(
                            title: newTitle,
                            dueDate: dateController.text.trim().isEmpty ? null : dateController.text.trim(),
                            priority: priority,
                            status: status,
                          );
                          Provider.of<AppProvider>(context, listen: false).updateTask(updatedTask);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Task updated: "$newTitle"')),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
