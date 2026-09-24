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
      // Default: newest first (higher id timestamp or reversed list)
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
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = cat);
                      }
                    },
                    selectedColor: const Color(0xFF6366F1),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade800),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),

            const SizedBox(height: 4),

            // Notes List or Empty State
            Expanded(
              child: filteredNotes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.edit_note_rounded,
                                size: 56,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching notes found'
                                  : 'No notes yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey.shade900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try searching with a different title or keyword.'
                                  : 'Tap + to write your first note (e.g. Shopping, Books, Grocery).',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                            if (_searchQuery.isEmpty) ...[
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showNoteEditorDialog(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Create a Note'),
                              ),
                            ],
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

                                // Note Body Preview
                                Padding(
                                  padding: const EdgeInsets.only(left: 38),
                                  child: Text(
                                    note.body.isNotEmpty ? note.body : '(Empty note content)',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      fontSize: 13.5,
                                      height: 1.4,
                                    ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Chips Row (Category, Date, Time)
                                if (note.category != null || note.date != null) ...[
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

  // --- Full Note Creator / Editor Modal ---
  void _showNoteEditorDialog(BuildContext context, {NoteItem? note}) {
    final titleController = TextEditingController(text: note?.isUntitled == true ? '' : note?.title);
    final bodyController = TextEditingController(text: note?.body);
    final dateController = TextEditingController(text: note?.date);
    final startTimeController = TextEditingController(text: note?.startTime);
    String selectedCategory = note?.category ?? 'General';

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

                    // Body Field
                    TextField(
                      controller: bodyController,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Note Content...',
                        hintText: 'e.g. books, pens, notebook, milk, bread...',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),

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

                          // If both title and body are completely empty, don't save
                          if (body.isEmpty && rawTitle.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter some text or title for the note.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          // Auto-fallback to "Untitled" if title is empty
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

  // --- Category Color Helper ---
  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'shopping':
      case 'grocery':
        return const Color(0xFF10B981);
      case 'study':
        return const Color(0xFF6366F1);
      case 'work':
        return Colors.blue;
      case 'personal':
        return Colors.purple;
      case 'ideas':
        return Colors.amber.shade700;
      default:
        return const Color(0xFF6366F1);
    }
  }

  // --- Category Icon Helper ---
  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'shopping':
      case 'grocery':
        return Icons.shopping_bag_rounded;
      case 'study':
        return Icons.menu_book_rounded;
      case 'work':
        return Icons.business_center_rounded;
      case 'personal':
        return Icons.person_rounded;
      case 'ideas':
        return Icons.lightbulb_rounded;
      default:
        return Icons.sticky_note_2_rounded;
    }
  }
}
