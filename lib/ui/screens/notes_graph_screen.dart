import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../engine/note_link_engine.dart';
import '../../models/app_models.dart';
import '../../providers/app_provider.dart';
import '../widgets/glass_widgets.dart';

class NotesGraphScreen extends StatefulWidget {
  final String? initialFocusNoteId;
  final bool isLocalMode;

  const NotesGraphScreen({
    super.key,
    this.initialFocusNoteId,
    this.isLocalMode = false,
  });

  @override
  State<NotesGraphScreen> createState() => _NotesGraphScreenState();
}

class _NotesGraphScreenState extends State<NotesGraphScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _physicsController;
  GraphTopology? _topology;

  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showLoneNodes = true;
  bool _isPhysicsRunning = true;
  String? _selectedNodeId;
  String? _focusedNoteId;

  // Viewport Transform
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  GraphNode? _draggedNode;

  final List<String> _categories = [
    'All',
    'Study',
    'Work',
    'Ideas',
    'Shopping',
    'Personal',
  ];

  @override
  void initState() {
    super.initState();
    _focusedNoteId = widget.initialFocusNoteId;
    _selectedNodeId = widget.initialFocusNoteId;

    _physicsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onPhysicsTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rebuildGraph();
      _startPhysics();
    });
  }

  @override
  void dispose() {
    _physicsController.dispose();
    super.dispose();
  }

  void _startPhysics() {
    if (!_physicsController.isAnimating) {
      _physicsController.repeat();
      setState(() => _isPhysicsRunning = true);
    }
  }

  void _stopPhysics() {
    if (_physicsController.isAnimating) {
      _physicsController.stop();
      setState(() => _isPhysicsRunning = false);
    }
  }

  void _onPhysicsTick() {
    if (_topology != null && _isPhysicsRunning) {
      NoteLinkEngine.stepPhysicsSimulation(
        _topology!.nodes,
        _topology!.edges,
      );
      setState(() {});
    }
  }

  void _rebuildGraph() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final allNotes = provider.notes;

    final topology = NoteLinkEngine.buildGraph(
      notes: allNotes,
      filterCategory: _selectedCategory,
      searchQuery: _searchQuery,
      focusNoteId: _focusedNoteId,
    );

    setState(() {
      _topology = topology;
      if (_selectedNodeId != null &&
          !topology.nodes.any((n) => n.id == _selectedNodeId)) {
        _selectedNodeId = null;
      }
    });

    _startPhysics();
  }

  void _recenterView() {
    setState(() {
      _panOffset = Offset.zero;
      _scale = 1.0;
    });
  }

  GraphNode? _findNodeAt(Offset localPosition, Size size) {
    if (_topology == null) return null;

    final center = Offset(size.width / 2, size.height / 2);
    // Convert screen coordinates back into world coordinates
    final worldX = (localPosition.dx - center.dx - _panOffset.dx) / _scale;
    final worldY = (localPosition.dy - center.dy - _panOffset.dy) / _scale;

    for (final node in _topology!.nodes.reversed) {
      if (!_showLoneNodes && node.isLoneNode && node.id != _selectedNodeId) {
        continue;
      }
      final dx = node.x - worldX;
      final dy = node.y - worldY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist <= node.radius + 14) {
        return node;
      }
    }
    return null;
  }

  void _openNoteEditor(NoteItem note) {
    // Navigate back with selected note or open editor
    Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final visibleNodes = _topology?.nodes.where((n) {
          if (!_showLoneNodes && n.isLoneNode && n.id != _selectedNodeId) {
            return false;
          }
          return true;
        }).toList() ??
        [];

    final selectedNode = _topology?.nodes.firstWhere(
      (n) => n.id == _selectedNodeId,
      orElse: () => visibleNodes.isNotEmpty ? visibleNodes.first : GraphNode(
        id: '',
        label: '',
        x: 0,
        y: 0,
        color: Colors.grey,
        icon: Icons.notes,
      ),
    );

    final totalEdges = _topology?.edges.length ?? 0;
    final totalConnected = visibleNodes.where((n) => !n.isLoneNode).length;
    final totalLone = visibleNodes.where((n) => n.isLoneNode).length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              '🕸️',
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _focusedNoteId != null ? 'Local Knowledge Graph' : 'Mindmap Knowledge Graph',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  '${visibleNodes.length} notes • $totalEdges links ($totalConnected connected, $totalLone lone)',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPhysicsRunning ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
              color: _isPhysicsRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            ),
            tooltip: _isPhysicsRunning ? 'Pause Physics' : 'Resume Physics',
            onPressed: () {
              if (_isPhysicsRunning) {
                _stopPhysics();
              } else {
                _startPhysics();
              }
            },
          ),
          IconButton(
            icon: Icon(
              _showLoneNodes ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: _showLoneNodes ? const Color(0xFF6366F1) : const Color(0xFF94A3B8),
            ),
            tooltip: _showLoneNodes ? 'Hide Lone Notes' : 'Show Lone Notes',
            onPressed: () {
              setState(() => _showLoneNodes = !_showLoneNodes);
            },
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded),
            tooltip: 'Recenter View',
            onPressed: _recenterView,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive Canvas with Force-Directed Graph
          GestureDetector(
            onScaleStart: (details) {
              final node = _findNodeAt(details.localFocalPoint, size);
              if (node != null) {
                setState(() {
                  _draggedNode = node;
                  _draggedNode!.isPinned = true;
                  _selectedNodeId = node.id;
                });
                _startPhysics();
              }
            },
            onScaleUpdate: (details) {
              if (_draggedNode != null) {
                final center = Offset(size.width / 2, size.height / 2);
                final worldX = (details.localFocalPoint.dx - center.dx - _panOffset.dx) / _scale;
                final worldY = (details.localFocalPoint.dy - center.dy - _panOffset.dy) / _scale;
                setState(() {
                  _draggedNode!.x = worldX;
                  _draggedNode!.y = worldY;
                  _draggedNode!.vx = 0;
                  _draggedNode!.vy = 0;
                });
              } else {
                setState(() {
                  _panOffset += details.focalPointDelta;
                  _scale = (_scale * details.scale).clamp(0.25, 3.5);
                });
              }
            },
            onScaleEnd: (details) {
              if (_draggedNode != null) {
                setState(() {
                  _draggedNode!.isPinned = false;
                  _draggedNode = null;
                });
              }
            },
            onTapUp: (details) {
              final node = _findNodeAt(details.localPosition, size);
              setState(() {
                _selectedNodeId = node?.id;
              });
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: _KnowledgeGraphPainter(
                topology: _topology,
                panOffset: _panOffset,
                scale: _scale,
                selectedNodeId: _selectedNodeId,
                showLoneNodes: _showLoneNodes,
                isDark: isDark,
              ),
            ),
          ),

          // 2. Top Filter and Search Bar
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Search Bar
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search concepts, topics, nodes...',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) {
                            _searchQuery = val;
                            _rebuildGraph();
                          },
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            setState(() => _searchQuery = '');
                            _rebuildGraph();
                          },
                        ),
                      if (_focusedNoteId != null)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.all_inclusive_rounded, size: 16),
                          label: const Text('Show All', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            setState(() => _focusedNoteId = null);
                            _rebuildGraph();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Category Filter Pills
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (ctx, idx) {
                      final cat = _categories[idx];
                      final isSelected = _selectedCategory == cat;
                      final catColor = NoteLinkEngine.getCategoryColor(cat, isDark: isDark);

                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selectedColor: catColor,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: isSelected ? catColor : Colors.transparent,
                          width: 1,
                        ),
                        onSelected: (val) {
                          setState(() => _selectedCategory = cat);
                          _rebuildGraph();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 3. Selected Node Floating Bottom Sheet
          if (_selectedNodeId != null && selectedNode != null && selectedNode.id.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildSelectedNodeCard(context, selectedNode, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedNodeCard(BuildContext context, GraphNode node, bool isDark) {
    final note = node.sourceObject is NoteItem ? node.sourceObject as NoteItem : null;
    final connections = node.connectionCount;
    final categoryColor = node.color;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(node.icon, color: categoryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            node.category ?? 'General',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: categoryColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          node.isLoneNode ? '🏝️ Lone note' : '🔗 $connections link${connections > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _selectedNodeId = null),
              ),
            ],
          ),
          if (note != null && note.body.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              note.body.replaceAll('\n', ' '),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!node.isLoneNode)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.hub_outlined, size: 16),
                  label: const Text('Focus Graph', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() => _focusedNoteId = node.id);
                    _rebuildGraph();
                  },
                ),
              const SizedBox(width: 8),
              if (note != null)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Open Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _openNoteEditor(note),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KnowledgeGraphPainter extends CustomPainter {
  final GraphTopology? topology;
  final Offset panOffset;
  final double scale;
  final String? selectedNodeId;
  final bool showLoneNodes;
  final bool isDark;

  _KnowledgeGraphPainter({
    required this.topology,
    required this.panOffset,
    required this.scale,
    required this.selectedNodeId,
    required this.showLoneNodes,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (topology == null) return;

    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx + panOffset.dx, center.dy + panOffset.dy);
    canvas.scale(scale);

    // 1. Draw aesthetic background grid dots
    final bgDotPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    const gridSpacing = 40.0;
    final startX = -size.width / scale - 300;
    final endX = size.width / scale + 300;
    final startY = -size.height / scale - 300;
    final endY = size.height / scale + 300;

    for (double gx = (startX / gridSpacing).floor() * gridSpacing; gx <= endX; gx += gridSpacing) {
      for (double gy = (startY / gridSpacing).floor() * gridSpacing; gy <= endY; gy += gridSpacing) {
        canvas.drawCircle(Offset(gx, gy), 1.0, bgDotPaint);
      }
    }

    final Map<String, GraphNode> nodeMap = {
      for (final n in topology!.nodes) n.id: n
    };

    // 2. Draw Edges (Connecting lines between notes)
    final edgePaint = Paint()
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final glowEdgePaint = Paint()
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (final edge in topology!.edges) {
      final src = nodeMap[edge.sourceId];
      final dst = nodeMap[edge.targetId];
      if (src == null || dst == null) continue;

      final isHighlighted =
          selectedNodeId == src.id || selectedNodeId == dst.id;

      final p1 = Offset(src.x, src.y);
      final p2 = Offset(dst.x, dst.y);

      if (isHighlighted) {
        glowEdgePaint.color = const Color(0xFF6366F1).withValues(alpha: 0.35);
        canvas.drawLine(p1, p2, glowEdgePaint);

        edgePaint.color = const Color(0xFF818CF8);
        edgePaint.strokeWidth = 2.2;
      } else {
        edgePaint.color = isDark
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFF64748B).withValues(alpha: 0.25);
        edgePaint.strokeWidth = 1.4;
      }

      canvas.drawLine(p1, p2, edgePaint);

      // Subtle directional arrow/dot in the middle
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final midDotPaint = Paint()
        ..color = isHighlighted
            ? const Color(0xFF6366F1)
            : (isDark ? Colors.white30 : Colors.black26)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(mid, isHighlighted ? 2.5 : 1.8, midDotPaint);
    }

    // 3. Draw Nodes
    for (final node in topology!.nodes) {
      if (!showLoneNodes && node.isLoneNode && node.id != selectedNodeId) {
        continue;
      }

      final isSelected = node.id == selectedNodeId;
      final nodePos = Offset(node.x, node.y);

      // Ambient Outer Glow
      if (isSelected || node.connectionCount > 2) {
        final haloPaint = Paint()
          ..color = node.color.withValues(alpha: isSelected ? 0.35 : 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(nodePos, node.radius + (isSelected ? 10 : 6), haloPaint);
      }

      // Node Body Circle
      final bodyPaint = Paint()
        ..color = isDark ? const Color(0xFF1E293B) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(nodePos, node.radius, bodyPaint);

      // Inner Accent fill
      final fillPaint = Paint()
        ..color = node.color.withValues(alpha: isDark ? 0.28 : 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(nodePos, node.radius, fillPaint);

      // Border outline
      final borderPaint = Paint()
        ..color = isSelected ? Colors.white : node.color.withValues(alpha: isDark ? 0.8 : 0.9)
        ..strokeWidth = isSelected ? 2.8 : (node.isLoneNode ? 1.2 : 2.0)
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(nodePos, node.radius, borderPaint);

      // Inner icon or mini glyph
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(node.icon.codePoint),
          style: TextStyle(
            fontSize: node.radius * 0.85,
            fontFamily: node.icon.fontFamily,
            package: node.icon.fontPackage,
            color: isSelected ? Colors.white : node.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        nodePos - Offset(iconPainter.width / 2, iconPainter.height / 2),
      );

      // Label Text Badge below node
      final textSpan = TextSpan(
        text: node.label,
        style: TextStyle(
          fontSize: isSelected ? 12 : 10.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
          shadows: [
            Shadow(
              color: isDark ? Colors.black87 : Colors.white70,
              blurRadius: 3,
            ),
          ],
        ),
      );

      final labelPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: 110);

      final labelBgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(node.x, node.y + node.radius + 12),
          width: labelPainter.width + 10,
          height: labelPainter.height + 4,
        ),
        const Radius.circular(6),
      );

      final labelBgPaint = Paint()
        ..color = (isDark ? const Color(0xFF0F172A) : Colors.white).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(labelBgRect, labelBgPaint);

      labelPainter.paint(
        canvas,
        Offset(node.x - labelPainter.width / 2, node.y + node.radius + 10),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _KnowledgeGraphPainter oldDelegate) => true;
}
