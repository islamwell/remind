import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  success,
  critical
}

class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? stackTrace;
  
  LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
    this.metadata,
    this.stackTrace,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'level': level.toString(),
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'stackTrace': stackTrace,
    };
  }
  
  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      message: map['message'],
      level: _parseLevelFromString(map['level']),
      timestamp: DateTime.parse(map['timestamp']),
      metadata: map['metadata'],
      stackTrace: map['stackTrace'],
    );
  }
  
  static LogLevel _parseLevelFromString(String level) {
    return LogLevel.values.firstWhere(
      (e) => e.toString() == level,
      orElse: () => LogLevel.info,
    );
  }
  
  String toJson() => json.encode(toMap());
  
  factory LogEntry.fromJson(String source) => LogEntry.fromMap(json.decode(source));
}

class LoggingService {
  static const String _logsFileName = 'reminder_logs.json';
  static const String _completionsFileName = 'completion_logs.json';
  static const int _maxLogEntries = 10000; // Keep last 10k entries
  static const String _prefsKey = 'logging_enabled';
  
  static List<LogEntry> _logs = [];
  static List<LogEntry> _completionLogs = [];
  static bool _isInitialized = false;
  static bool _loggingEnabled = true;
  
  /// Initialize the logging service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _loggingEnabled = prefs.getBool(_prefsKey) ?? true;
      
      await _loadLogs();
      _isInitialized = true;
      
