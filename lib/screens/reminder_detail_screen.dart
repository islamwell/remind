import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../config/app_theme.dart';
import '../services/logging_service.dart';
import '../services/alarm_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

class ReminderDetailScreen extends StatefulWidget {
  final Reminder reminder;
  
  const ReminderDetailScreen({Key? key, required this.reminder}) : super(key: key);
  
  @override
  _ReminderDetailScreenState createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends State<ReminderDetailScreen> {
  late Reminder reminder;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingPreview = false;
  
  @override
  void initState() {
    super.initState();
    reminder = widget.reminder;
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  void _changeAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      
      if (result != null) {
        setState(() {
          reminder.soundPath = result.files.single.path;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio file updated'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting audio: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
  
  void _toggleAudioPreview() async {
    if (_isPlayingPreview) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingPreview = false;
      });
    } else {
      if (reminder.soundPath != null) {
        if (reminder.soundPath!.startsWith('http')) {
          await _audioPlayer.play(UrlSource(reminder.soundPath!));
        } else {
          await _audioPlayer.play(DeviceFileSource(reminder.soundPath!));
        }
        setState(() {
          _isPlayingPreview = true;
        });
        
        _audioPlayer.onPlayerComplete.listen((event) {
          setState(() {
            _isPlayingPreview = false;
          });
        });
      }
    }
  }

  void _logFeedback() {
    double sliderValue = 4;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Log completion feedback',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 16),
                  Slider(
                    value: sliderValue,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    activeColor: AppTheme.primaryGreen,
                    label: _scoreLabel(sliderValue),
                    onChanged: (value) => setModalState(() => sliderValue = value),
                  ),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Notes or reflections (optional)',
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final feedback = reminder.markCompleted(
                        mood: _scoreLabel(sliderValue),
                        note: controller.text,
                      );
                      await LoggingService.logCompletion(
                        reminder.id,
                        reminder.title,
                        additionalData: {
                          'mood': feedback.mood,
                          'note': feedback.note,
                          'score': sliderValue,
                        },
                      );
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Feedback logged for ${reminder.title}'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Mark complete'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }
  
  @override
  Widget build(BuildContext context) {
    final stats = reminder.getStatistics();
    final successRate = stats['total'] > 0 
      ? ((stats['total'] - reminder.snoozeCount) * 100 / stats['total']).round()
      : 0;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Reminder Details',
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
            icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Stats Cards
            Container(
              padding: EdgeInsets.all(20),
              color: AppTheme.primaryGreen,
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      value: stats['total'].toString(),
                      label: 'Completed',
                      icon: Icons.check_circle,
                      isLight: true,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      value: '${stats['streak']} days',
                      label: 'Streak',
                      icon: Icons.local_fire_department,
                      isLight: true,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      value: '$successRate%',
                      label: 'Success Rate',
                      icon: Icons.trending_up,
                      isLight: true,
                    ),
                  ),
                ],
              ),
            ),
            
            Container(
              color: AppTheme.surface,
              child: Column(
                children: [
                  // Title and Description
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                reminder.icon,
                                color: AppTheme.primaryGreen,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reminder.title,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    reminder.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(height: 1),
                  
                  // Frequency and Next Due
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.access_time,
                            iconColor: AppTheme.primaryGreen,
                            title: 'Frequency',
                            value: _getFrequencyText(),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.alarm,
                            iconColor: AppTheme.warning,
                            title: 'Next Due',
                            value: reminder.isActive 
                              ? reminder.getNextAlarmTime()
                              : 'Paused',
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton.icon(
                      onPressed: _logFeedback,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        minimumSize: Size(double.infinity, 48),
                      ),
                      icon: Icon(Icons.check_circle_outline),
                      label: Text('Complete + log feedback'),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Audio File Section
                  if (reminder.soundPath != null || reminder.recordedVoicePath != null)
                    Column(
                      children: [
                        Divider(height: 1),
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.music_note,
                                    color: AppTheme.info,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Audio File',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    'Created',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reminder.soundPath?.split('/').last ?? 
                                            'gentle-reminder.mp3',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            reminder.createdAt.toString().substring(0, 10),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  
                  // Audio Preview Section
                  Column(
                    children: [
                      Divider(height: 1),
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.music_note,
                              color: AppTheme.info,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Audio Preview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Spacer(),
                            TextButton(
                              onPressed: _changeAudioFile,
                              child: Text(
                                'Change',
                                style: TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Category Section
                  Column(
                    children: [
                      Divider(height: 1),
                      Container(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                border: Border.all(
                                  color: AppTheme.primaryGreen,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                reminder.category.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // History Section
                  if (reminder.feedbackHistory.isNotEmpty || reminder.completionHistory.isNotEmpty)
                    Column(
                      children: [
                        Divider(height: 1),
                        Container(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'History & feedback',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Spacer(),
                                  Text('${reminder.feedbackHistory.length} logged', style: TextStyle(color: AppTheme.textSecondary)),
                                ],
                              ),
                              SizedBox(height: 12),
                              ...(reminder.feedbackHistory.isNotEmpty
                                      ? reminder.feedbackHistory
                                      : reminder.completionHistory
                                          .map((date) => ReminderFeedback(
                                                completed: true,
                                                timestamp: date,
                                                mood: 'Completed',
                                                note: null,
                                              )))
                                  .take(5)
                                  .map((entry) => Padding(
                                        padding: EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.check_circle, size: 16, color: AppTheme.success),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year} · ${entry.mood ?? 'Completed'}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: AppTheme.textPrimary,
                                                    ),
                                                  ),
                                                  if (entry.note != null && entry.note!.isNotEmpty)
                                                    Padding(
                                                      padding: EdgeInsets.only(top: 4),
                                                      child: Text(
                                                        entry.note!,
                                                        style: TextStyle(color: AppTheme.textSecondary),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
    bool isLight = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isLight 
          ? Colors.white.withOpacity(0.2)
          : AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isLight ? Colors.white : AppTheme.primaryGreen,
            size: 24,
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isLight ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isLight 
                ? Colors.white.withOpacity(0.8)
                : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getFrequencyText() {
    switch (reminder.frequency) {
      case ReminderFrequency.daily:
        return 'Daily';
      case ReminderFrequency.weekly:
        return 'Weekly';
      case ReminderFrequency.monthly:
        return 'Monthly';
      case ReminderFrequency.interval:
        return 'Every ${reminder.intervalMinutes} min';
      case ReminderFrequency.once:
        return 'Once';
      default:
        return 'Custom';
    }
  }

  String _scoreLabel(double value) {
    if (value >= 4.5) return 'Energised';
    if (value >= 3.5) return 'Positive';
    if (value >= 2.5) return 'Neutral';
    if (value >= 1.5) return 'Tired';
    return 'Exhausted';
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
              leading: Icon(Icons.edit, color: AppTheme.textPrimary),
              title: Text('Edit Reminder'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to edit screen
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: AppTheme.error),
              title: Text('Delete Reminder', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Reminder?'),
        content: Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await AlarmService.cancelReminder(reminder.id);
              Navigator.pop(context);
              Navigator.pop(context, 'deleted');
            },
            child: Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}
