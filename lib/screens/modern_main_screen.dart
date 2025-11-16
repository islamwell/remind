import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reminder.dart';
import '../services/alarm_service.dart';
import '../services/logging_service.dart';
import '../config/app_theme.dart';
import '../screens/add_reminder.dart';
import '../widgets/reminder_card.dart';
import '../widgets/stat_card.dart';
import '../screens/logs_screen.dart';
import '../screens/settings_screen.dart';

class ModernMainScreen extends StatefulWidget {
  @override
  _ModernMainScreenState createState() => _ModernMainScreenState();
}

class _ModernMainScreenState extends State<ModernMainScreen> {
  List<Reminder> reminders = [];
  final LoggingService logger = LoggingService();
  String searchQuery = '';
  
  // Sample data for demonstration
  @override
  void initState() {
    super.initState();
    _loadSampleReminders();
    _setupBackgroundHandler();
  }
  
  void _loadSampleReminders() {
    // Add sample reminders for demo
    reminders = [
      Reminder(
        id: '1',
        title: 'Call Mom',
        description: 'Check in with family',
        frequency: ReminderFrequency.daily,
        scheduledTime: TimeOfDay(hour: 19, minute: 0),
        icon: Icons.family_restroom,
        category: ReminderCategory.family,
        isActive: true,
      ),
      Reminder(
        id: '2',
        title: 'Gratitude Journal',
        description: 'Write 3 things you are grateful for',
        frequency: ReminderFrequency.daily,
        scheduledTime: TimeOfDay(hour: 21, minute: 0),
        icon: Icons.edit_note,
        category: ReminderCategory.personal,
        isActive: false,
      ),
      Reminder(
        id: '3',
        title: 'Exercise',
        description: '30 minutes of physical activity',
        frequency: ReminderFrequency.daily,
        scheduledTime: TimeOfDay(hour: 7, minute: 0),
        icon: Icons.fitness_center,
        category: ReminderCategory.health,
        isActive: true,
      ),
    ];
    
    // Update completion history for stats
    reminders[0].completionHistory = [
      DateTime.now().subtract(Duration(days: 0)),
      DateTime.now().subtract(Duration(days: 1)),
      DateTime.now().subtract(Duration(days: 2)),
      DateTime.now().subtract(Duration(days: 3)),
      DateTime.now().subtract(Duration(days: 4)),
      DateTime.now().subtract(Duration(days: 6)),
      DateTime.now().subtract(Duration(days: 7)),
      DateTime.now().subtract(Duration(days: 8)),
      DateTime.now().subtract(Duration(days: 9)),
      DateTime.now().subtract(Duration(days: 10)),
      DateTime.now().subtract(Duration(days: 11)),
      DateTime.now().subtract(Duration(days: 12)),
    ];
    
    setState(() {});
  }
  
  void _setupBackgroundHandler() {
    // Handle notification actions
  }
  
  List<Reminder> get activeReminders => 
      reminders.where((r) => r.isActive).toList();
  
  List<Reminder> get pausedReminders => 
      reminders.where((r) => !r.isActive).toList();
  
