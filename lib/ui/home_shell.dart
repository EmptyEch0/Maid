import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_provider.dart';
import '../services/alarm_service.dart';
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
  }

  @override
  void dispose() {
    _alarmSub?.cancel();
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



