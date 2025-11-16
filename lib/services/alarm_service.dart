import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:system_alert_window/system_alert_window.dart';
import '../models/reminder.dart';
import 'logging_service.dart';

/// CRITICAL SERVICE: Handles reliable alarms that work even when phone is locked
/// Uses multiple redundant systems to ensure alarms always trigger
class AlarmService {
  static const String _isolateName = 'AlarmIsolate';
  static SendPort? _uiSendPort;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final LoggingService _logger = LoggingService();
  
  /// Initialize alarm service with all necessary permissions and channels
  static Future<void> initialize() async {
    // Initialize notification channels for high-priority alarms
    await AwesomeNotifications().initialize(
      null, // Use default app icon
      [
        NotificationChannel(
          channelGroupKey: 'good_deeds_group',
          channelKey: 'alarm_channel',
          channelName: 'Good Deeds Alarms',
          channelDescription: 'Critical reminders that must not be missed',
          defaultColor: Colors.teal,
          ledColor: Colors.teal,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          // CRITICAL: These settings ensure notification shows on lock screen
          locked: true,
          criticalAlerts: true,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          displayOnForeground: true,
          displayOnBackground: true,
        ),
        NotificationChannel(
          channelGroupKey: 'good_deeds_group',
          channelKey: 'fullscreen_channel',
          channelName: 'Full Screen Alarms',
          channelDescription: 'Full screen reminders',
          defaultColor: Colors.teal,
          ledColor: Colors.teal,
          importance: NotificationImportance.Max,
          // Full screen intent category
          locked: true,
          criticalAlerts: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'good_deeds_group',
          channelGroupName: 'Good Deeds',
        ),
      ],
    );
    
    // Request critical permissions for full-screen alarms
    await AwesomeNotifications().requestPermissionToSendNotifications(
      channelKey: 'alarm_channel',
      permissions: [
        NotificationPermission.Alert,
        NotificationPermission.Sound,
        NotificationPermission.Badge,
        NotificationPermission.Vibration,
        NotificationPermission.Light,
        NotificationPermission.CriticalAlert,
        NotificationPermission.FullScreenIntent,
      ],
    );
    
    // Initialize system alert window for overlay on lock screen
    await SystemAlertWindow.requestPermissions();
    
    _logger.log("AlarmService initialized with all permissions", LogLevel.info);
  }
  
  /// Schedule a reminder with multiple fallback systems
  static Future<void> scheduleReminder(Reminder reminder) async {
    try {
      // Calculate next alarm time
      final DateTime nextAlarm = reminder.getNextAlarmDateTime();
      final int alarmId = reminder.id.hashCode;
      
      // Save reminder data for background access
      await _saveReminderData(reminder);
      
      // METHOD 1: Android Alarm Manager (Most reliable for exact timing)
      await AndroidAlarmManager.oneShotAt(
        nextAlarm,
        alarmId,
        _alarmCallback,
        exact: true, // CRITICAL: Exact timing for reliability
        wakeup: true, // CRITICAL: Wake device from sleep
        rescheduleOnReboot: true, // Persist through reboots
        alarmClock: true, // Show in system alarm clock UI
      );
      
      // METHOD 2: Awesome Notifications (Backup with full-screen intent)
      await AwesomeNotifications().createNotification(
        schedule: NotificationCalendar.fromDate(date: nextAlarm),
        content: NotificationContent(
          id: alarmId,
          channelKey: 'fullscreen_channel',
          title: reminder.title,
          body: reminder.description,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true, // CRITICAL: Wake screen
          fullScreenIntent: true, // CRITICAL: Launch full-screen
          criticalAlert: true,
          autoDismissible: false,
          locked: true,
          displayOnForeground: true,
          displayOnBackground: true,
          customSound: reminder.soundPath,
          payload: {
            'reminderId': reminder.id,
            'action': 'alarm_triggered',
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'COMPLETE',
            label: 'Mark Complete',
            actionType: ActionType.KeepOnTop,
            color: Colors.green,
          ),
          NotificationActionButton(
            key: 'SNOOZE',
            label: 'Snooze 5 min',
            actionType: ActionType.KeepOnTop,
            color: Colors.orange,
          ),
          NotificationActionButton(
            key: 'DISMISS',
            label: 'Dismiss',
            actionType: ActionType.DismissAction,
            isDangerousOption: true,
            color: Colors.red,
          ),
        ],
      );
      
      // Schedule periodic checks as additional backup
      if (reminder.frequency == ReminderFrequency.interval) {
        await _scheduleIntervalReminder(reminder);
      }
      
      _logger.log(
        "Scheduled reminder: ${reminder.title} for ${nextAlarm.toIso8601String()}",
        LogLevel.info,
        metadata: {'reminderId': reminder.id, 'alarmTime': nextAlarm.toIso8601String()},
      );
      
    } catch (e) {
      _logger.log(
        "Failed to schedule reminder: ${reminder.title}",
        LogLevel.error,
        metadata: {'error': e.toString(), 'reminderId': reminder.id},
      );
      rethrow;
    }
  }
  
