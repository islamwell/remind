import 'package:flutter/material.dart';
import 'dart:convert';

enum ReminderFrequency {
  once,
  daily,
  weekly,
  monthly,
  interval, // Every X minutes
  custom
}

enum ReminderCategory {
  family,
  charity,
  health,
  spiritual,
  work,
  personal
}

class Reminder {
  final String id;
  String title;
  String description;
  ReminderFrequency frequency;
  TimeOfDay? scheduledTime;
  List<int>? weekDays; // For weekly: 1=Mon, 7=Sun
  int? dayOfMonth; // For monthly
  int? intervalMinutes; // For interval
  DateTime? nextAlarmTime;
  bool isActive;
  String? soundPath; // Path to custom sound file
  String? recordedVoicePath; // Path to recorded voice
  IconData icon;
  ReminderCategory category;
  Map<String, dynamic>? customData;
  List<DateTime> completionHistory;
  int snoozeCount;
  DateTime createdAt;
  DateTime updatedAt;
  
  Reminder({
    String? id,
    required this.title,
    required this.description,
    required this.frequency,
    this.scheduledTime,
    this.weekDays,
    this.dayOfMonth,
    this.intervalMinutes,
    this.nextAlarmTime,
    this.isActive = true,
    this.soundPath,
    this.recordedVoicePath,
    IconData? icon,
    ReminderCategory? category,
    this.customData,
    List<DateTime>? completionHistory,
    this.snoozeCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    icon = icon ?? Icons.notifications,
    category = category ?? ReminderCategory.personal,
    completionHistory = completionHistory ?? [],
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now() {
      // Calculate initial next alarm time
      updateNextAlarmTime();
    }
  
  /// Calculate the next alarm time based on frequency
  DateTime getNextAlarmDateTime() {
    final now = DateTime.now();
    
    switch (frequency) {
      case ReminderFrequency.once:
        return nextAlarmTime ?? now.add(Duration(minutes: 1));
        
      case ReminderFrequency.daily:
        if (scheduledTime != null) {
          var next = DateTime(
            now.year,
            now.month,
            now.day,
            scheduledTime!.hour,
            scheduledTime!.minute,
          );
          if (next.isBefore(now)) {
            next = next.add(Duration(days: 1));
          }
          return next;
        }
        return now.add(Duration(days: 1));
        
      case ReminderFrequency.weekly:
        if (weekDays != null && weekDays!.isNotEmpty && scheduledTime != null) {
          // Find next occurrence of selected weekday
          for (int i = 0; i < 7; i++) {
            final testDate = now.add(Duration(days: i));
            if (weekDays!.contains(testDate.weekday)) {
              final alarmTime = DateTime(
                testDate.year,
                testDate.month,
                testDate.day,
                scheduledTime!.hour,
                scheduledTime!.minute,
              );
              if (alarmTime.isAfter(now)) {
                return alarmTime;
              }
            }
          }
        }
        return now.add(Duration(days: 7));
        
      case ReminderFrequency.monthly:
        if (dayOfMonth != null && scheduledTime != null) {
          var next = DateTime(
            now.year,
            now.month,
            dayOfMonth!,
            scheduledTime!.hour,
            scheduledTime!.minute,
          );
          if (next.isBefore(now)) {
            // Move to next month
            next = DateTime(
              now.month == 12 ? now.year + 1 : now.year,
              now.month == 12 ? 1 : now.month + 1,
              dayOfMonth!,
              scheduledTime!.hour,
              scheduledTime!.minute,
            );
          }
          return next;
        }
        return now.add(Duration(days: 30));
        
      case ReminderFrequency.interval:
        if (intervalMinutes != null && intervalMinutes! > 0) {
          return now.add(Duration(minutes: intervalMinutes!));
        }
        return now.add(Duration(minutes: 20));
        
      case ReminderFrequency.custom:
        return nextAlarmTime ?? now.add(Duration(hours: 1));
        
      default:
        return now.add(Duration(hours: 1));
    }
  }
  
  /// Update the next alarm time after completion or snooze
  void updateNextAlarmTime() {
    nextAlarmTime = getNextAlarmDateTime();
    updatedAt = DateTime.now();
  }
  
  /// Mark reminder as completed
  void markCompleted() {
    completionHistory.add(DateTime.now());
    snoozeCount = 0; // Reset snooze count
    updateNextAlarmTime();
  }
  
  /// Snooze the reminder
  void snooze(int minutes) {
    nextAlarmTime = DateTime.now().add(Duration(minutes: minutes));
    snoozeCount++;
    updatedAt = DateTime.now();
  }
  
  /// Get formatted next alarm time
  String getNextAlarmTime() {
    if (nextAlarmTime == null) return "Not scheduled";
    
    final now = DateTime.now();
    final diff = nextAlarmTime!.difference(now);
    
    if (diff.inMinutes < 60) {
      return "In ${diff.inMinutes} minutes";
    } else if (diff.inHours < 24) {
      return "In ${diff.inHours} hours";
    } else if (diff.inDays == 1) {
      return "Tomorrow at ${TimeOfDay.fromDateTime(nextAlarmTime!).format(null)}";
    } else if (diff.inDays < 7) {
      return "In ${diff.inDays} days";
    } else {
      return "${nextAlarmTime!.day}/${nextAlarmTime!.month} at ${TimeOfDay.fromDateTime(nextAlarmTime!).format(null)}";
    }
  }
  
  /// Get completion statistics
  Map<String, dynamic> getStatistics() {
    final now = DateTime.now();
    final last30Days = completionHistory.where((date) => 
      date.isAfter(now.subtract(Duration(days: 30)))
    ).length;
    
    final last7Days = completionHistory.where((date) => 
      date.isAfter(now.subtract(Duration(days: 7)))
    ).length;
    
    final today = completionHistory.where((date) => 
      date.year == now.year && 
      date.month == now.month && 
      date.day == now.day
    ).length;
    
    return {
      'total': completionHistory.length,
      'last30Days': last30Days,
      'last7Days': last7Days,
      'today': today,
      'streak': _calculateStreak(),
    };
  }
  
  /// Calculate current streak
  int _calculateStreak() {
    if (completionHistory.isEmpty) return 0;
    
    // Sort completion history
    final sorted = List<DateTime>.from(completionHistory)
      ..sort((a, b) => b.compareTo(a));
    
    int streak = 0;
    DateTime? lastDate;
    
    for (final date in sorted) {
      if (lastDate == null) {
        streak = 1;
        lastDate = date;
      } else {
        final dayDiff = lastDate.difference(date).inDays;
        if (dayDiff == 1) {
          streak++;
          lastDate = date;
        } else {
          break;
        }
      }
    }
    
    return streak;
  }
  
  /// Convert to JSON
  String toJson() {
    return json.encode({
      'id': id,
      'title': title,
      'description': description,
      'frequency': frequency.index,
      'scheduledTime': scheduledTime != null 
        ? {'hour': scheduledTime!.hour, 'minute': scheduledTime!.minute}
        : null,
      'weekDays': weekDays,
      'dayOfMonth': dayOfMonth,
      'intervalMinutes': intervalMinutes,
      'nextAlarmTime': nextAlarmTime?.toIso8601String(),
      'isActive': isActive,
      'soundPath': soundPath,
      'recordedVoicePath': recordedVoicePath,
      'icon': icon.codePoint,
      'category': category.index,
      'customData': customData,
      'completionHistory': completionHistory.map((d) => d.toIso8601String()).toList(),
      'snoozeCount': snoozeCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    });
  }
  
  /// Create from JSON
  factory Reminder.fromJson(String jsonString) {
    final data = json.decode(jsonString);
    return Reminder(
      id: data['id'],
      title: data['title'],
      description: data['description'],
      frequency: ReminderFrequency.values[data['frequency']],
      scheduledTime: data['scheduledTime'] != null
        ? TimeOfDay(
            hour: data['scheduledTime']['hour'],
            minute: data['scheduledTime']['minute'],
          )
        : null,
      weekDays: data['weekDays'] != null 
        ? List<int>.from(data['weekDays'])
        : null,
      dayOfMonth: data['dayOfMonth'],
      intervalMinutes: data['intervalMinutes'],
      nextAlarmTime: data['nextAlarmTime'] != null 
        ? DateTime.parse(data['nextAlarmTime'])
        : null,
      isActive: data['isActive'],
      soundPath: data['soundPath'],
      recordedVoicePath: data['recordedVoicePath'],
      icon: IconData(data['icon'], fontFamily: 'MaterialIcons'),
      category: ReminderCategory.values[data['category']],
      customData: data['customData'],
      completionHistory: (data['completionHistory'] as List)
        .map((d) => DateTime.parse(d))
        .toList(),
      snoozeCount: data['snoozeCount'],
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
    );
  }
  
  /// Create from template
  factory Reminder.fromTemplate(ReminderTemplate template) {
    return Reminder(
      title: template.name,
      description: template.description,
      frequency: template.frequency,
      scheduledTime: template.time,
      intervalMinutes: template.intervalMinutes,
      icon: template.icon,
      category: _getCategoryFromString(template.category),
    );
  }
  
  static ReminderCategory _getCategoryFromString(String category) {
    switch (category.toLowerCase()) {
      case 'family':
        return ReminderCategory.family;
      case 'charity':
        return ReminderCategory.charity;
      case 'health':
        return ReminderCategory.health;
      case 'spiritual':
        return ReminderCategory.spiritual;
      case 'work':
        return ReminderCategory.work;
      default:
        return ReminderCategory.personal;
    }
  }
}

/// Template for quick reminder creation
class ReminderTemplate {
  final String name;
  final String description;
  final ReminderFrequency frequency;
  final TimeOfDay? time;
  final int? intervalMinutes;
  final IconData icon;
  final String category;
  
  const ReminderTemplate({
    required this.name,
    required this.description,
    required this.frequency,
    this.time,
    this.intervalMinutes,
    required this.icon,
    required this.category,
  });
}
