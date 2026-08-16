import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';

class DsaDayPlan {
  final int dayNumber; // 1 to 90
  final int weekNumber; // 1 to 18
  final String date; // YYYY-MM-DD
  final String topic;
  final String watch;
  final String study;
  final String practice;
  final String target;

  DsaDayPlan({
    required this.dayNumber,
    required this.weekNumber,
    required this.date,
    required this.topic,
    required this.watch,
    required this.study,
    required this.practice,
    required this.target,
  });
}

class DsaPlanSeeder {
  static final List<Map<String, dynamic>> _weekData = [
    // WEEK 1: Python Fundamentals (Aug 17–21)
    {
      'week': 1,
      'topic': 'Python Fundamentals',
      'days': [
        {
          'watch': 'Introduction to Python, Prerequisites, Installation',
          'study': 'Variables, Data types (int, float, str, bool), Input/Output, Type conversion',
          'practice': 'Sum of two numbers, Swap numbers, Area calculations, Celsius to Fahrenheit, Calculator, Even/Odd',
          'target': '8–10 problems',
        },
        {
          'watch': 'Print Function, Operators',
          'study': 'Arithmetic (+ - * / % // **), Comparison (== != > < >= <=), Logical (and, or, not)',
          'practice': 'Even/odd, Positive/negative, Largest of 2/3, Leap year, Simple grading, Divisibility',
          'target': '10 problems',
        },
        {
          'watch': 'Control Flow, Loops',
          'study': 'if/elif/else, for/while/range(), break, continue',
          'practice': 'Factorial, Prime check, Fibonacci, Reverse number, Sum of digits, Count digits, Armstrong number',
          'target': '12–15 problems',
        },
        {
          'watch': 'Strings, String challenges',
          'study': 'Indexing (s[0], s[-1]), slicing (s[::-1]), Traversal, string methods',
          'practice': 'Reverse string, Palindrome, Count vowels, Count characters, Character frequency, Remove spaces',
          'target': '10–12 problems',
        },
        {
          'watch': 'Lists, Tuples, Dictionaries, Sets, Functions',
          'study': 'list, dict, set fundamentals, append(), pop(), remove(), sort(), reverse(), dict[key]',
          'practice': 'Maximum/minimum element, Frequency count, Remove duplicates, Find common elements, List reversal',
          'target': '12–15 problems',
        },
      ]
    },
    // WEEK 2: Arrays (Aug 24–28)
    {
      'week': 2,
      'topic': 'Arrays',
      'days': [
        {
          'watch': 'Array introduction',
          'study': 'Array concept, indexing, traversal, searching, updating. Time complexity O(1), O(n)',
          'practice': 'Find maximum, Find minimum, Sum array, Count even numbers, Linear search, Reverse array',
          'target': '8–10 problems',
        },
        {
          'watch': 'Array manipulation',
          'study': 'In-place operations, swapping, reverse, duplicate handling',
          'practice': 'Reverse array, Move zeroes, Remove duplicates, Rotate array, Second largest, Missing number',
          'target': '8–10 problems',
        },
        {
          'watch': 'Array problem solving',
          'study': 'Subarrays, brute force, optimization',
          'practice': 'Maximum subarray, Best time to buy/sell stock, Maximum sum, Minimum subarray, Subarray problems',
          'target': '8 problems',
        },
        {
          'watch': 'Prefix sum',
          'study': 'prefix[i] = sum of elements before/current, When prefix sums are useful',
          'practice': 'Range sum, Running sum, Pivot index, Subarray sum, Equilibrium index',
          'target': '8 problems',
        },
        {
          'watch': 'Array Revision Day',
          'study': 'No new major concept. Solve 10 mixed array problems. Record approach, time/space complexity, mistake.',
          'practice': '10 mixed array problems without solutions',
          'target': '10 mixed problems',
        },
      ]
    },
    // WEEK 3: Arrays II + Prefix Sum (Aug 31–Sep 4)
    {
      'week': 3,
      'topic': 'Arrays II + Prefix Sum',
      'days': [
        {
          'watch': "Kadane's algorithm",
          'study': "Kadane's algorithm, Maximum subarray",
          'practice': 'Maximum subarray sum, Contiguous subarray problems',
          'target': '5–7 problems',
        },
        {
          'watch': 'Difference arrays & Prefix/Suffix',
          'study': 'Difference arrays, Prefix/suffix concepts',
          'practice': 'Range addition, Corporate flight bookings',
          'target': '7–8 problems',
        },
        {
          'watch': 'Sorting basics in DSA',
          'study': 'Sorting basics, built-in sorting, when sorting helps DSA',
          'practice': 'Sort array, Merge arrays, Intersection of arrays, Union, Relative ordering',
          'target': '8 problems',
        },
        {
          'watch': 'Frequency arrays & Hashing intro',
          'study': 'Frequency arrays, hashing introduction',
          'practice': 'Frequency counting, Duplicate detection, Majority element, Missing/repeating numbers',
          'target': '8 problems',
        },
        {
          'watch': 'Friday Array Test',
          'study': 'Solve 2 Easy + 3 Medium problems in 90 minutes. Review mistakes.',
          'practice': 'Array Test: 2 Easy + 3 Medium problems',
          'target': '5 test problems (90 mins)',
        },
      ]
    },
    // WEEK 4: Two Pointers + Sliding Window (Sep 7–11)
    {
      'week': 4,
      'topic': 'Two Pointers + Sliding Window',
      'days': [
        {
          'watch': 'Two pointers fundamentals',
          'study': 'Two pointers fundamentals (left -> / <- right)',
          'practice': 'Two Sum, Reverse array, Pair sum, Remove duplicates',
          'target': '5–7 problems',
        },
        {
          'watch': 'Advanced two pointers',
          'study': 'Advanced two pointers techniques',
          'practice': 'Two Sum II, Container With Most Water, 3Sum, Valid palindrome',
          'target': '5–7 problems',
        },
        {
          'watch': 'Sliding window fundamentals',
          'study': 'Fixed window vs variable window techniques',
          'practice': 'Maximum sum of K elements, Average subarray, First window problems',
          'target': '5–7 problems',
        },
        {
          'watch': 'Advanced sliding window',
          'study': 'Advanced sliding window techniques',
          'practice': 'Longest substring without repeating characters, Longest repeating character replacement, Permutation in string',
          'target': '5–7 problems',
        },
        {
          'watch': 'Friday Pattern Day',
          'study': 'Solve 5 Two Pointer + 5 Sliding Window problems. Goal: recognize patterns.',
          'practice': '10 pattern recognition problems',
          'target': '10 pattern problems',
        },
      ]
    },
    // WEEK 5: Strings + Hashing (Sep 14–18)
    {
      'week': 5,
      'topic': 'Strings + Hashing',
      'days': [
        {
          'watch': 'Character traversal & palindromes',
          'study': 'Character traversal, frequency, palindrome, anagrams',
          'practice': 'String palindromes, Anagram checks, Character frequency',
          'target': '8 problems',
        },
        {
          'watch': 'Hashing: dict, set, Counter',
          'study': 'Hashing structures in Python: dict, set, collections.Counter',
          'practice': 'Two Sum, Contains Duplicate, Valid Anagram, Frequency problems',
          'target': '8 problems',
        },
        {
          'watch': 'Advanced hashing',
          'study': 'Advanced hashing patterns',
          'practice': 'Group Anagrams, Longest consecutive sequence, Majority element',
          'target': '8 problems',
        },
        {
          'watch': 'Prefix + hashing',
          'study': 'Combining prefix sums with hash maps',
          'practice': 'Subarray sum equals K, Longest subarray with sum K, Frequency-based problems',
          'target': '8 problems',
        },
        {
          'watch': 'Friday Strings & Hashing Test',
          'study': 'Solve 2 arrays + 2 strings + 2 hashing + 2 sliding window problems in 90 minutes.',
          'practice': '8 mixed test problems in 90 mins',
          'target': '8 test problems',
        },
      ]
    },
    // WEEK 6: Linked List (Sep 21–25)
    {
      'week': 6,
      'topic': 'Linked List',
      'days': [
        {
          'watch': 'Linked List Node & Traversal',
          'study': 'Node, head, traversal, insertion - implement your own LinkedList class',
          'practice': 'Implement LinkedList, Insert at head/tail/index',
          'target': '5 problems',
        },
        {
          'watch': 'Linked List Operations',
          'study': 'Deletion, searching, updating in LinkedList',
          'practice': 'Delete node, Search element, Find length, Update node',
          'target': '6 problems',
        },
        {
          'watch': 'Reverse Linked List',
          'study': 'Reverse Linked List — iterative vs recursive approach',
          'practice': 'Reverse LinkedList, Reverse sublist',
          'target': '5 problems',
        },
        {
          'watch': 'Fast & Slow Pointers',
          'study': 'Fast/slow pointers, cycle detection (Floyd\'s algorithm), middle node',
          'practice': 'Linked list cycle, Find middle node, Cycle II start node',
          'target': '6 problems',
        },
        {
          'watch': 'Linked List Problem Solving',
          'study': 'Common LinkedList interview patterns',
          'practice': 'Merge two sorted lists, Remove nth node from end, Palindrome linked list, Intersection',
          'target': '6 problems',
        },
      ]
    },
    // WEEK 7: Stack + Queue (Sep 28–Oct 2)
    {
      'week': 7,
      'topic': 'Stack + Queue',
      'days': [
        {
          'watch': 'Stack (LIFO) Fundamentals',
          'study': 'Stack (LIFO) concept — implement using Python list',
          'practice': 'Push, Pop, Peek, Is empty implementation',
          'target': '5 problems',
        },
        {
          'watch': 'Stack Classic Problems',
          'study': 'Stack application patterns',
          'practice': 'Valid parentheses, Min stack, Evaluate postfix expression',
          'target': '6 problems',
        },
        {
          'watch': 'Monotonic Stack',
          'study': 'Monotonic stack: next greater element, previous greater, next smaller',
          'practice': 'Next greater element I & II, Daily temperatures',
          'target': '5 problems',
        },
        {
          'watch': 'Queue (FIFO) & Deque',
          'study': 'Queue (FIFO) — Python: from collections import deque',
          'practice': 'Queue implementation, Circular queue, Deque operations',
          'target': '5 problems',
        },
        {
          'watch': 'Stack + Queue Friday Test',
          'study': 'Mixed: Stack + Queue + Monotonic stack',
          'practice': '8 mixed stack & queue problems',
          'target': '8 problems',
        },
      ]
    },
    // WEEK 8: Recursion + Backtracking (Oct 5–9)
    {
      'week': 8,
      'topic': 'Recursion + Backtracking',
      'days': [
        {
          'watch': 'Recursion Fundamentals',
          'study': 'Base case, recursive case, call stack execution',
          'practice': 'Factorial, Fibonacci, Sum of N, Power(x,n), Reverse string recursively',
          'target': '5 problems',
        },
        {
          'watch': 'Recursion on Arrays & Strings',
          'study': 'Array & String recursion patterns',
          'practice': 'Array traversal recursively, Subsequence generation, Recursive binary search',
          'target': '5 problems',
        },
        {
          'watch': 'Backtracking Core Concept',
          'study': 'Backtracking framework: Choose -> Explore -> Undo',
          'practice': 'Subsets, Permutations',
          'target': '5 problems',
        },
        {
          'watch': 'Advanced Backtracking',
          'study': 'Pruning branches in backtracking trees',
          'practice': 'Combination Sum I & II, Generate Parentheses, Letter combinations of phone number',
          'target': '5 problems',
        },
        {
          'watch': 'Friday Backtracking Test',
          'study': 'Solve 5 problems without looking at solutions',
          'practice': '5 backtracking test problems',
          'target': '5 test problems',
        },
      ]
    },
    // WEEK 9: Binary Search (Oct 12–16)
    {
      'week': 9,
      'topic': 'Binary Search',
      'days': [
        {
          'watch': 'Binary Search Basics',
          'study': 'Binary search on sorted arrays: left, right, mid, avoiding integer overflow',
          'practice': 'Standard Binary Search, Search insertion position',
          'target': '8 problems',
        },
        {
          'watch': 'Lower & Upper Bounds',
          'study': 'First occurrence, last occurrence, lower bound, upper bound',
          'practice': 'Find first and last position of element in sorted array, Count occurrences',
          'target': '7 problems',
        },
        {
          'watch': 'Rotated & Peak Searching',
          'study': 'Search in rotated sorted array, find peak element',
          'practice': 'Search in Rotated Sorted Array I & II, Find Peak Element, Find Minimum in Rotated Array',
          'target': '6 problems',
        },
        {
          'watch': 'Binary Search on Answer Space',
          'study': 'Binary Search on Answer (learn search range condition functions carefully)',
          'practice': 'Koko Eating Bananas, Capacity to Ship Packages Within D Days, Minimum speed problems',
          'target': '5 problems',
        },
        {
          'watch': 'Friday Binary Search Test',
          'study': 'Solve 5 binary search problems in 90 minutes',
          'practice': '5 binary search test problems',
          'target': '5 test problems (90 mins)',
        },
      ]
    },
    // WEEK 10: Binary Trees (Oct 19–23)
    {
      'week': 10,
      'topic': 'Binary Trees',
      'days': [
        {
          'watch': 'Tree Terminology & Node Class',
          'study': 'Tree terminology: root, parent, child, leaf, height, depth. Implement TreeNode class',
          'practice': 'Implement TreeNode, Count nodes, Sum of all nodes',
          'target': '5 problems',
        },
        {
          'watch': 'Tree Traversals (DFS)',
          'study': 'Preorder, Inorder, Postorder — implement recursively and iteratively',
          'practice': 'Binary Tree Inorder, Preorder, Postorder Traversals',
          'target': '5 problems',
        },
        {
          'watch': 'Level Order Traversal (BFS)',
          'study': 'Level order traversal using Queue / BFS',
          'practice': 'Level order traversal, Maximum depth of binary tree, Min depth',
          'target': '5 problems',
        },
        {
          'watch': 'Tree Properties & Structural Problems',
          'study': 'Checking tree symmetry and balance',
          'practice': 'Same tree, Invert binary tree, Balanced binary tree, Diameter of binary tree',
          'target': '5 problems',
        },
        {
          'watch': 'Friday Mixed Tree Test',
          'study': 'Mixed binary tree problems',
          'practice': '8 mixed binary tree problems',
          'target': '8 test problems',
        },
      ]
    },
    // WEEK 11: BST + Tree Problems (Oct 26–30)
    {
      'week': 11,
      'topic': 'BST + Tree Problems',
      'days': [
        {
          'watch': 'BST Fundamentals',
          'study': 'BST fundamentals: search, insert, delete, BST property (left < root < right)',
          'practice': 'Implement BST, Insert into BST',
          'target': '5 problems',
        },
        {
          'watch': 'BST Validation & Operations',
          'study': 'Validating BST properties',
          'practice': 'Search in BST, Validate Binary Search Tree, Kth smallest element in BST',
          'target': '6 problems',
        },
        {
          'watch': 'Lowest Common Ancestor (LCA)',
          'study': 'Lowest Common Ancestor, tree recursion patterns',
          'practice': 'LCA of BST, LCA of Binary Tree',
          'target': '5 problems',
        },
        {
          'watch': 'Advanced Tree Paths',
          'study': 'Tree path sums and views',
          'practice': 'Binary tree right side view, Path sum I & II, Maximum path sum',
          'target': '5 problems',
        },
        {
          'watch': 'Friday Tree/BST Test',
          'study': 'Solve 6 mixed tree/BST problems',
          'practice': '6 mixed tree & BST problems',
          'target': '6 test problems',
        },
      ]
    },
    // WEEK 12: Heap + Priority Queue (Nov 2–6)
    {
      'week': 12,
      'topic': 'Heap + Priority Queue',
      'days': [
        {
          'watch': 'Heap & Priority Queue in Python',
          'study': 'Heap, min heap, max heap, priority queue — Python: import heapq',
          'practice': 'Implement MinHeap using heapq, Heapify array',
          'target': '5 problems',
        },
        {
          'watch': 'Top K Problems',
          'study': 'Maintaining heap of size K',
          'practice': 'Kth largest element in array, Kth smallest element, Top K elements',
          'target': '5 problems',
        },
        {
          'watch': 'Frequency & Closest Points',
          'study': 'Frequency + heap patterns',
          'practice': 'Top K frequent elements, K closest points to origin',
          'target': '5 problems',
        },
        {
          'watch': 'K-Way Merge & Median Stream',
          'study': 'Two heaps pattern (min-heap + max-heap)',
          'practice': 'Merge K sorted lists, Find median from data stream',
          'target': '4 problems',
        },
        {
          'watch': 'Friday Heap Test',
          'study': 'Solve 5-6 priority queue problems',
          'practice': '5-6 mixed heap problems',
          'target': '5–6 test problems',
        },
      ]
    },
    // WEEK 13: Graph Basics (Nov 9–13)
    {
      'week': 13,
      'topic': 'Graph Basics',
      'days': [
        {
          'watch': 'Graph Representation & Terminology',
          'study': 'Graph terminology: nodes, edges, directed/undirected, weighted/unweighted. Represent graph using adjacency_list',
          'practice': 'Build adjacency list, Graph traversal setup',
          'target': '4 problems',
        },
        {
          'watch': 'BFS Traversal',
          'study': 'BFS: queue + visited set',
          'practice': 'BFS traversal, Shortest path in unweighted graph',
          'target': '5 problems',
        },
        {
          'watch': 'DFS Traversal',
          'study': 'DFS: recursion + visited set',
          'practice': 'DFS traversal, Connected components in undirected graph',
          'target': '5 problems',
        },
        {
          'watch': 'Grid Graph Problems',
          'study': 'Grid graphs (2D matrix traversal using BFS/DFS)',
          'practice': 'Number of Islands, Flood Fill, Number of Provinces',
          'target': '5 problems',
        },
        {
          'watch': 'Friday Graph Test',
          'study': 'Solve 5-6 basic graph problems',
          'practice': '5-6 graph problems',
          'target': '5–6 test problems',
        },
      ]
    },
    // WEEK 14: Advanced Graphs (Nov 16–20)
    {
      'week': 14,
      'topic': 'Advanced Graphs',
      'days': [
        {
          'watch': 'Cycle Detection',
          'study': 'Cycle detection algorithms',
          'practice': 'Cycle in undirected graph, Cycle in directed graph',
          'target': '4 problems',
        },
        {
          'watch': 'Topological Sort',
          'study': 'Topological Sort (Kahn\'s BFS & DFS approaches)',
          'practice': 'Course Schedule I, Course Schedule II',
          'target': '4 problems',
        },
        {
          'watch': 'Bipartite Graphs',
          'study': 'Bipartite Graph checking (BFS 2-coloring)',
          'practice': 'Is Graph Bipartite?, Graph coloring problems',
          'target': '4 problems',
        },
        {
          'watch': 'Dijkstra Shortest Path',
          'study': 'Dijkstra algorithm: priority queue + shortest path array',
          'practice': 'Network Delay Time, Shortest path in weighted graph',
          'target': '4 problems',
        },
        {
          'watch': 'Disjoint Set Union (DSU)',
          'study': 'Union Find / DSU (find, union by rank, path compression)',
          'practice': 'Number of Provinces using DSU, Redundant Connection',
          'target': '4 problems',
        },
      ]
    },
    // WEEK 15: Greedy (Nov 23–27)
    {
      'week': 15,
      'topic': 'Greedy',
      'days': [
        {
          'watch': 'Greedy Core Concept',
          'study': 'Greedy concept: choosing local optimum for global optimum',
          'practice': 'Assign Cookies, Activity Selection',
          'target': '5 problems',
        },
        {
          'watch': 'Interval Problems',
          'study': 'Sorting intervals by start/end time',
          'practice': 'Merge Intervals, Insert Interval, Non-overlapping Intervals',
          'target': '5 problems',
        },
        {
          'watch': 'Greedy Array Problems',
          'study': 'Greedy array traversal tricks',
          'practice': 'Jump Game I, Jump Game II',
          'target': '4 problems',
        },
        {
          'watch': 'Scheduling & Partitioning',
          'study': 'Greedy scheduling & resource allocation',
          'practice': 'Gas Station, Partition Labels, Scheduling problems',
          'target': '4 problems',
        },
        {
          'watch': 'Friday Greedy Test',
          'study': 'Solve 5-7 greedy problems',
          'practice': '5–7 greedy test problems',
          'target': '5–7 test problems',
        },
      ]
    },
    // WEEK 16: Dynamic Programming I (Nov 30–Dec 4)
    {
      'week': 16,
      'topic': 'Dynamic Programming I',
      'days': [
        {
          'watch': 'What is DP?',
          'study': 'What is DP? Overlapping subproblems, optimal substructure, memoization vs tabulation',
          'practice': 'Fibonacci, Climbing Stairs',
          'target': '4 problems',
        },
        {
          'watch': '1D DP Patterns',
          'study': '1D Array DP state transitions',
          'practice': 'Climbing Stairs, Min Cost Climbing Stairs, House Robber',
          'target': '5 problems',
        },
        {
          'watch': 'More 1D DP',
          'study': 'State choices in 1D DP',
          'practice': 'House Robber II, Decode Ways, Maximum sum problems',
          'target': '5 problems',
        },
        {
          'watch': '2D Grid DP',
          'study': '2D Grid DP: Grid paths, min/max path cost',
          'practice': 'Unique Paths I & II, Minimum Path Sum',
          'target': '4 problems',
        },
        {
          'watch': 'Friday DP Revision',
          'study': 'Solve 5 DP problems and write down recurrence relation for each.',
          'practice': '5 1D & 2D DP problems',
          'target': '5 DP problems + recurrences',
        },
      ]
    },
    // WEEK 17: Dynamic Programming II (Dec 7–11)
    {
      'week': 17,
      'topic': 'Dynamic Programming II',
      'days': [
        {
          'watch': 'Knapsack Pattern',
          'study': '0/1 Knapsack pattern (include vs exclude choice)',
          'practice': '0/1 Knapsack, Partition Equal Subset Sum',
          'target': '4 problems',
        },
        {
          'watch': 'Unbounded Knapsack / Coin Change',
          'study': 'Unbounded knapsack choices',
          'practice': 'Coin Change I, Coin Change II',
          'target': '4 problems',
        },
        {
          'watch': 'LCS & LIS Subsequences',
          'study': 'Subsequence DP state transitions',
          'practice': 'Longest Common Subsequence (LCS), Longest Increasing Subsequence (LIS)',
          'target': '4 problems',
        },
        {
          'watch': 'String DP',
          'study': 'Two-string alignment DP',
          'practice': 'Longest Palindromic Subsequence, Edit Distance',
          'target': '4 problems',
        },
        {
          'watch': 'Friday DP Test',
          'study': 'Solve 5 mixed DP problems without looking at solutions.',
          'practice': '5 mixed DP test problems',
          'target': '5 test problems',
        },
      ]
    },
    // WEEK 18: Job Interview Preparation (Dec 14–18)
    {
      'week': 18,
      'topic': 'Job Interview Preparation',
      'days': [
        {
          'watch': 'Interview Practice: Arrays & Hashing',
          'study': 'Time management: 90 min solving + 45 min mistake review',
          'practice': '2 Easy + 3 Medium (Arrays & Hashing)',
          'target': '5 problems (2h 15m)',
        },
        {
          'watch': 'Interview Practice: Strings & Two Pointers',
          'study': 'Mock test conditions',
          'practice': '2 Easy + 3 Medium (Strings, Sliding Window, Two Pointers)',
          'target': '5 problems',
        },
        {
          'watch': 'Interview Practice: LinkedList & Trees',
          'study': 'Structure & pointer safety in interviews',
          'practice': '1 Easy + 4 Medium (Linked List, Stack, Trees)',
          'target': '5 problems',
        },
        {
          'watch': 'Interview Practice: Graphs & DP',
          'study': 'Explaining complexity out loud',
          'practice': '1 Easy + 3 Medium (Binary Search, Graph, DP)',
          'target': '4 problems',
        },
        {
          'watch': 'FULL MOCK INTERVIEW (Day 90)',
          'study': 'Simulate 2-hour full job interview. Explain brute force, optimize, state time/space complexity, code, and test edge cases.',
          'practice': '4 Problems: 1 Array/Hashing, 1 LinkedList/Tree, 1 Binary Search/Graph, 1 DP/Greedy',
          'target': 'FULL 2-HOUR MOCK INTERVIEW',
        },
      ]
    },
  ];

