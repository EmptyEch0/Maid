import 'package:flutter/material.dart';
import '../../engine/note_link_engine.dart';
import '../../models/app_models.dart';
import '../screens/notes_graph_screen.dart';

/// Interactive modal sheet showing the local network graph of a single note and its neighbors
class NoteLocalGraphModal extends StatelessWidget {
  final NoteItem currentNote;
  final List<NoteItem> allNotes;
  final Function(NoteItem targetNote)? onNavigateToNote;

  const NoteLocalGraphModal({
    super.key,
    required this.currentNote,
    required this.allNotes,
    this.onNavigateToNote,
  });

  static void show(
    BuildContext context, {
    required NoteItem note,
    required List<NoteItem> allNotes,
    Function(NoteItem targetNote)? onNavigateToNote,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => NoteLocalGraphModal(
        currentNote: note,
        allNotes: allNotes,
        onNavigateToNote: onNavigateToNote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outgoingLinks = NoteLinkEngine.extractLinks(currentNote.body);
    final backlinks = NoteLinkEngine.findBacklinks(currentNote, allNotes);

    // Resolved outgoing note objects
    final outgoingNotes = <NoteItem>[];
    for (final l in outgoingLinks) {
      if (l.entityType == LinkEntityType.note) {
        final match = NoteLinkEngine.findMatchingNote(l.targetName, allNotes);
        if (match != null && !outgoingNotes.any((n) => n.id == match.id)) {
          outgoingNotes.add(match);
        }
      }
    }

    final totalConnections = outgoingNotes.length + backlinks.length;

    return Container(
      padding: const EdgeInsets.all(24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🧠', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentNote.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$totalConnections connected note${totalConnections == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded),
                tooltip: 'Open in Full Graph View',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotesGraphScreen(
                        initialFocusNoteId: currentNote.id,
                        isLocalMode: true,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Outgoing Links Section
          if (outgoingNotes.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.arrow_outward_rounded, size: 16, color: Color(0xFF6366F1)),
                SizedBox(width: 6),
                Text(
                  'Outgoing Links (Mentions)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: outgoingNotes.map((note) {
                final catColor = NoteLinkEngine.getCategoryColor(note.category);
                return ActionChip(
                  backgroundColor: catColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  side: BorderSide(color: catColor.withValues(alpha: 0.35)),
                  avatar: Icon(
                    NoteLinkEngine.getCategoryIcon(note.category, LinkEntityType.note),
                    size: 14,
                    color: catColor,
                  ),
                  label: Text(
                    note.displayTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (onNavigateToNote != null) {
                      onNavigateToNote!(note);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Backlinks Section
          if (backlinks.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.south_west_rounded, size: 16, color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Text(
                  'Backlinks (Linked From)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: backlinks.map((note) {
                final catColor = NoteLinkEngine.getCategoryColor(note.category);
                return ActionChip(
                  backgroundColor: catColor.withValues(alpha: isDark ? 0.18 : 0.1),
                  side: BorderSide(color: catColor.withValues(alpha: 0.35)),
                  avatar: Icon(
                    Icons.link_rounded,
                    size: 14,
                    color: catColor,
                  ),
                  label: Text(
                    note.displayTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (onNavigateToNote != null) {
                      onNavigateToNote!(note);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          if (outgoingNotes.isEmpty && backlinks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Text('🏝️', style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    const Text(
                      'Lone / Isolated Note',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type //another note or [[topic]] inside the body to connect it to your knowledge network!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Spacer(),

          // Full View Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Text('🕸️', style: TextStyle(fontSize: 18)),
              label: const Text(
                'Explore in Full Mindmap Graph',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotesGraphScreen(
                      initialFocusNoteId: currentNote.id,
                      isLocalMode: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
