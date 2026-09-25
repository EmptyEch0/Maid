import 'dart:math';
import 'package:flutter/material.dart';
import '../models/app_models.dart';

enum LinkEntityType {
  note,
  task,
  dsa,
  event,
}

class ExtractedLink {
  final String rawText;
  final String targetName;
  final LinkEntityType entityType;
  final int startIndex;
  final int endIndex;

  const ExtractedLink({
    required this.rawText,
    required this.targetName,
    required this.entityType,
    required this.startIndex,
    required this.endIndex,
  });
}

class GraphNode {
  final String id;
  final String label;
  final String? category;
  final LinkEntityType type;
  final dynamic sourceObject;
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  final Color color;
  final IconData icon;
  int connectionCount;
  bool isLoneNode;
  bool isPinned;

  GraphNode({
    required this.id,
    required this.label,
    this.category,
    this.type = LinkEntityType.note,
    this.sourceObject,
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    this.radius = 24.0,
    required this.color,
    required this.icon,
    this.connectionCount = 0,
    this.isLoneNode = true,
    this.isPinned = false,
  });
}

class GraphEdge {
  final String sourceId;
  final String targetId;
  final bool isBidirectional;

  const GraphEdge({
    required this.sourceId,
    required this.targetId,
    this.isBidirectional = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphEdge &&
          ((sourceId == other.sourceId && targetId == other.targetId) ||
              (isBidirectional && sourceId == other.targetId && targetId == other.sourceId));

  @override
  int get hashCode => sourceId.hashCode ^ targetId.hashCode;
}

class GraphTopology {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, List<String>> adjacencyList;
  final Map<String, List<String>> incomingLinks;

  GraphTopology({
    required this.nodes,
    required this.edges,
    required this.adjacencyList,
    required this.incomingLinks,
  });

  List<GraphNode> get loneNodes => nodes.where((n) => n.isLoneNode).toList();
  List<GraphNode> get connectedNodes => nodes.where((n) => !n.isLoneNode).toList();
}

class NoteLinkEngine {
  // Matches //word, //word with spaces, or [[wiki links]]
  // Examples:
  // //Dynamic Programming
  // //task:Complete homework
  // //dsa:Binary Search
  // //event:Team Sync
  // [[Binary Search]]
  static final RegExp linkRegex = RegExp(
    r'(?:\/\/(?<slash>[a-zA-Z0-9_\-\s:]+?)(?=\s\/\/|\s{2,}|\/|$|\n|[,\.!?]))|(?:\[\[(?<wiki>[^\]]+)\]\])',
  );

  /// Extracts all outgoing links from a note body or title
  static List<ExtractedLink> extractLinks(String text) {
    if (text.isEmpty) return [];

    final matches = linkRegex.allMatches(text);
    final List<ExtractedLink> extracted = [];

    for (final match in matches) {
      final raw = match.group(0) ?? '';
      String target = match.namedGroup('slash') ?? match.namedGroup('wiki') ?? '';
      target = target.trim();

      if (target.isEmpty) continue;

      LinkEntityType type = LinkEntityType.note;
      String cleanTarget = target;

      final lower = target.toLowerCase();
      if (lower.startsWith('task:')) {
        type = LinkEntityType.task;
        cleanTarget = target.substring(5).trim();
      } else if (lower.startsWith('dsa:')) {
        type = LinkEntityType.dsa;
        cleanTarget = target.substring(4).trim();
      } else if (lower.startsWith('event:')) {
        type = LinkEntityType.event;
        cleanTarget = target.substring(6).trim();
      } else if (lower.startsWith('note:')) {
        type = LinkEntityType.note;
        cleanTarget = target.substring(5).trim();
      }

      if (cleanTarget.isNotEmpty) {
        extracted.add(ExtractedLink(
          rawText: raw,
          targetName: cleanTarget,
          entityType: type,
          startIndex: match.start,
          endIndex: match.end,
        ));
      }
    }

    return extracted;
  }

  /// Extracts plain target names without duplicate mentions
  static List<String> extractUniqueTargetNames(String text) {
    final links = extractLinks(text);
    return links.map((l) => l.targetName).toSet().toList();
  }

  /// Finds matching note by title or fallback substring
  static NoteItem? findMatchingNote(String targetName, List<NoteItem> allNotes) {
    final clean = targetName.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // Exact title match first
    for (final note in allNotes) {
      if (note.displayTitle.trim().toLowerCase() == clean) {
        return note;
      }
    }

    // Secondary: note starts with targetName or title contains targetName
    for (final note in allNotes) {
      final title = note.displayTitle.trim().toLowerCase();
      if (title.contains(clean) || clean.contains(title)) {
        return note;
      }
    }

    return null;
  }

  /// Finds all notes that link back to the specified note
  static List<NoteItem> findBacklinks(NoteItem currentNote, List<NoteItem> allNotes) {
    final noteTitle = currentNote.displayTitle.trim().toLowerCase();
    final backlinks = <NoteItem>[];

    for (final note in allNotes) {
      if (note.id == currentNote.id) continue;
      final links = extractLinks(note.body);
      final hasLink = links.any((l) =>
          l.entityType == LinkEntityType.note &&
          (l.targetName.toLowerCase() == noteTitle ||
              l.targetName.toLowerCase() == currentNote.id.toLowerCase()));
      if (hasLink) {
        backlinks.add(note);
      }
    }

    return backlinks;
  }

  /// Resolves the category color for nodes
  static Color getCategoryColor(String? category, {bool isDark = true}) {
    final cat = (category ?? 'general').toLowerCase().trim();
    switch (cat) {
      case 'study':
      case 'dsa':
      case 'academics':
        return const Color(0xFF6366F1); // Indigo
      case 'work':
      case 'projects':
      case 'code':
        return const Color(0xFF0EA5E9); // Sky Blue
      case 'ideas':
      case 'brainstorm':
        return const Color(0xFF10B981); // Emerald
      case 'shopping':
      case 'grocery':
        return const Color(0xFFEC4899); // Pink
      case 'personal':
      case 'life':
        return const Color(0xFF8B5CF6); // Purple
      case 'urgent':
      case 'priority':
        return const Color(0xFFF59E0B); // Amber
      default:
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    }
  }

  /// Resolves icon for category or entity type
  static IconData getCategoryIcon(String? category, LinkEntityType type) {
    switch (type) {
      case LinkEntityType.task:
        return Icons.check_circle_outline_rounded;
      case LinkEntityType.dsa:
        return Icons.code_rounded;
      case LinkEntityType.event:
        return Icons.event_rounded;
      case LinkEntityType.note:
        final cat = (category ?? 'general').toLowerCase().trim();
        switch (cat) {
          case 'study':
          case 'dsa':
            return Icons.school_rounded;
          case 'work':
            return Icons.work_outline_rounded;
          case 'ideas':
            return Icons.lightbulb_outline_rounded;
          case 'shopping':
          case 'grocery':
            return Icons.shopping_bag_outlined;
          case 'personal':
            return Icons.person_outline_rounded;
          default:
            return Icons.description_outlined;
        }
    }
  }

  /// Constructs the full graph topology from all notes (and optionally tasks & events)
  static GraphTopology buildGraph({
    required List<NoteItem> notes,
    List<TaskItem>? tasks,
    List<CalendarEvent>? events,
    String? filterCategory,
    String? searchQuery,
    String? focusNoteId,
    int focusDepth = 2,
  }) {
    final Map<String, GraphNode> nodeMap = {};
    final Set<GraphEdge> edgeSet = {};
    final Map<String, List<String>> adjacency = {};
    final Map<String, List<String>> incoming = {};

    final rng = Random(42); // deterministic random seed for layout repeatability
    final radius = 220.0;

    // Filter notes
    List<NoteItem> targetNotes = notes;
    if (filterCategory != null && filterCategory.isNotEmpty && filterCategory != 'All') {
      targetNotes = targetNotes
          .where((n) => (n.category ?? 'general').toLowerCase() == filterCategory.toLowerCase())
          .toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      targetNotes = targetNotes
          .where((n) =>
              n.displayTitle.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
          .toList();
    }

    // 1. Create nodes for all notes
    final noteCount = targetNotes.length;
    for (int i = 0; i < noteCount; i++) {
      final note = targetNotes[i];
      final angle = (i / max(1, noteCount)) * 2 * pi;
      final dist = radius + (rng.nextDouble() - 0.5) * 80;

      final node = GraphNode(
        id: note.id,
        label: note.displayTitle,
        category: note.category,
        type: LinkEntityType.note,
        sourceObject: note,
        x: cos(angle) * dist,
        y: sin(angle) * dist,
        color: getCategoryColor(note.category),
        icon: getCategoryIcon(note.category, LinkEntityType.note),
      );

      nodeMap[note.id] = node;
      adjacency[note.id] = [];
      incoming[note.id] = [];
    }

    // 2. Discover Edges from notes bodies
    for (final note in targetNotes) {
      final links = extractLinks(note.body);
      final sourceNode = nodeMap[note.id];
      if (sourceNode == null) continue;

      for (final link in links) {
        if (link.entityType == LinkEntityType.note) {
          final targetNote = findMatchingNote(link.targetName, notes);
          if (targetNote != null && targetNote.id != note.id) {
            // Note edge
            if (nodeMap.containsKey(targetNote.id)) {
              edgeSet.add(GraphEdge(sourceId: note.id, targetId: targetNote.id));
              adjacency[note.id]?.add(targetNote.id);
              incoming[targetNote.id]?.add(note.id);
            }
          }
        }
      }
    }

    // 3. Mark connections, degrees, and radius sizing
    for (final edge in edgeSet) {
      final src = nodeMap[edge.sourceId];
      final dst = nodeMap[edge.targetId];
      if (src != null) {
        src.connectionCount++;
        src.isLoneNode = false;
      }
      if (dst != null) {
        dst.connectionCount++;
        dst.isLoneNode = false;
      }
    }

    // Scale radius by connection count (Hub nodes grow larger)
    for (final node in nodeMap.values) {
      if (!node.isLoneNode) {
        node.radius = min(42.0, 22.0 + (node.connectionCount * 4.5));
      } else {
        node.radius = 18.0;
      }
    }

    // 4. If focusNoteId is provided, filter for local graph
    if (focusNoteId != null && nodeMap.containsKey(focusNoteId)) {
      final Set<String> visibleIds = {focusNoteId};
      Set<String> currentLevel = {focusNoteId};

      for (int d = 0; d < focusDepth; d++) {
        final Set<String> nextLevel = {};
        for (final id in currentLevel) {
          final neighbors = (adjacency[id] ?? []) + (incoming[id] ?? []);
          for (final n in neighbors) {
            if (!visibleIds.contains(n)) {
              visibleIds.add(n);
              nextLevel.add(n);
            }
          }
        }
        currentLevel = nextLevel;
      }

      final filteredNodes = nodeMap.values.where((n) => visibleIds.contains(n.id)).toList();
      final filteredEdges = edgeSet
          .where((e) => visibleIds.contains(e.sourceId) && visibleIds.contains(e.targetId))
          .toList();

      return GraphTopology(
        nodes: filteredNodes,
        edges: filteredEdges,
        adjacencyList: adjacency,
        incomingLinks: incoming,
      );
    }

    return GraphTopology(
      nodes: nodeMap.values.toList(),
      edges: edgeSet.toList(),
      adjacencyList: adjacency,
      incomingLinks: incoming,
    );
  }

  /// Runs one step of force-directed physics layout
  static void stepPhysicsSimulation(
    List<GraphNode> nodes,
    List<GraphEdge> edges, {
    double repulsionForce = 4500.0,
    double springLength = 110.0,
    double springK = 0.04,
    double centerGravity = 0.015,
    double damping = 0.86,
  }) {
    final Map<String, GraphNode> map = {for (final n in nodes) n.id: n};

    // 1. Coulomb Repulsion between all node pairs
    for (int i = 0; i < nodes.length; i++) {
      final n1 = nodes[i];
      for (int j = i + 1; j < nodes.length; j++) {
        final n2 = nodes[j];

        double dx = n2.x - n1.x;
        double dy = n2.y - n1.y;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 1.0) dist = 1.0;

        // Repulsion force
        double force = repulsionForce / (dist * dist);
        // Lone nodes have softer repulsion
        if (n1.isLoneNode && n2.isLoneNode) {
          force *= 0.6;
        }

        double fx = (dx / dist) * force;
        double fy = (dy / dist) * force;

        if (!n1.isPinned) {
          n1.vx -= fx;
          n1.vy -= fy;
        }
        if (!n2.isPinned) {
          n2.vx += fx;
          n2.vy += fy;
        }
      }
    }

    // 2. Hooke's Spring Attraction along edges
    for (final edge in edges) {
      final n1 = map[edge.sourceId];
      final n2 = map[edge.targetId];
      if (n1 == null || n2 == null) continue;

      double dx = n2.x - n1.x;
      double dy = n2.y - n1.y;
      double dist = sqrt(dx * dx + dy * dy);
      if (dist < 1.0) dist = 1.0;

      double displacement = dist - springLength;
      double force = springK * displacement;

      double fx = (dx / dist) * force;
      double fy = (dy / dist) * force;

      if (!n1.isPinned) {
        n1.vx += fx;
        n1.vy += fy;
      }
      if (!n2.isPinned) {
        n2.vx += fx;
        n2.vy += fy;
      }
    }

    // 3. Center Gravity pull
    for (final node in nodes) {
      if (node.isPinned) continue;

      double distFromOrigin = sqrt(node.x * node.x + node.y * node.y);
      if (distFromOrigin > 0.0) {
        // Lone nodes are pulled into a gentle outer orbit
        final targetDist = node.isLoneNode ? 240.0 : 0.0;
        final pullFactor = node.isLoneNode ? centerGravity * 0.4 : centerGravity;

        double deltaDist = distFromOrigin - targetDist;
        node.vx -= (node.x / distFromOrigin) * deltaDist * pullFactor;
        node.vy -= (node.y / distFromOrigin) * deltaDist * pullFactor;
      }

      // Apply velocity and damping
      node.x += node.vx;
      node.y += node.vy;
      node.vx *= damping;
      node.vy *= damping;
    }
  }
}