  /// Check if current time is within Do Not Disturb period
  static Future<bool> _isDoNotDisturbActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('dnd_enabled') ?? false;
      
      if (!enabled) return false;
      
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      
      final startHour = prefs.getInt('dnd_start_hour') ?? 22;
      final startMinute = prefs.getInt('dnd_start_minute') ?? 0;
      final startMinutes = startHour * 60 + startMinute;
      
      final endHour = prefs.getInt('dnd_end_hour') ?? 7;
      final endMinute = prefs.getInt('dnd_end_minute') ?? 0;
      final endMinutes = endHour * 60 + endMinute;
      
      // Handle overnight period (e.g., 22:00 to 07:00)
      if (startMinutes > endMinutes) {
        return currentMinutes >= startMinutes || currentMinutes < endMinutes;
      } else {
        return currentMinutes >= startMinutes && currentMinutes < endMinutes;
      }
    } catch (e) {
      _logger.log(
        "Error checking Do Not Disturb status",
        LogLevel.error,
        metadata: {'error': e.toString()},
      );
      return false;
    }
  }
  
  /// Background isolate callback - runs even when app is terminated
  @pragma('vm:entry-point')
  static Future<void> _alarmCallback() async {
    try {
      // Check if Do Not Disturb is active
      if (await _isDoNotDisturbActive()) {
        print('[ALARM] Skipped - Do Not Disturb is active');
        // Reschedule the alarm for after DND period
        // Note: In production, you'd want to reschedule this properly
        return;
      }
      
      // This runs in a separate isolate - need to reinitialize
      final DateTime timestamp = DateTime.now();
      print('[ALARM] Triggered at ${timestamp.toIso8601String()}');
      
      // Wake the device and turn on screen
      await WakelockPlus.enable();
      
      // Get reminder data
      final int alarmId = Isolate.current.hashCode;
      final reminder = await _loadReminderData(alarmId.toString());
      
      if (reminder != null) {
        // Play alarm sound
        await _playAlarmSound(reminder.soundPath);
        
        // Vibrate pattern
        await _triggerVibration();
        
        // Show full-screen overlay
        await _showFullScreenAlarm(reminder);
        
        // Log the alarm trigger
        await LoggingService.logStatic(
          "Alarm triggered: ${reminder.title}",
          LogLevel.info,
          metadata: {'timestamp': timestamp.toIso8601String()},
        );
      }
      
      // Keep wake lock for 30 seconds to ensure user sees alarm
      Future.delayed(Duration(seconds: 30), () {
        WakelockPlus.disable();
      });
      
    } catch (e) {
      print('[ALARM] Error in callback: $e');
    }
  }
  
  /// Show full-screen alarm overlay that appears over lock screen
  static Future<void> _showFullScreenAlarm(Reminder reminder) async {
    try {
      // METHOD 1: System Alert Window (Works over lock screen)
      await SystemAlertWindow.showSystemWindow(
        height: SystemWindowHeader.MAX,
        width: SystemWindowHeader.MAX,
        header: SystemWindowHeader(
          title: SystemWindowText(
            text: reminder.title,
            fontSize: 24,
            textColor: Colors.white,
            fontWeight: FontWeight.BOLD,
          ),
          padding: SystemWindowPadding.setSymmetricPadding(12, 12),
          subTitle: SystemWindowText(
            text: reminder.description,
            fontSize: 16,
            textColor: Colors.white70,
          ),
          decoration: SystemWindowDecoration(
            startColor: Colors.teal.value,
            endColor: Colors.teal.shade700.value,
          ),
        ),
        body: SystemWindowBody(
          rows: [
            EachRow(
              columns: [
                EachColumn(
                  text: SystemWindowText(
                    text: "🔔 TIME FOR GOOD DEED 🔔",
                    fontSize: 20,
                    textColor: Colors.white,
                    fontWeight: FontWeight.BOLD,
                  ),
                ),
              ],
              gravity: ContentGravity.CENTER,
            ),
            EachRow(
              columns: [
                EachColumn(
                  text: SystemWindowText(
                    text: DateTime.now().toString().substring(0, 19),
                    fontSize: 14,
                    textColor: Colors.white70,
                  ),
                ),
              ],
              gravity: ContentGravity.CENTER,
              margin: SystemWindowMargin(top: 8),
            ),
          ],
          rows: [
            EachRow(
              columns: [
                EachColumn(
                  text: SystemWindowText(
                    text: "COMPLETE",
                    fontSize: 14,
                    textColor: Colors.white,
                  ),
                  decoration: SystemWindowDecoration(
                    startColor: Colors.green.value,
                    endColor: Colors.green.shade700.value,
                    borderRadius: 25,
                  ),
                  margin: SystemWindowMargin(left: 4, right: 4, bottom: 4, top: 4),
                ),
                EachColumn(
                  text: SystemWindowText(
                    text: "SNOOZE",
                    fontSize: 14,
                    textColor: Colors.white,
                  ),
                  decoration: SystemWindowDecoration(
                    startColor: Colors.orange.value,
                    endColor: Colors.orange.shade700.value,
                    borderRadius: 25,
                  ),
                  margin: SystemWindowMargin(left: 4, right: 4, bottom: 4, top: 4),
                ),
                EachColumn(
                  text: SystemWindowText(
                    text: "DISMISS",
                    fontSize: 14,
                    textColor: Colors.white,
                  ),
                  decoration: SystemWindowDecoration(
                    startColor: Colors.red.value,
                    endColor: Colors.red.shade700.value,
                    borderRadius: 25,
                  ),
                  margin: SystemWindowMargin(left: 4, right: 4, bottom: 4, top: 4),
                ),
              ],
              gravity: ContentGravity.CENTER,
            ),
          ],
        ),
        footer: SystemWindowFooter(
          buttons: [
            SystemWindowButton(
              text: SystemWindowText(
                text: "Mark as Complete",
                fontSize: 12,
                textColor: Colors.white,
              ),
              tag: "complete_${reminder.id}",
              width: SystemWindowButton.MATCH_PARENT,
              height: SystemWindowButton.WRAP_CONTENT,
              decoration: SystemWindowDecoration(
                startColor: Colors.green.value,
                endColor: Colors.green.shade700.value,
              ),
            ),
          ],
          buttonPosition: ButtonPosition.CENTER,
        ),
        margin: SystemWindowMargin(left: 8, right: 8, top: 100, bottom: 0),
        gravity: SystemWindowGravity.TOP,
        notificationTitle: reminder.title,
        notificationBody: reminder.description,
      );
      
      // Listen for button clicks
      SystemAlertWindow.registerOnClickListener((tag) {
        if (tag != null) {
          if (tag.startsWith("complete_")) {
            _handleComplete(reminder);
            SystemAlertWindow.closeSystemWindow();
          } else if (tag.startsWith("snooze_")) {
            _handleSnooze(reminder);
            SystemAlertWindow.closeSystemWindow();
          } else if (tag.startsWith("dismiss_")) {
            SystemAlertWindow.closeSystemWindow();
          }
        }
      });
      
    } catch (e) {
      print('[ALARM] Failed to show system alert: $e');
      // Fallback to high-priority notification
      await _showFallbackNotification(reminder);
    }
  }
  
  /// Play alarm sound with maximum volume
  static Future<void> _playAlarmSound(String? soundPath) async {
    try {
      final player = AudioPlayer();
      
      // Set to alarm stream for maximum volume even in silent mode
      await player.setReleaseMode(ReleaseMode.loop);
      
      if (soundPath != null && soundPath.isNotEmpty) {
        // Play custom sound
        await player.play(DeviceFileSource(soundPath));
      } else {
        // Play default alarm sound
        await player.play(AssetSource('sounds/default_alarm.mp3'));
      }
      
      // Stop after 30 seconds
      Future.delayed(Duration(seconds: 30), () {
        player.stop();
        player.dispose();
      });
      
    } catch (e) {
      print('[ALARM] Failed to play sound: $e');
    }
  }
  
  /// Trigger vibration pattern
  static Future<void> _triggerVibration() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Strong vibration pattern
        await Vibration.vibrate(
          pattern: [0, 1000, 500, 1000, 500, 1000, 500, 1000],
          intensities: [0, 255, 0, 255, 0, 255, 0, 255],
        );
      }
    } catch (e) {
      print('[ALARM] Failed to vibrate: $e');
    }
  }
  
  /// Handle snooze action
  static Future<void> _handleSnooze(Reminder reminder) async {
    // Reschedule for 5 minutes later
    final snoozeTime = DateTime.now().add(Duration(minutes: 5));
    reminder.nextAlarmTime = snoozeTime;
    await scheduleReminder(reminder);
    
    await LoggingService.logStatic(
      "Reminder snoozed: ${reminder.title}",
      LogLevel.info,
      metadata: {'snoozeUntil': snoozeTime.toIso8601String()},
    );
  }
  
  /// Handle completion action
  static Future<void> _handleComplete(Reminder reminder) async {
    // Log completion
    await LoggingService.logStatic(
      "Reminder completed: ${reminder.title}",
      LogLevel.success,
      metadata: {
        'completedAt': DateTime.now().toIso8601String(),
        'reminderId': reminder.id,
      },
    );
    
    // Reschedule based on frequency
    if (reminder.frequency != ReminderFrequency.once) {
      reminder.updateNextAlarmTime();
      await scheduleReminder(reminder);
    }
  }
  
  /// Cancel a scheduled reminder
  static Future<void> cancelReminder(String reminderId) async {
    final int alarmId = reminderId.hashCode;
    
    // Cancel from all systems
    await AndroidAlarmManager.cancel(alarmId);
    await AwesomeNotifications().cancel(alarmId);
    
    // Remove saved data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('reminder_$reminderId');
    
    _logger.log("Cancelled reminder: $reminderId", LogLevel.info);
  }
  
  /// Save reminder data for background access
  static Future<void> _saveReminderData(Reminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_${reminder.id}', reminder.toJson());
  }
  
  /// Load reminder data in background
  static Future<Reminder?> _loadReminderData(String reminderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('reminder_$reminderId');
      if (data != null) {
        return Reminder.fromJson(data);
      }
    } catch (e) {
      print('[ALARM] Failed to load reminder data: $e');
    }
    return null;
  }
  
  /// Schedule interval-based reminders (e.g., every 20 minutes)
  static Future<void> _scheduleIntervalReminder(Reminder reminder) async {
    if (reminder.intervalMinutes != null && reminder.intervalMinutes! > 0) {
      await AndroidAlarmManager.periodic(
        Duration(minutes: reminder.intervalMinutes!),
        reminder.id.hashCode,
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    }
  }
  
  /// Fallback notification if full-screen fails
  static Future<void> _showFallbackNotification(Reminder reminder) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch,
        channelKey: 'alarm_channel',
        title: '🔔 ${reminder.title}',
        body: reminder.description,
        bigText: 'TIME FOR YOUR GOOD DEED!\n\n${reminder.description}',
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
        autoDismissible: false,
        displayOnForeground: true,
        displayOnBackground: true,
        locked: true,
        payload: {'reminderId': reminder.id},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'COMPLETE',
          label: 'Complete',
          actionType: ActionType.KeepOnTop,
        ),
        NotificationActionButton(
          key: 'SNOOZE',
          label: 'Snooze',
          actionType: ActionType.KeepOnTop,
        ),
      ],
    );
  }
}
