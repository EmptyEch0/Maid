import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../engine/note_link_engine.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../widgets/animated_entry.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/linked_text_editor.dart';
import '../widgets/note_graph_modal.dart';
import '../widgets/universal_reschedule_dialog.dart';
import 'notes_graph_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'title'

  final List<String> _categories = [
    'All',
    'Shopping',
    'Grocery',
    'Study',
    'Work',
    'Personal',
    'Ideas',
  ];

  final List<String> _titleSuggestions = [
    'Shopping',
    'Grocery',
    'Books & Stationary',
    'Study Notes',
    'Work Tasks',
    'Ideas',
    'Quick List',
  ];

  Color _getCategoryColor(String? category) {
    return NoteLinkEngine.getCategoryColor(category);
  }

  IconData _getCategoryIcon(String? category) {
    return NoteLinkEngine.getCategoryIcon(category, LinkEntityType.note);
  }

  void _handleLinkTap(BuildContext context, ExtractedLink link) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final allNotes = provider.notes;

    if (link.entityType == LinkEntityType.note) {
      final targetNote = NoteLinkEngine.findMatchingNote(link.targetName, allNotes);
      if (targetNote != null) {
        _showNoteEditorDialog(context, note: targetNote);
      } else {
        // Quick Create Prompt
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Text('✨', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('Create Linked Note?'),
              ],
            ),
            content: Text(
              'Note "${link.targetName}" does not exist yet. Would you like to create it now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create & Open'),
                onPressed: () {
                  Navigator.pop(ctx);
                  final newNote = NoteItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: link.targetName,
                    body: '',
                    category: 'General',
                  );
                  provider.addNote(newNote);
                  _showNoteEditorDialog(context, note: newNote);
                },
              ),
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linked to ${link.entityType.name.toUpperCase()}: ${link.targetName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final allNotes = provider.notes;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter notes based on category and search query
    List<NoteItem> filteredNotes = allNotes.where((note) {
      final matchesCategory = _selectedCategory == 'All' ||
          (note.category?.toLowerCase() == _selectedCategory.toLowerCase());

      final titleStr = (note.title ?? 'Untitled').toLowerCase();
      final bodyStr = note.body.toLowerCase();
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          titleStr.contains(query) ||
          bodyStr.contains(query);

      return matchesCategory && matchesSearch;
    }).toList();

    // Sort notes
    if (_sortBy == 'title') {
      filteredNotes.sort((a, b) => a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase()));
    } else if (_sortBy == 'oldest') {
      filteredNotes.sort((a, b) => a.id.compareTo(b.id));
    } else {
      // Default: newest first
      filteredNotes.sort((a, b) => b.id.compareTo(a.id));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.note_alt_rounded, color: Color(0xFF6366F1), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Notes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            if (allNotes.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${allNotes.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Mindmap Graph View Trigger (Obsidian-Style)
          IconButton(
            icon: const Text('🕸️', style: TextStyle(fontSize: 20)),
            tooltip: 'Mindmap Knowledge Graph',
            onPressed: _openGraphScreen,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort notes',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'newest',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 18, color: _sortBy == 'newest' ? colorScheme.primary : null),
                    const SizedBox(width: 8),
                    Text('Newest First', style: TextStyle(fontWeight: _sortBy == 'newest' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'oldest',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward_rounded, size: 18, color: _sortBy == 'oldest' ? colorScheme.primary : null),
                    const SizedBox(width: 8),
                    Text('Oldest First', style: TextStyle(fontWeight: _sortBy == 'oldest' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'title',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha_rounded, size: 18, color: _sortBy == 'title' ? colorScheme.primary : null),
                    const SizedBox(width: 8),
                    Text('Title (A-Z)', style: TextStyle(fontWeight: _sortBy == 'title' ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Reschedule Anything',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
        ],
      ),
      body: GlassBackground(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search notes by title or content...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6366F1)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            // Category Filter Chips
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final isSelected = _selectedCategory == cat;
                  final catColor = _getCategoryColor(cat);

                  return FilterChip(
                    selected: isSelected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat != 'All') ...[
                          Icon(
                            _getCategoryIcon(cat),
                            size: 13,
                            color: isSelected ? Colors.white : catColor,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(cat),
                      ],
                    ),
                    onSelected: (val) => setState(() => _selectedCategory = cat),
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),

            // Note List
            Expanded(
              child: filteredNotes.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.note_alt_outlined,
                                size: 56,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching notes found'
                                  : (_selectedCategory != 'All'
                                      ? 'No notes in "$_selectedCategory"'
                                      : 'No notes created yet'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try searching with different keywords.'
                                  : 'Tap + to write your first note or type //topic to link ideas into a mindmap.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showNoteEditorDialog(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Create a Note'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        final isUntitled = note.isUntitled;

                        // Calculate links for indicator
                        final outgoingLinks = NoteLinkEngine.extractLinks(note.body);
                        final backlinks = NoteLinkEngine.findBacklinks(note, allNotes);
                        final totalConnections = outgoingLinks.length + backlinks.length;

                        return AnimatedEntry(
                          index: index,
                          child: GlassCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            onTap: () => _showNoteEditorDialog(context, note: note),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and Header Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(note.category).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _getCategoryIcon(note.category),
                                        color: _getCategoryColor(note.category),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              note.displayTitle,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isUntitled
                                                    ? (isDark ? Colors.white60 : Colors.grey.shade600)
                                                    : (isDark ? Colors.white : Colors.grey.shade900),
                                                fontStyle: isUntitled ? FontStyle.italic : FontStyle.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isUntitled) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Untitled',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Local Graph Preview Button
                                    IconButton(
                                      icon: const Text('🧠', style: TextStyle(fontSize: 16)),
                                      tooltip: 'View Connected Graph',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => NoteLocalGraphModal.show(
                                        context,
                                        note: note,
                                        allNotes: allNotes,
                                        onNavigateToNote: (target) => _showNoteEditorDialog(context, note: target),
                                      ),
                                    ),
                                    // Quick Title Rename Button
                                    IconButton(
                                      icon: const Icon(Icons.drive_file_rename_outline_rounded, size: 20),
                                      color: const Color(0xFF6366F1),
                                      tooltip: 'Rename Title',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showRenameDialog(context, note: note),
                                    ),
                                    // Reschedule Note
                                    IconButton(
                                      icon: const Icon(Icons.schedule_send_rounded, size: 20),
                                      color: const Color(0xFF6366F1),
                                      tooltip: 'Reschedule Note',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => UniversalRescheduleDialog.showForNote(context, note),
                                    ),
                                    // Delete Note
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                      color: Colors.redAccent,
                                      tooltip: 'Delete Note',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _confirmDeleteNote(context, note),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Note Body Preview with Clickable Links
                                Padding(
                                  padding: const EdgeInsets.only(left: 38),
                                  child: note.body.isNotEmpty
                                      ? LinkedNoteBodyViewer(
                                          text: note.body,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          onLinkTap: (link) => _handleLinkTap(context, link),
                                        )
                                      : Text(
                                          '(Empty note content)',
                                          style: TextStyle(
                                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                                            fontSize: 13.5,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                ),

                                // Chips Row (Category, Graph Status, Date, Time)
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(left: 38),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      if (note.category != null && note.category!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getCategoryColor(note.category).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_getCategoryIcon(note.category), size: 12, color: _getCategoryColor(note.category)),
                                              const SizedBox(width: 4),
                                              Text(
                                                note.category!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _getCategoryColor(note.category),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Mindmap Connection Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: totalConnections > 0
                                              ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                                              : (isDark ? Colors.white10 : Colors.grey.shade200),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              totalConnections > 0 ? '🔗' : '🏝️',
                                              style: const TextStyle(fontSize: 10),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              totalConnections > 0
                                                  ? '$totalConnections connection${totalConnections > 1 ? "s" : ""}'
                                                  : 'Lone note',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: totalConnections > 0
                                                    ? const Color(0xFF6366F1)
                                                    : (isDark ? Colors.white60 : Colors.grey.shade600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      if (note.date != null && note.date!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${note.date!}${note.startTime != null && note.startTime!.isNotEmpty ? " • ${note.startTime}" : ""}',
                                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteEditorDialog(context),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('New Note', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _openGraphScreen() async {
    final selectedNote = await Navigator.push<NoteItem?>(
      context,
      MaterialPageRoute(builder: (_) => const NotesGraphScreen()),
    );
    if (!mounted) return;
    if (selectedNote != null) {
      _showNoteEditorDialog(context, note: selectedNote);
    }
  }

  // --- Quick Title Rename Dialog ---
  void _showRenameDialog(BuildContext context, {required NoteItem note}) {
    final titleController = TextEditingController(text: note.isUntitled ? '' : note.title);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.drive_file_rename_outline_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Rename Title', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Give your note a recognizable title (e.g. Grocery, Shopping, Books):',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Note Title',
                    hintText: 'e.g. Grocery, Shopping, Work...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => titleController.clear(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Quick Suggestions:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _titleSuggestions.map((suggestion) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        titleController.text = suggestion;
                        titleController.selection = TextSelection.fromPosition(
                          TextPosition(offset: suggestion.length),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          suggestion,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final newTitle = titleController.text.trim();
                final provider = Provider.of<AppProvider>(context, listen: false);
                provider.updateNoteTitle(note.id, newTitle.isEmpty ? 'Untitled' : newTitle);
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Note renamed to "${newTitle.isEmpty ? 'Untitled' : newTitle}"'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Save Title'),
            ),
          ],
        );
      },
    );
  }

  // --- Confirm Delete Note ---
  void _confirmDeleteNote(BuildContext context, NoteItem note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Note?'),
        content: Text('Are you sure you want to delete "${note.displayTitle}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              final provider = Provider.of<AppProvider>(context, listen: false);
              provider.deleteNote(note.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Note deleted'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- Full Note Creator / Editor Modal with Linking & Graph ---
  void _showNoteEditorDialog(BuildContext context, {NoteItem? note}) {
    final titleController = TextEditingController(text: note?.isUntitled == true ? '' : note?.title);
    final bodyController = LinkedTextEditingController(text: note?.body);
    final dateController = TextEditingController(text: note?.date);
    final startTimeController = TextEditingController(text: note?.startTime);
    String selectedCategory = note?.category ?? 'General';

    String linkQuery = '';
    bool showAutocomplete = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final provider = Provider.of<AppProvider>(context, listen: false);
            final allNotes = provider.notes;

            // Check outgoing and backlinks for this note
            final outgoingLinks = NoteLinkEngine.extractLinks(bodyController.text);
            final backlinks = note != null ? NoteLinkEngine.findBacklinks(note, allNotes) : <NoteItem>[];

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
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1), size: 26),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          note == null ? 'New Note' : 'Edit Note',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (note != null) ...[
                          // Mini Graph Button
                          IconButton(
                            icon: const Text('🧠', style: TextStyle(fontSize: 20)),
                            tooltip: 'Local Knowledge Map',
                            onPressed: () {
                              NoteLocalGraphModal.show(
                                context,
                                note: note,
                                allNotes: allNotes,
                                onNavigateToNote: (target) {
                                  Navigator.pop(ctx);
                                  _showNoteEditorDialog(context, note: target);
                                },
                              );
                            },
                          ),
                          IconButton(
                            icon: const Text('🕸️', style: TextStyle(fontSize: 20)),
                            tooltip: 'Explore Full Graph',
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotesGraphScreen(
                                    initialFocusNoteId: note.id,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Title Field
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Title (e.g. Grocery, Shopping, Books)',
                        hintText: 'Leave empty for "Untitled"',
                        prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF6366F1)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Quick Title Suggestion Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _titleSuggestions.map((suggestion) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setModalState(() {
                              titleController.text = suggestion;
                              if (suggestion.toLowerCase().contains('shop') || suggestion.toLowerCase().contains('groc')) {
                                selectedCategory = 'Shopping';
                              } else if (suggestion.toLowerCase().contains('study') || suggestion.toLowerCase().contains('book')) {
                                selectedCategory = 'Study';
                              } else if (suggestion.toLowerCase().contains('work')) {
                                selectedCategory = 'Work';
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
                            ),
                            child: Text(
                              suggestion,
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // Autocomplete suggestion strip when typing // or [[
                    if (showAutocomplete)
                      NoteAutocompleteStrip(
                        query: linkQuery,
                        existingNotes: allNotes,
                        onSuggestionSelected: (selectedTitle, type) {
                          setModalState(() {
                            final currentText = bodyController.text;
                            final cursor = bodyController.selection.baseOffset;
                            
                            // Replace partial trigger with completed //link
                            final lastSlash = currentText.lastIndexOf('//', cursor > 0 ? cursor - 1 : 0);
                            final lastWiki = currentText.lastIndexOf('[[', cursor > 0 ? cursor - 1 : 0);
                            final triggerPos = lastSlash > lastWiki ? lastSlash : lastWiki;

                            if (triggerPos != -1) {
                              final before = currentText.substring(0, triggerPos);
                              final after = cursor <= currentText.length ? currentText.substring(cursor) : '';
                              final insertText = '//$selectedTitle ';
                              bodyController.text = '$before$insertText$after';
                              bodyController.selection = TextSelection.fromPosition(
                                TextPosition(offset: (before + insertText).length),
                              );
                            } else {
                              bodyController.text = '$currentText //$selectedTitle ';
                            }
                            showAutocomplete = false;
                          });
                        },
                      ),

                    // Body Field with Real-Time Link Highlighting
                    TextField(
                      controller: bodyController,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (val) {
                        final cursor = bodyController.selection.baseOffset;
                        if (cursor > 0) {
                          final textBeforeCursor = val.substring(0, cursor);
                          final slashIdx = textBeforeCursor.lastIndexOf('//');
                          final wikiIdx = textBeforeCursor.lastIndexOf('[[');

                          final lastTrigger = slashIdx > wikiIdx ? slashIdx : wikiIdx;
                          if (lastTrigger != -1 && (cursor - lastTrigger) <= 25) {
                            final q = textBeforeCursor.substring(lastTrigger + (slashIdx > wikiIdx ? 2 : 2));
                            if (!q.contains('\n') && !q.contains('  ')) {
                              setModalState(() {
                                linkQuery = q;
                                showAutocomplete = true;
                              });
                              return;
                            }
                          }
                        }
                        if (showAutocomplete) {
                          setModalState(() => showAutocomplete = false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Note Content...',
                        hintText: 'Type //topic or [[topic]] to link notes into a Mindmap...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Helpful Hint / Trigger Shortcuts
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Type //topic, //task:Name, or //dsa:Topic to connect ideas.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            setModalState(() {
                              final text = bodyController.text;
                              bodyController.text = '$text //';
                              bodyController.selection = TextSelection.fromPosition(
                                TextPosition(offset: bodyController.text.length),
                              );
                              linkQuery = '';
                              showAutocomplete = true;
                            });
                          },
                          child: const Text('+ Add //Link', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),

                    // Backlinks & Mentioned Notes List (if editing an existing note)
                    if (backlinks.isNotEmpty || outgoingLinks.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (outgoingLinks.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.arrow_outward_rounded, size: 14, color: Color(0xFF6366F1)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Mentions (${outgoingLinks.length})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: outgoingLinks.map((l) {
                                  return ActionChip(
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    label: Text(l.targetName, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => _handleLinkTap(context, l),
                                  );
                                }).toList(),
                              ),
                            ],
                            if (backlinks.isNotEmpty) ...[
                              if (outgoingLinks.isNotEmpty) const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.south_west_rounded, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Referenced by (${backlinks.length})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: backlinks.map((bl) {
                                  return ActionChip(
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    avatar: const Icon(Icons.link_rounded, size: 12, color: Color(0xFF10B981)),
                                    label: Text(bl.displayTitle, style: const TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _showNoteEditorDialog(context, note: bl);
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Category Selector
                    const Text('Category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['General', 'Shopping', 'Grocery', 'Study', 'Work', 'Personal', 'Ideas'].map((cat) {
                          final isSel = selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSel,
                              onSelected: (val) {
                                if (val) setModalState(() => selectedCategory = cat);
                              },
                              selectedColor: const Color(0xFF6366F1),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                fontSize: 11.5,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              ),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Schedule Date & Time Row (Interactive Pickers)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                final y = picked.year.toString().padLeft(4, '0');
                                final m = picked.month.toString().padLeft(2, '0');
                                final d = picked.day.toString().padLeft(2, '0');
                                setModalState(() => dateController.text = '$y-$m-$d');
                              }
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: dateController,
                                decoration: InputDecoration(
                                  labelText: 'Date (Optional)',
                                  hintText: 'YYYY-MM-DD',
                                  prefixIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (pickedTime != null) {
                                final h = pickedTime.hour.toString().padLeft(2, '0');
                                final min = pickedTime.minute.toString().padLeft(2, '0');
                                setModalState(() => startTimeController.text = '$h:$min');
                              }
                            },
                            child: IgnorePointer(
                              child: TextField(
                                controller: startTimeController,
                                decoration: InputDecoration(
                                  labelText: 'Time (Optional)',
                                  hintText: 'HH:MM',
                                  prefixIcon: const Icon(Icons.access_time_rounded, color: Color(0xFF6366F1)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (dateController.text.isNotEmpty || startTimeController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            tooltip: 'Clear schedule',
                            onPressed: () {
                              setModalState(() {
                                dateController.clear();
                                startTimeController.clear();
                              });
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: () {
                          final body = bodyController.text.trim();
                          final rawTitle = titleController.text.trim();

                          if (body.isEmpty && rawTitle.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter some text or title for the note.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          final finalTitle = rawTitle.isEmpty ? 'Untitled' : rawTitle;
                          final provider = Provider.of<AppProvider>(context, listen: false);
                          final newNote = NoteItem(
                            id: note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                            title: finalTitle,
                            body: body,
                            category: selectedCategory,
                            date: dateController.text.trim().isEmpty ? null : dateController.text.trim(),
                            startTime: startTimeController.text.trim().isEmpty ? null : startTimeController.text.trim(),
                          );

                          provider.addNote(newNote);
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Note "$finalTitle" saved successfully!'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: Text(
                          note == null ? 'Save Note' : 'Update Note',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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
