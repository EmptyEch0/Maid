import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService instance = PermissionService._init();
  PermissionService._init();

  /// Requests all necessary permissions for notifications, alarms, and voice assistant when app launches.
  Future<void> requestAllAppPermissions() async {
    // Only perform on mobile platforms (Android / iOS)
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      // 1. Request Notification Permission
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }

      // 2. Request Microphone Permission for Voice Assistant
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        await Permission.microphone.request();
      }

      // 3. Request Speech Recognition Permission (iOS & Android)
      final speechStatus = await Permission.speech.status;
      if (!speechStatus.isGranted) {
        await Permission.speech.request();
      }

      // 4. Request Exact Alarm Permission on Android 12+
      if (Platform.isAndroid) {
        final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
        if (!exactAlarmStatus.isGranted) {
          await Permission.scheduleExactAlarm.request();
        }
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  /// Checks if critical permissions are granted
  Future<bool> hasMicrophonePermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    return await Permission.microphone.isGranted;
  }

  Future<bool> hasNotificationPermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return true;
    return await Permission.notification.isGranted;
  }
}