  List<Reminder> get filteredReminders {
    if (searchQuery.isEmpty) return reminders;
    return reminders.where((r) => 
      r.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
      r.description.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }
  
  void _toggleReminder(Reminder reminder, bool value) async {
    setState(() {
      reminder.isActive = value;
    });
    
    if (value) {
      await AlarmService.scheduleReminder(reminder);
      logger.log("Reminder activated: ${reminder.title}", LogLevel.info);
    } else {
      await AlarmService.cancelReminder(reminder.id);
      logger.log("Reminder deactivated: ${reminder.title}", LogLevel.info);
    }
  }
  
  void _deleteReminder(Reminder reminder) async {
    await AlarmService.cancelReminder(reminder.id);
    setState(() {
      reminders.remove(reminder);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${reminder.title} deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            setState(() {
              reminders.add(reminder);
            });
            if (reminder.isActive) {
              AlarmService.scheduleReminder(reminder);
            }
          },
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Reminders',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: AppTheme.textPrimary, size: 28),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddReminderScreen()),
              );
              if (result != null && result is Reminder) {
                setState(() {
                  reminders.add(result);
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: CustomScrollView(
        physics: BouncingScrollPhysics(),
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Container(
              color: AppTheme.surface,
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                        border: Border.all(color: AppTheme.border, width: 1),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search reminders...',
                          hintStyle: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppTheme.textTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () {},
                      padding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Stats Cards (Optional - can be toggled)
          if (false) // Set to true to show stats
          SliverToBoxAdapter(
            child: Container(
              height: 120,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Completed',
                      value: stats['completed'].toString(),
                      icon: Icons.check_circle_outline,
                      color: AppTheme.success,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Streak',
                      value: '${stats['streak']} days',
                      icon: Icons.local_fire_department,
                      color: AppTheme.warning,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Success',
                      value: '${stats['successRate']}%',
                      icon: Icons.trending_up,
                      color: AppTheme.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Active Reminders Section
          if (activeReminders.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusXLarge),
                    topRight: Radius.circular(AppTheme.radiusXLarge),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: AppTheme.success,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.expand_less),
                          onPressed: () {},
                          color: AppTheme.textTertiary,
                        ),
                      ],
                    ),
                    Text(
                      '${activeReminders.length} reminders',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 16),
                    ...activeReminders.map((reminder) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ModernReminderCard(
                        reminder: reminder,
                        onToggle: (value) => _toggleReminder(reminder, value),
                        onDelete: () => _deleteReminder(reminder),
                        onTap: () => _showReminderDetails(reminder),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          
          // Paused Reminders Section
          if (pausedReminders.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: activeReminders.isEmpty ? 8 : 16),
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: activeReminders.isEmpty 
                    ? BorderRadius.only(
                        topLeft: Radius.circular(AppTheme.radiusXLarge),
                        topRight: Radius.circular(AppTheme.radiusXLarge),
                      )
                    : BorderRadius.zero,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.pause,
                            color: AppTheme.warning,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Paused',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.expand_less),
                          onPressed: () {},
                          color: AppTheme.textTertiary,
                        ),
                      ],
                    ),
                    Text(
                      '${pausedReminders.length} reminder${pausedReminders.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 16),
                    ...pausedReminders.map((reminder) => Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ModernReminderCard(
                        reminder: reminder,
                        onToggle: (value) => _toggleReminder(reminder, value),
                        onDelete: () => _deleteReminder(reminder),
                        onTap: () => _showReminderDetails(reminder),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          
          // Empty State
          if (reminders.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No reminders yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap + to create your first reminder',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => AddReminderScreen()),
                        );
                        if (result != null && result is Reminder) {
                          setState(() {
                            reminders.add(result);
                          });
                        }
                      },
                      icon: Icon(Icons.add),
                      label: Text('Create Reminder'),
                    ),
                  ],
                ),
              ),
            ),
          
          // Bottom Spacing
          SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }
  
  Map<String, dynamic> _calculateStats() {
    int totalCompleted = 0;
    int longestStreak = 0;
    
    for (var reminder in reminders) {
      final stats = reminder.getStatistics();
      totalCompleted += (stats['total'] as int);
      if ((stats['streak'] as int) > longestStreak) {
        longestStreak = stats['streak'] as int;
      }
    }
    
    int successRate = 85; // Calculate based on actual data
    
    return {
      'completed': totalCompleted,
      'streak': longestStreak,
      'successRate': successRate,
    };
  }
  
  void _showReminderDetails(Reminder reminder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReminderDetailScreen(reminder: reminder),
      ),
    );
  }
  
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.history, color: AppTheme.textPrimary),
              title: Text('View Logs'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LogsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: AppTheme.textPrimary),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: AppTheme.textPrimary),
              title: Text('About'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Reminder Card Widget
class ModernReminderCard extends StatelessWidget {
  final Reminder reminder;
  final Function(bool) onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  
  const ModernReminderCard({
    Key? key,
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: reminder.isActive 
                      ? AppTheme.primaryGreen.withOpacity(0.1)
                      : AppTheme.textTertiary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    reminder.icon,
                    color: reminder.isActive 
                      ? AppTheme.primaryGreen 
                      : AppTheme.textTertiary,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Text(
                              reminder.frequency.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: reminder.isActive
                                ? AppTheme.success.withOpacity(0.1)
                                : AppTheme.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Text(
                              reminder.isActive ? 'ACTIVE' : 'PAUSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: reminder.isActive
                                  ? AppTheme.success
                                  : AppTheme.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: reminder.isActive,
                  onChanged: onToggle,
                  activeColor: Colors.white,
                  activeTrackColor: AppTheme.primaryGreen,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: AppTheme.border,
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.textTertiary,
                ),
                SizedBox(width: 4),
                Text(
                  reminder.isActive 
                    ? 'Next: ${reminder.getNextAlarmTime()}'
                    : 'Next: Paused',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    if (reminder.soundPath != null || reminder.recordedVoicePath != null)
                      Icon(
                        Icons.volume_up,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                    SizedBox(width: 8),
                    InkWell(
                      onTap: () {},
                      child: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
