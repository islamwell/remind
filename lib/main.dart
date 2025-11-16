import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:io';
import 'models/reminder.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'screens/modern_main_screen.dart';
import 'screens/full_screen_alarm.dart';
import 'screens/add_reminder.dart';
import 'screens/logs_screen.dart';
import 'screens/settings_screen.dart';
import 'services/logging_service.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await NotificationService.initialize();
  await AndroidAlarmManager.initialize();
  await LoggingService.initialize();
  
  // Request critical permissions
  await _requestPermissions();
  
  runApp(GoodDeedsReminderApp());
}

Future<void> _requestPermissions() async {
  // Critical permissions for reliable alarms
  await [
    Permission.notification,
    Permission.systemAlertWindow, // For full-screen overlay
    Permission.ignoreBatteryOptimizations, // Prevent Doze mode interference
    Permission.scheduleExactAlarm, // For exact alarms Android 12+
    Permission.microphone, // For voice recording
    Permission.storage, // For file access
  ].request();
  
  // Ensure app can draw over other apps (critical for lock screen)
  if (Platform.isAndroid) {
    if (!await Permission.systemAlertWindow.isGranted) {
      // Direct user to settings if permission not granted
      await openAppSettings();
    }
  }
}

class GoodDeedsReminderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Good Deeds Reminder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      home: ModernMainScreen(),
      routes: {
        '/fullScreenAlarm': (context) => FullScreenAlarmScreen(),
        '/addReminder': (context) => AddReminderScreen(),
      },
    );
  }
}
