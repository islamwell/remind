import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/logging_service.dart';

class LogsScreen extends StatefulWidget {
  @override
  _LogsScreenState createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogEntry> logs = [];
  String filter = 'all';
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  void _loadLogs() {
    setState(() {
      if (filter == 'all') {
        logs = LoggingService.getLogs();
      } else if (filter == 'completions') {
        logs = LoggingService.getCompletionLogs();
      } else if (filter == 'errors') {
        logs = LoggingService.getLogsByLevel(LogLevel.error);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final stats = LoggingService.getCompletionStats();
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Activity Logs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: AppTheme.textPrimary),
            onPressed: _exportLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Section
          Container(
            padding: EdgeInsets.all(20),
            color: AppTheme.surface,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        label: 'Total',
                        value: stats['total'].toString(),
                        color: AppTheme.info,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'Today',
                        value: stats['today'].toString(),
                        color: AppTheme.success,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        label: 'This Week',
                        value: stats['thisWeek'].toString(),
                        color: AppTheme.warning,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      SizedBox(width: 8),
                      _buildFilterChip('Completions', 'completions'),
                      SizedBox(width: 8),
                      _buildFilterChip('Errors', 'errors'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Logs List
          Expanded(
            child: logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: AppTheme.textTertiary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No logs yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(20),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[logs.length - 1 - index];
                    return _buildLogEntry(log);
                  },
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = filter == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          filter = value;
        });
        _loadLogs();
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusRound),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primaryGreen 
            : AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusRound),
          border: Border.all(
            color: isSelected 
              ? AppTheme.primaryGreen 
              : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
              ? Colors.white 
              : AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogEntry(LogEntry log) {
    Color levelColor;
    IconData levelIcon;
    
    switch (log.level) {
      case LogLevel.success:
        levelColor = AppTheme.success;
        levelIcon = Icons.check_circle;
        break;
      case LogLevel.error:
        levelColor = AppTheme.error;
        levelIcon = Icons.error;
        break;
      case LogLevel.warning:
        levelColor = AppTheme.warning;
        levelIcon = Icons.warning;
        break;
      default:
        levelColor = AppTheme.info;
        levelIcon = Icons.info;
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              levelIcon,
              color: levelColor,
              size: 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _formatTime(log.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                if (log.metadata != null) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      log.metadata.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else {
      return '${time.day}/${time.month} at ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
  
  void _exportLogs() async {
    try {
      final exportData = await LoggingService.exportLogs();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logs exported successfully'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export logs'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
