import 'package:flutter/material.dart';
import '../../engine/note_link_engine.dart';
import '../../models/app_models.dart';

/// A custom TextEditingController that highlights inline note links (`//topic` or `[[topic]]`)
class LinkedTextEditingController extends TextEditingController {
  final Color linkColor;
  final Color? linkBackgroundColor;

  LinkedTextEditingController({
    super.text,
    this.linkColor = const Color(0xFF6366F1),
    this.linkBackgroundColor,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final defaultStyle = style ?? const TextStyle(fontSize: 15);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actualLinkBg = linkBackgroundColor ??
        (isDark
            ? const Color(0xFF6366F1).withValues(alpha: 0.22)
            : const Color(0xFF6366F1).withValues(alpha: 0.12));

    final actualLinkColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);

    final String fullText = text;
    if (fullText.isEmpty) {
      return TextSpan(text: '', style: defaultStyle);
    }

    final List<TextSpan> children = [];
    int lastIndex = 0;

    final matches = NoteLinkEngine.linkRegex.allMatches(fullText);

    for (final match in matches) {
      // Normal text before match
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: fullText.substring(lastIndex, match.start),
          style: defaultStyle,
        ));
      }

      final matchedText = match.group(0) ?? '';
      
      // Determine prefix entity icon / color
      Color tagColor = actualLinkColor;
      if (matchedText.toLowerCase().contains('task:')) {
        tagColor = const Color(0xFF10B981);
      } else if (matchedText.toLowerCase().contains('dsa:')) {
        tagColor = const Color(0xFFF59E0B);
      } else if (matchedText.toLowerCase().contains('event:')) {
        tagColor = const Color(0xFF0EA5E9);
      }

      children.add(TextSpan(
        text: matchedText,
        style: defaultStyle.copyWith(
          color: tagColor,
          fontWeight: FontWeight.w700,
          backgroundColor: actualLinkBg,
          letterSpacing: 0.2,
        ),
      ));

      lastIndex = match.end;
    }

    // Remaining text after last match
    if (lastIndex < fullText.length) {
      children.add(TextSpan(
        text: fullText.substring(lastIndex),
        style: defaultStyle,
      ));
    }

    return TextSpan(children: children, style: defaultStyle);
  }
}

/// A viewer widget that renders note body text with clickable interactive link chips
class LinkedNoteBodyViewer extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;
  final Function(ExtractedLink link) onLinkTap;
  final int? maxLines;
  final TextOverflow overflow;

  const LinkedNoteBodyViewer({
    super.key,
    required this.text,
    this.baseStyle,
    required this.onLinkTap,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = baseStyle ??
        TextStyle(
          fontSize: 14,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          height: 1.45,
        );

    final links = NoteLinkEngine.extractLinks(text);

    if (links.isEmpty) {
      return Text(
        text,
        style: defaultStyle,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final link in links) {
      if (link.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, link.startIndex),
          style: defaultStyle,
        ));
      }

      // Entity Color
      Color linkColor = const Color(0xFF6366F1);
      IconData linkIcon = Icons.link_rounded;

      switch (link.entityType) {
        case LinkEntityType.task:
          linkColor = const Color(0xFF10B981);
          linkIcon = Icons.check_circle_outline_rounded;
          break;
        case LinkEntityType.dsa:
          linkColor = const Color(0xFFF59E0B);
          linkIcon = Icons.code_rounded;
          break;
        case LinkEntityType.event:
          linkColor = const Color(0xFF0EA5E9);
          linkIcon = Icons.event_rounded;
          break;
        case LinkEntityType.note:
          linkColor = const Color(0xFF6366F1);
          linkIcon = Icons.note_rounded;
          break;
      }

      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onLinkTap(link),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: linkColor.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: linkColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(linkIcon, size: 12, color: linkColor),
                    const SizedBox(width: 4),
                    Text(
                      link.targetName,
                      style: TextStyle(
                        fontSize: (defaultStyle.fontSize ?? 14) * 0.92,
                        fontWeight: FontWeight.w600,
                        color: isDark ? linkColor.withValues(alpha: 0.95) : linkColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));

      lastIndex = link.endIndex;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: defaultStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Autocomplete suggestion strip when typing `//` or `[[` in Note Editor
class NoteAutocompleteStrip extends StatelessWidget {
  final String query;
  final List<NoteItem> existingNotes;
  final Function(String title, LinkEntityType type) onSuggestionSelected;

  const NoteAutocompleteStrip({
    super.key,
    required this.query,
    required this.existingNotes,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.toLowerCase().trim();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter notes
    final matchingNotes = existingNotes.where((n) {
      if (cleanQuery.isEmpty) return true;
      return n.displayTitle.toLowerCase().contains(cleanQuery);
    }).take(6).toList();

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Quick hint badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF6366F1)),
                SizedBox(width: 6),
                Text(
                  'Link Suggestions:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                ),
              ],
            ),
          ),
          ...matchingNotes.map((note) {
            final catColor = NoteLinkEngine.getCategoryColor(note.category);
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: ActionChip(
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                side: BorderSide(
                  color: catColor.withValues(alpha: 0.4),
                  width: 1,
                ),
                avatar: Icon(
                  NoteLinkEngine.getCategoryIcon(note.category, LinkEntityType.note),
                  size: 14,
                  color: catColor,
                ),
                label: Text(
                  note.displayTitle,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () => onSuggestionSelected(note.displayTitle, LinkEntityType.note),
              ),
            );
          }),
          // Option to link as task / dsa
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ActionChip(
              backgroundColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
              side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
              avatar: const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
              label: Text(
                'task:${cleanQuery.isEmpty ? "NewTask" : cleanQuery}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
              ),
              onPressed: () => onSuggestionSelected('task:${cleanQuery.isEmpty ? "NewTask" : cleanQuery}', LinkEntityType.task),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ActionChip(
              backgroundColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
              side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
              avatar: const Icon(Icons.code_rounded, size: 14, color: Color(0xFFF59E0B)),
              label: Text(
                'dsa:${cleanQuery.isEmpty ? "Topic" : cleanQuery}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
              ),
              onPressed: () => onSuggestionSelected('dsa:${cleanQuery.isEmpty ? "Topic" : cleanQuery}', LinkEntityType.dsa),
            ),
          ),
        ],
      ),
    );
  }
}
