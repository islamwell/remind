import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/reminder.dart';
import '../screens/full_screen_alarm.dart';
import 'logging_service.dart';
import 'alarm_service.dart';

/// Service for handling notifications and their actions
class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  /// Initialize notification service
  static Future<void> initialize() async {
    // Initialize Flutter Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundNotificationResponse,
    );
    
    // Request Android 13+ notification permission
    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    
    // Request exact alarm permission for Android 12+
    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
    
    LoggingService.logStatic(
      "NotificationService initialized",
      LogLevel.info,
    );
  }
  
  /// Handle notification tap when app is in foreground
  static void _onNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload != null) {
      await _handleNotificationAction(response.actionId, payload);
    }
  }
  
  /// Handle notification tap when app is in background
  @pragma('vm:entry-point')
  static void _backgroundNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    if (payload != null) {
      await _handleNotificationAction(response.actionId, payload);
    }
  }
  
  /// Handle notification action based on action ID
  static Future<void> _handleNotificationAction(String? actionId, String payload) async {
    try {
      final data = Uri.parse(payload).queryParameters;
      final reminderId = data['reminderId'];
      
      if (reminderId == null) return;
      
      switch (actionId) {
        case 'COMPLETE':
          await LoggingService.logCompletion(
            reminderId,
            data['title'] ?? 'Reminder',
          );
          // Reschedule if recurring
          // Implementation would load reminder and reschedule
          break;
          
        case 'SNOOZE':
          await LoggingService.logSnooze(
            reminderId,
            data['title'] ?? 'Reminder',
            5,
          );
          // Schedule snooze alarm
          // Implementation would create new alarm 5 minutes later
          break;
          
        case 'DISMISS':
          await LoggingService.logDismissal(
            reminderId,
            data['title'] ?? 'Reminder',
          );
          break;
          
        default:
          // Open full screen alarm if notification is tapped
          // Note: In real implementation, this would navigate to the alarm screen
          break;
      }
    } catch (e) {
      print('Error handling notification action: $e');
    }
  }
  
  /// Awesome Notifications callbacks (static for background access)
  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    LoggingService.logStatic(
      "Notification created: ${receivedNotification.title}",
      LogLevel.debug,
    );
  }
  
  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    LoggingService.logStatic(
      "Notification displayed: ${receivedNotification.title}",
      LogLevel.info,
      metadata: {
        'notificationId': receivedNotification.id,
        'channelKey': receivedNotification.channelKey,
      },
    );
  }
  
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    final payload = receivedAction.payload ?? {};
    final reminderId = payload['reminderId'];
    final reminderTitle = receivedAction.title ?? 'Reminder';
    
    LoggingService.logStatic(
      "Notification action received: ${receivedAction.buttonKeyPressed}",
      LogLevel.info,
      metadata: {
        'action': receivedAction.buttonKeyPressed,
        'reminderId': reminderId,
      },
    );
    
    switch (receivedAction.buttonKeyPressed) {
      case 'COMPLETE':
        await LoggingService.logCompletion(
          reminderId ?? '',
          reminderTitle,
          additionalData: {
            'completedVia': 'notification',
          },
        );
        
        // Cancel notification
        await AwesomeNotifications().cancel(receivedAction.id!);
        
        // Show success notification
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: DateTime.now().millisecondsSinceEpoch,
            channelKey: 'alarm_channel',
            title: '✅ Good Deed Complete!',
            body: '$reminderTitle has been marked as complete',
            autoDismissible: true,
            duration: Duration(seconds: 5),
          ),
        );
        break;
        
      case 'SNOOZE':
        await LoggingService.logSnooze(
          reminderId ?? '',
          reminderTitle,
          5,
        );
        
        // Cancel current notification
        await AwesomeNotifications().cancel(receivedAction.id!);
        
        // Schedule snooze notification
        await AwesomeNotifications().createNotification(
          schedule: NotificationCalendar.fromDate(
            date: DateTime.now().add(Duration(minutes: 5)),
          ),
          content: NotificationContent(
            id: receivedAction.id!,
            channelKey: 'alarm_channel',
            title: '🔔 Snoozed: $reminderTitle',
            body: 'Your reminder will ring again in 5 minutes',
            category: NotificationCategory.Alarm,
            wakeUpScreen: true,
            fullScreenIntent: true,
            criticalAlert: true,
            autoDismissible: false,
            payload: payload,
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
              label: 'Snooze Again',
              actionType: ActionType.KeepOnTop,
              color: Colors.orange,
            ),
            NotificationActionButton(
              key: 'DISMISS',
              label: 'Dismiss',
              actionType: ActionType.DismissAction,
              color: Colors.red,
            ),
          ],
        );
        break;
        
      case 'DISMISS':
        await LoggingService.logDismissal(
          reminderId ?? '',
          reminderTitle,
        );
        await AwesomeNotifications().cancel(receivedAction.id!);
        break;
        
      default:
        // Notification body tapped - try to show full screen
        if (receivedAction.payload?['action'] == 'alarm_triggered') {
          // In a real app, this would navigate to FullScreenAlarmScreen
          // For now, just log it
          LoggingService.logStatic(
            "Notification tapped - would show full screen alarm",
            LogLevel.info,
          );
        }
    }
  }
  
  /// Show a high-priority notification (backup for full-screen alarm)
  static Future<void> showHighPriorityNotification(Reminder reminder) async {
    try {
      // Using Flutter Local Notifications for more control
      const androidDetails = AndroidNotificationDetails(
        'alarm_channel_high',
        'High Priority Alarms',
        channelDescription: 'Critical reminders that must not be missed',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
        enableLights: true,
        ledColor: Color(0xFF00BFA5),
        ledOnMs: 1000,
        ledOffMs: 500,
        showWhen: true,
        when: DateTime.now().millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: false,
        ongoing: true,
        autoCancel: false,
        actions: [
          AndroidNotificationAction(
            'complete',
            'Complete',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze',
            'Snooze 5 min',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'dismiss',
            'Dismiss',
            cancelNotification: true,
          ),
        ],
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
        sound: 'alarm.aiff',
      );
      
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      final payload = Uri(
        queryParameters: {
          'reminderId': reminder.id,
          'title': reminder.title,
          'action': 'alarm',
        },
      ).toString();
      
      await _localNotifications.show(
        reminder.id.hashCode,
        '🔔 ${reminder.title}',
        reminder.description,
        notificationDetails,
        payload: payload,
      );
      
      LoggingService.logStatic(
        "High priority notification shown: ${reminder.title}",
        LogLevel.info,
      );
      
    } catch (e) {
      LoggingService.logStatic(
        "Failed to show high priority notification",
        LogLevel.error,
        metadata: {'error': e.toString()},
      );
    }
  }
  
  /// Cancel a notification
  static Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
    await AwesomeNotifications().cancel(id);
  }
  
  /// Get pending notifications
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }
  
  /// Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final awesomeEnabled = await AwesomeNotifications().isNotificationAllowed();
    
    // Also check system settings
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final systemEnabled = await androidImplementation?.areNotificationsEnabled() ?? false;
    
    return awesomeEnabled && systemEnabled;
  }
  
  /// Request notification permissions if not granted
  static Future<bool> requestPermissions() async {
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      return await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    return true;
  }
  
  /// Show test notification to verify system is working
  static Future<void> showTestNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch,
        channelKey: 'alarm_channel',
        title: '🔔 Test Reminder',
        body: 'This is a test notification. Your reminders are working!',
        bigText: 'If you can see this notification, your Good Deeds Reminder app is properly configured and will alert you even when your phone is locked.',
        category: NotificationCategory.Alarm,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
        autoDismissible: false,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'TEST_COMPLETE',
          label: 'Great!',
          actionType: ActionType.DismissAction,
          color: Colors.green,
        ),
      ],
    );
    
    LoggingService.logStatic(
      "Test notification sent",
      LogLevel.info,
    );
  }
}
