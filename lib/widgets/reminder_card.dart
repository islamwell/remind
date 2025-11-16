import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/reminder.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final Function(bool) onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  
  const ReminderCard({
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
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                    size: 22,
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
                          _buildTag(
                            label: reminder.frequency.name.toUpperCase(),
                            color: AppTheme.primaryGreen,
                          ),
                          SizedBox(width: 8),
                          _buildTag(
                            label: reminder.isActive ? 'ACTIVE' : 'PAUSED',
                            color: reminder.isActive 
                              ? AppTheme.success 
                              : AppTheme.warning,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: reminder.isActive,
                    onChanged: onToggle,
                    activeColor: Colors.white,
                    activeTrackColor: AppTheme.primaryGreen,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: AppTheme.border,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textTertiary,
                  ),
                  SizedBox(width: 6),
                  Text(
                    reminder.isActive 
                      ? 'Next: ${reminder.getNextAlarmTime()}'
                      : 'Next: Paused',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Spacer(),
                  if (reminder.soundPath != null || reminder.recordedVoicePath != null)
                    Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.volume_up,
                        size: 16,
                        color: AppTheme.info,
                      ),
                    ),
                  InkWell(
                    onTap: () => _showOptions(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTag({required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  
  void _showOptions(BuildContext context) {
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
              leading: Icon(Icons.edit, color: AppTheme.textPrimary),
              title: Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                // Handle edit
              },
            ),
            ListTile(
              leading: Icon(Icons.snooze, color: AppTheme.warning),
              title: Text('Snooze'),
              onTap: () {
                Navigator.pop(context);
                // Handle snooze
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppTheme.error),
              title: Text('Delete', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
