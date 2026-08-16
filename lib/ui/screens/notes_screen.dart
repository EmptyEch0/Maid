import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/app_models.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/animated_entry.dart';
import '../widgets/universal_reschedule_dialog.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final notes = provider.notes;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.note_alt_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Plain Notes & Checklists'),
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
      body: notes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_note_rounded, size: 64, color: isDark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No notes yet. Tap + to write your first note.', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return AnimatedEntry(
                  index: index,
                  child: GlassCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () => _showNoteEditorDialog(context, note: note),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.description_rounded, color: Color(0xFF6366F1), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title ?? 'Untitled Note',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                note.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              if (note.date != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    GlassPillBadge(
                                      label: '${note.date} ${note.startTime ?? ""}',
                                      icon: Icons.event_outlined,
                                      color: const Color(0xFF0EA5E9),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Action buttons: Reschedule & Delete
                        IconButton(
                          icon: const Icon(Icons.schedule_send_rounded, color: Color(0xFF6366F1), size: 20),
                          tooltip: 'Reschedule Note',
                          onPressed: () => UniversalRescheduleDialog.showForNote(context, note),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          tooltip: 'Delete Note',
                          onPressed: () => provider.deleteNote(note.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditorDialog(context),
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('New Note'),
      ),
    );
  }

  void _showNoteEditorDialog(BuildContext context, {NoteItem? note}) {
    final titleController = TextEditingController(text: note?.title);
    final bodyController = TextEditingController(text: note?.body);
    final dateController = TextEditingController(text: note?.date);
    final startTimeController = TextEditingController(text: note?.startTime);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
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
                    Text(
                      note == null ? 'New Note' : 'Edit Note',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title (Optional)',
                    hintText: 'e.g. Dynamic Programming Cheat Sheet',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Body text...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dateController,
                        decoration: InputDecoration(
                          labelText: 'Date (Optional)',
                          prefixIcon: const Icon(Icons.calendar_month_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: startTimeController,
                        decoration: InputDecoration(
                          labelText: 'Time (Optional)',
                          prefixIcon: const Icon(Icons.access_time_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
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
                      final body = bodyController.text.trim();
                      if (body.isEmpty) return;

                      final provider = Provider.of<AppProvider>(context, listen: false);
                      final newNote = NoteItem(
                        id: note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
                        body: body,
                        date: dateController.text.trim().isEmpty ? null : dateController.text.trim(),
                        startTime: startTimeController.text.trim().isEmpty ? null : startTimeController.text.trim(),
                      );
                      provider.addNote(newNote);
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save Note'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
