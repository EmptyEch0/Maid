import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import 'progress_ring.dart';

/// Tickable checklist inside a note. Items whose text starts with "## " are section headings
/// (tap a heading to fold it). Ticks save immediately. Long-press an item to delete it.
class NoteChecklist extends StatefulWidget {
  final String noteId;
  const NoteChecklist({super.key, required this.noteId});

  @override
  State<NoteChecklist> createState() => _NoteChecklistState();
}

class _NoteChecklistState extends State<NoteChecklist> {
  static const _accent = Color(0xFF6366F1);
  List<ChecklistItem> _items = [];
  final Set<String> _folded = {};
  final _addController = TextEditingController();
  bool _loaded = false;

  AppProvider get _provider => Provider.of<AppProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _provider.getChecklist(widget.noteId);
    if (mounted) {
      setState(() {
        _items = list;
        _loaded = true;
      });
    }
  }

  bool _isHeading(ChecklistItem i) => i.text.startsWith('## ');

  Future<void> _toggle(ChecklistItem item) async {
    setState(() => _items = [for (final i in _items) i.id == item.id ? i.copyWith(isDone: !i.isDone) : i]);
    await _provider.toggleChecklistItem(item);
  }

  Future<void> _add() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    _addController.clear();
    final nextOrder = _items.isEmpty ? 0 : _items.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await _provider.addChecklistItem(ChecklistItem(
      id: 'ck_${DateTime.now().microsecondsSinceEpoch}',
      parentId: widget.noteId,
      parentType: 'note',
      text: text,
      sortOrder: nextOrder,
    ));
    await _load();
  }

  Future<void> _confirmDelete(ChecklistItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(_isHeading(item) ? item.text.substring(3) : item.text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _provider.deleteChecklistItem(item);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final tasks = _items.where((i) => !_isHeading(i)).toList();
    final done = tasks.where((i) => i.isDone).length;

    // Group items under their heading so each section can show its own progress.
    final rows = <Widget>[];
    String? currentHeading;
    for (var idx = 0; idx < _items.length; idx++) {
      final item = _items[idx];
      if (_isHeading(item)) {
        currentHeading = item.id;
        final section = <ChecklistItem>[];
        for (var j = idx + 1; j < _items.length && !_isHeading(_items[j]); j++) {
          section.add(_items[j]);
        }
        final sectionDone = section.where((i) => i.isDone).length;
        final folded = _folded.contains(item.id);
        final complete = section.isNotEmpty && sectionDone == section.length;
        rows.add(InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => folded ? _folded.remove(item.id) : _folded.add(item.id)),
          onLongPress: () => _confirmDelete(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
            child: Row(
              children: [
                Icon(folded ? Icons.chevron_right_rounded : Icons.expand_more_rounded, size: 20, color: _accent),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.text.substring(3),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (complete ? const Color(0xFF10B981) : _accent).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$sectionDone/${section.length}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: complete ? const Color(0xFF10B981) : _accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
        continue;
      }
      if (currentHeading != null && _folded.contains(currentHeading)) continue;
      rows.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _toggle(item),
        onLongPress: () => _confirmDelete(item),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.isDone,
              activeColor: const Color(0xFF10B981),
              visualDensity: VisualDensity.compact,
              onChanged: (_) => _toggle(item),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 11, bottom: 6),
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 13.5,
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                    color: item.isDone ? muted : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (tasks.isNotEmpty) ...[
                ProgressRing(done: done, total: tasks.length, size: 64, strokeWidth: 7),
                const SizedBox(width: 14),
              ] else ...[
                const Icon(Icons.checklist_rounded, color: _accent, size: 20),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (tasks.isNotEmpty)
                      Text('$done of ${tasks.length} done · ${tasks.length - done} to go',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
                  ],
                ),
              ),
            ],
          ),
          ...rows,
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: 'Add an item (start with "## " for a heading)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded, color: _accent),
                tooltip: 'Add item',
                onPressed: _add,
              ),
            ],
          ),
          Text('Tap to tick · long-press to delete · tap a heading to fold it',
              style: TextStyle(fontSize: 10.5, color: muted)),
        ],
      ),
    );
  }
}
