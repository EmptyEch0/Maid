import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';
import '../engine/local_query_engine.dart';
import 'app_lock_screen.dart';
import 'screens/voice_assistant_screen.dart';
import 'screens/tasks_inbox_screen.dart';
import 'screens/alarms_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/study_timer_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/alarm_ringing_dialog.dart';
import 'widgets/voice_quick_action_fab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  StreamSubscription<AlarmItem>? _alarmSub;
  StreamSubscription<Uri?>? _widgetSub;

  final List<Widget> _screens = const [
    VoiceAssistantScreen(),
    TasksInboxScreen(),
    AlarmsScreen(),
    CalendarScreen(),
    StudyTimerScreen(),
    NotesScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Listen for live triggered alarms to pop up ringing dialog
    _alarmSub = AlarmService.instance.onAlarmTriggered.listen((alarm) {
      if (mounted) {
        AlarmRingingDialog.show(context, alarm);
      }
    });

    // Handle notification click
    NotificationService.instance.onNotificationClick = (payload) {
      if (payload != null && mounted) {
        final provider = Provider.of<AppProvider>(context, listen: false);
        final matching = provider.alarms.where((a) => a.id == payload).toList();
        if (matching.isNotEmpty) {
          AlarmRingingDialog.show(context, matching.first);
        }
      }
    };

    // Listen for Widget click actions (Mic button, Add button, Open App)
    _initHomeWidgetListener();
  }

  Future<void> _initHomeWidgetListener() async {
    // Check if launched from widget
    final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initialUri != null) {
      _handleWidgetUri(initialUri);
    }

    // Listen to background/foreground clicks from home widget
    _widgetSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleWidgetUri(uri);
      }
    });
  }

  void _handleWidgetUri(Uri uri) {
    final uriStr = uri.toString();
    if (uriStr.contains('read_aloud') || uriStr.contains('voice')) {
      setState(() => _currentIndex = 0); // Assistant
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final provider = Provider.of<AppProvider>(context, listen: false);
        final result = await LocalQueryEngine.processQuery('tell my work', provider);
        await TtsService.instance.stop();
        await TtsService.instance.speak(result.spokenText);
      });
    } else if (uriStr.contains('add_task')) {
      setState(() => _currentIndex = 1); // Tasks
    } else if (uriStr.contains('tasks')) {
      setState(() => _currentIndex = 1); // Tasks
    }
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
    _widgetSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // If app is locked, render Lock screen
    if (!provider.isUnlocked) {
      return const AppLockScreen();
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: VoiceQuickActionFab(
        onOpenAddAlarm: () {
          setState(() => _currentIndex = 2); // Switch to Alarms tab
        },
        onOpenAddHabit: () {
          setState(() => _currentIndex = 2); // Switch to Alarms/Habits tab
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'Assistant'),
          NavigationDestination(icon: Icon(Icons.task_alt_rounded), label: 'Tasks'),
          NavigationDestination(icon: Icon(Icons.alarm_rounded), label: 'Alarms'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.timer_rounded), label: 'Study'),
          NavigationDestination(icon: Icon(Icons.note_alt_rounded), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Review'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