  /// Generates the list of 90 weekday plans starting on August 17, 2026 (skipping Saturdays & Sundays).
  static List<DsaDayPlan> generate90DayPlan() {
    final List<DsaDayPlan> plans = [];
    DateTime currentDate = DateTime(2026, 8, 17); // Start Aug 17, 2026 (Monday)
    int totalDayCounter = 0;

    for (var weekMap in _weekData) {
      final weekNum = weekMap['week'] as int;
      final weekTopic = weekMap['topic'] as String;
      final daysList = weekMap['days'] as List<Map<String, String>>;

      for (var dayContent in daysList) {
        // Advance currentDate until it's a weekday (Mon=1, ..., Fri=5)
        while (currentDate.weekday == DateTime.saturday || currentDate.weekday == DateTime.sunday) {
          currentDate = currentDate.add(const Duration(days: 1));
        }

        totalDayCounter++;
        final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

        plans.add(DsaDayPlan(
          dayNumber: totalDayCounter,
          weekNumber: weekNum,
          date: dateStr,
          topic: '$weekTopic - Day $totalDayCounter',
          watch: dayContent['watch']!,
          study: dayContent['study']!,
          practice: dayContent['practice']!,
          target: dayContent['target']!,
        ));

        // Advance to next day for next item
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }

    return plans;
  }

  /// Seeds all 90 weekday plans into AppProvider events & notes
  static Future<void> seedToApp(AppProvider provider) async {
    final plans = generate90DayPlan();

    for (var plan in plans) {
      // 1. Create Calendar Event for 90-day plan day
      final event = CalendarEvent(
        id: 'dsa_plan_${plan.dayNumber}_${plan.date}',
        title: 'DSA W${plan.weekNumber}D${plan.dayNumber}: ${plan.topic}',
        date: plan.date,
        startTime: '18:00',
        endTime: '21:00',
        category: 'Study',
        priority: 3,
        notes: 'Watch: ${plan.watch}\nStudy: ${plan.study}\nPractice: ${plan.practice}\nTarget: ${plan.target}',
      );
      await provider.addEvent(event);

      // 2. Create Note Item
      final note = NoteItem(
        id: 'dsa_note_${plan.dayNumber}_${plan.date}',
        title: 'DSA Day ${plan.dayNumber} (Week ${plan.weekNumber}): ${plan.topic}',
        body: '📅 Date: ${plan.date}\n\n🎥 WATCH:\n${plan.watch}\n\n📖 STUDY:\n${plan.study}\n\n💻 PRACTICE:\n${plan.practice}\n\n🎯 TARGET: ${plan.target}',
        category: 'DSA 90-Day Plan',
        date: plan.date,
      );
      await provider.addNote(note);
    }
  }
}