      // Set up Flutter error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        logStatic(
          'Flutter Error: ${details.exception}',
          LogLevel.error,
          metadata: {
            'library': details.library,
            'context': details.context?.toString(),
          },
          stackTrace: details.stack?.toString(),
        );
      };
      
      print('[LoggingService] Initialized with ${_logs.length} existing logs');
    } catch (e) {
      print('[LoggingService] Failed to initialize: $e');
    }
  }
  
  /// Load logs from storage
  static Future<void> _loadLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      // Load general logs
      final logsFile = File('${directory.path}/$_logsFileName');
      if (await logsFile.exists()) {
        final content = await logsFile.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _logs = jsonList.map((item) => LogEntry.fromMap(item)).toList();
      }
      
      // Load completion logs
      final completionsFile = File('${directory.path}/$_completionsFileName');
      if (await completionsFile.exists()) {
        final content = await completionsFile.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _completionLogs = jsonList.map((item) => LogEntry.fromMap(item)).toList();
      }
    } catch (e) {
      print('[LoggingService] Error loading logs: $e');
    }
  }
  
  /// Save logs to storage
  static Future<void> _saveLogs() async {
    if (!_loggingEnabled) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      
      // Save general logs
      final logsFile = File('${directory.path}/$_logsFileName');
      final logsJson = json.encode(_logs.map((e) => e.toMap()).toList());
      await logsFile.writeAsString(logsJson);
      
      // Save completion logs
      final completionsFile = File('${directory.path}/$_completionsFileName');
      final completionsJson = json.encode(_completionLogs.map((e) => e.toMap()).toList());
      await completionsFile.writeAsString(completionsJson);
    } catch (e) {
      print('[LoggingService] Error saving logs: $e');
    }
  }
  
  /// Instance method for logging
  void log(
    String message,
    LogLevel level, {
    Map<String, dynamic>? metadata,
    String? stackTrace,
  }) {
    logStatic(message, level, metadata: metadata, stackTrace: stackTrace);
  }
  
  /// Static method for logging (can be called from isolates)
  static Future<void> logStatic(
    String message,
    LogLevel level, {
    Map<String, dynamic>? metadata,
    String? stackTrace,
  }) async {
    if (!_loggingEnabled) return;
    
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
      metadata: metadata,
      stackTrace: stackTrace,
    );
    
    // Add to appropriate list
    if (message.toLowerCase().contains('complet') || 
        metadata?['type'] == 'completion') {
      _completionLogs.add(entry);
      
      // Trim if too many entries
      if (_completionLogs.length > _maxLogEntries) {
        _completionLogs = _completionLogs.sublist(
          _completionLogs.length - _maxLogEntries,
        );
      }
    }
    
    _logs.add(entry);
    
    // Trim if too many entries
    if (_logs.length > _maxLogEntries) {
      _logs = _logs.sublist(_logs.length - _maxLogEntries);
    }
    
    // Print to console in debug mode
    if (kDebugMode) {
      final levelEmoji = _getLevelEmoji(level);
      print('$levelEmoji [${level.name.toUpperCase()}] ${entry.timestamp.toIso8601String()}: $message');
      if (metadata != null) {
        print('   Metadata: $metadata');
      }
      if (stackTrace != null && level == LogLevel.error) {
        print('   Stack: $stackTrace');
      }
    }
    
    // Save to disk periodically (every 10 logs)
    if (_logs.length % 10 == 0) {
      await _saveLogs();
    }
    
    // For critical errors, save immediately
    if (level == LogLevel.critical || level == LogLevel.error) {
      await _saveLogs();
    }
  }
  
  /// Log reminder completion
  static Future<void> logCompletion(
    String reminderId,
    String reminderTitle, {
    Map<String, dynamic>? additionalData,
  }) async {
    final metadata = {
      'type': 'completion',
      'reminderId': reminderId,
      'reminderTitle': reminderTitle,
      'timestamp': DateTime.now().toIso8601String(),
      ...?additionalData,
    };
    
    await logStatic(
      'Completed: $reminderTitle',
      LogLevel.success,
      metadata: metadata,
    );
  }
  
  /// Log reminder snooze
  static Future<void> logSnooze(
    String reminderId,
    String reminderTitle,
    int snoozeMinutes,
  ) async {
    final metadata = {
      'type': 'snooze',
      'reminderId': reminderId,
      'reminderTitle': reminderTitle,
      'snoozeMinutes': snoozeMinutes,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await logStatic(
      'Snoozed: $reminderTitle for $snoozeMinutes minutes',
      LogLevel.info,
      metadata: metadata,
    );
  }
  
  /// Log reminder dismissal
  static Future<void> logDismissal(
    String reminderId,
    String reminderTitle,
  ) async {
    final metadata = {
      'type': 'dismissal',
      'reminderId': reminderId,
      'reminderTitle': reminderTitle,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await logStatic(
      'Dismissed: $reminderTitle',
      LogLevel.warning,
      metadata: metadata,
    );
  }
  
  /// Get all logs
  static List<LogEntry> getLogs() => List.from(_logs);
  
  /// Get completion logs
  static List<LogEntry> getCompletionLogs() => List.from(_completionLogs);
  
  /// Get logs filtered by level
  static List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }
  
  /// Get logs for a specific reminder
  static List<LogEntry> getLogsForReminder(String reminderId) {
    return _logs.where((log) => 
      log.metadata?['reminderId'] == reminderId
    ).toList();
  }
  
  /// Get logs within date range
  static List<LogEntry> getLogsInRange(DateTime start, DateTime end) {
    return _logs.where((log) =>
      log.timestamp.isAfter(start) && log.timestamp.isBefore(end)
    ).toList();
  }
  
  /// Get completion statistics
  static Map<String, dynamic> getCompletionStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(Duration(days: 7));
    final monthAgo = today.subtract(Duration(days: 30));
    
    final todayCompletions = _completionLogs.where((log) =>
      log.timestamp.isAfter(today)
    ).length;
    
    final weekCompletions = _completionLogs.where((log) =>
      log.timestamp.isAfter(weekAgo)
    ).length;
    
    final monthCompletions = _completionLogs.where((log) =>
      log.timestamp.isAfter(monthAgo)
    ).length;
    
    // Group by reminder
    final completionsByReminder = <String, int>{};
    for (final log in _completionLogs) {
      final title = log.metadata?['reminderTitle'] ?? 'Unknown';
      completionsByReminder[title] = (completionsByReminder[title] ?? 0) + 1;
    }
    
    return {
      'total': _completionLogs.length,
      'today': todayCompletions,
      'thisWeek': weekCompletions,
      'thisMonth': monthCompletions,
      'byReminder': completionsByReminder,
      'mostCompleted': completionsByReminder.isEmpty 
        ? null 
        : completionsByReminder.entries.reduce((a, b) => 
            a.value > b.value ? a : b
          ).key,
    };
  }
  
  /// Clear all logs
  static Future<void> clearLogs() async {
    _logs.clear();
    _completionLogs.clear();
    await _saveLogs();
    await logStatic('Logs cleared', LogLevel.info);
  }
  
  /// Export logs as JSON
  static Future<String> exportLogs() async {
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'generalLogs': _logs.map((e) => e.toMap()).toList(),
      'completionLogs': _completionLogs.map((e) => e.toMap()).toList(),
      'statistics': getCompletionStats(),
    };
    
    return json.encode(exportData);
  }
  
  /// Toggle logging enabled/disabled
  static Future<void> setLoggingEnabled(bool enabled) async {
    _loggingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    
    if (enabled) {
      await logStatic('Logging enabled', LogLevel.info);
    }
  }
  
  static bool get isLoggingEnabled => _loggingEnabled;
  
  /// Get emoji for log level
  static String _getLevelEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
      case LogLevel.critical:
        return '🚨';
    }
  }
}

// Convenience logger instance
final logger = LoggingService();
