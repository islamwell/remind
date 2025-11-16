import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';
import '../services/notification_service.dart';
import '../services/logging_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _loggingEnabled = true;
  bool _doNotDisturbEnabled = false;
  TimeOfDay _doNotDisturbStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _doNotDisturbEnd = TimeOfDay(hour: 7, minute: 0);
  String _snoozeTime = '5';
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notifEnabled = await NotificationService.areNotificationsEnabled();
    setState(() {
      _notificationsEnabled = notifEnabled;
      _loggingEnabled = LoggingService.isLoggingEnabled;
      _doNotDisturbEnabled = prefs.getBool('dnd_enabled') ?? false;
      _doNotDisturbStart = TimeOfDay(
        hour: prefs.getInt('dnd_start_hour') ?? 22,
        minute: prefs.getInt('dnd_start_minute') ?? 0,
      );
      _doNotDisturbEnd = TimeOfDay(
        hour: prefs.getInt('dnd_end_hour') ?? 7,
        minute: prefs.getInt('dnd_end_minute') ?? 0,
      );
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Settings',
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
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Notifications Section
            _buildSection(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              children: [
                _buildSwitchTile(
                  title: 'Enable Notifications',
                  subtitle: 'Receive reminder alerts',
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final granted = await NotificationService.requestPermissions();
                      setState(() {
                        _notificationsEnabled = granted;
                      });
                    } else {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    }
                  },
                ),
                _buildSwitchTile(
                  title: 'Sound',
                  subtitle: 'Play alarm sounds',
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                    });
                  },
                ),
                _buildSwitchTile(
                  title: 'Vibration',
                  subtitle: 'Vibrate on alarm',
                  value: _vibrationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _vibrationEnabled = value;
                    });
                  },
                ),
              ],
            ),
            
            // Do Not Disturb Section
            _buildSection(
              title: 'Do Not Disturb',
              icon: Icons.do_not_disturb_on,
              children: [
                _buildSwitchTile(
                  title: 'Enable Do Not Disturb',
                  subtitle: 'Silence reminders during set hours',
                  value: _doNotDisturbEnabled,
                  onChanged: (value) {
                    setState(() {
                      _doNotDisturbEnabled = value;
                    });
                    _saveDoNotDisturbSettings();
                  },
                ),
                if (_doNotDisturbEnabled) ...[
                  _buildTimeTile(
                    title: 'Start Time',
                    subtitle: 'When to start silencing',
                    time: _doNotDisturbStart,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _doNotDisturbStart,
                      );
                      if (picked != null) {
                        setState(() {
                          _doNotDisturbStart = picked;
                        });
                        _saveDoNotDisturbSettings();
                      }
                    },
                  ),
                  _buildTimeTile(
                    title: 'End Time',
                    subtitle: 'When to resume reminders',
                    time: _doNotDisturbEnd,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _doNotDisturbEnd,
                      );
                      if (picked != null) {
                        setState(() {
                          _doNotDisturbEnd = picked;
                        });
                        _saveDoNotDisturbSettings();
                      }
                    },
                  ),
                ],
              ],
            ),
            
            // Snooze Settings
            _buildSection(
              title: 'Snooze',
              icon: Icons.snooze,
              children: [
                _buildDropdownTile(
                  title: 'Snooze Duration',
                  subtitle: 'Time to delay reminder',
                  value: _snoozeTime,
                  items: ['5', '10', '15', '30'],
                  suffix: 'minutes',
                  onChanged: (value) {
                    setState(() {
                      _snoozeTime = value!;
                    });
                  },
                ),
              ],
            ),
            
            // Data & Privacy
            _buildSection(
              title: 'Data & Privacy',
              icon: Icons.security,
              children: [
                _buildSwitchTile(
                  title: 'Activity Logging',
                  subtitle: 'Track completion history',
                  value: _loggingEnabled,
                  onChanged: (value) async {
                    await LoggingService.setLoggingEnabled(value);
                    setState(() {
                      _loggingEnabled = value;
                    });
                  },
                ),
                _buildActionTile(
                  title: 'Clear All Logs',
                  subtitle: 'Delete activity history',
                  icon: Icons.delete_outline,
                  onTap: _clearLogs,
                  isDestructive: true,
                ),
              ],
            ),
            
            // Test & Debug
            _buildSection(
              title: 'Test & Debug',
              icon: Icons.bug_report_outlined,
              children: [
                _buildActionTile(
                  title: 'Test Notification',
                  subtitle: 'Send a test reminder notification',
                  icon: Icons.notifications_active,
                  onTap: _testNotification,
                ),
                _buildActionTile(
                  title: 'Test Full Screen Alarm',
                  subtitle: 'Preview the alarm screen',
                  icon: Icons.fullscreen,
                  onTap: _testFullScreenAlarm,
                ),
              ],
            ),
            
            // About
            _buildSection(
              title: 'About',
              icon: Icons.info_outline,
              children: [
                _buildInfoTile(
                  title: 'Version',
                  value: '1.0.0',
                ),
                _buildInfoTile(
                  title: 'Developer',
                  value: 'Good Deeds Team',
                ),
                _buildActionTile(
                  title: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () {},
                ),
                _buildActionTile(
                  title: 'Terms of Service',
                  icon: Icons.description_outlined,
                  onTap: () {},
                ),
              ],
            ),
            
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ...children.map((child) => Column(
            children: [
              Divider(height: 1, indent: 20, endIndent: 20),
              child,
            ],
          )),
        ],
      ),
    );
  }
  
  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
        ? Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          )
        : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: AppTheme.primaryGreen,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
  
  Widget _buildDropdownTile({
    required String title,
    String? subtitle,
    required String value,
    required List<String> items,
    String? suffix,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
        ? Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          )
        : null,
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.border),
        ),
        child: DropdownButton<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(
              '$item${suffix != null ? ' $suffix' : ''}',
              style: TextStyle(fontSize: 14),
            ),
          )).toList(),
          onChanged: onChanged,
          underline: SizedBox(),
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, size: 20),
        ),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
  
  Widget _buildActionTile({
    required String title,
    String? subtitle,
    IconData? icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: icon != null
        ? Icon(
            icon,
            color: isDestructive ? AppTheme.error : AppTheme.primaryGreen,
            size: 20,
          )
        : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? AppTheme.error : AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
        ? Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          )
        : null,
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppTheme.textTertiary,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
  
  Widget _buildInfoTile({
    required String title,
    required String value,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
  
  Widget _buildTimeTile({
    required String title,
    String? subtitle,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
        ? Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          )
        : null,
      trailing: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          time.format(context),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
  
  void _saveDoNotDisturbSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dnd_enabled', _doNotDisturbEnabled);
    await prefs.setInt('dnd_start_hour', _doNotDisturbStart.hour);
    await prefs.setInt('dnd_start_minute', _doNotDisturbStart.minute);
    await prefs.setInt('dnd_end_hour', _doNotDisturbEnd.hour);
    await prefs.setInt('dnd_end_minute', _doNotDisturbEnd.minute);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_doNotDisturbEnabled 
          ? 'Do Not Disturb enabled' 
          : 'Do Not Disturb disabled'),
        backgroundColor: AppTheme.success,
      ),
    );
  }
  
  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All Logs?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await LoggingService.clearLogs();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Logs cleared'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: Text(
              'Clear',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }
  
  void _testNotification() async {
    await NotificationService.showTestNotification();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test notification sent'),
        backgroundColor: AppTheme.success,
      ),
    );
  }
  
  void _testFullScreenAlarm() {
    Navigator.pushNamed(context, '/fullScreenAlarm');
  }
}
