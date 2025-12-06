import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../config/app_theme.dart';
import '../models/reminder.dart';
import '../services/alarm_service.dart';
import '../services/logging_service.dart';

class EveryAyahTrack {
  final String title;
  final String url;
  final String reciter;
  final String description;

  const EveryAyahTrack({
    required this.title,
    required this.url,
    required this.reciter,
    required this.description,
  });
}

class AddReminderScreen extends StatefulWidget {
  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  ReminderFrequency _selectedFrequency = ReminderFrequency.daily;
  TimeOfDay _selectedTime = TimeOfDay(hour: 9, minute: 0);
  List<int> _selectedWeekDays = [];
  int _selectedDayOfMonth = 1;
  int _intervalMinutes = 20;
  String? _customSoundPath;
  EveryAyahTrack? _selectedEveryAyahTrack;
  String? _recordedVoicePath;
  bool _isRecording = false;
  IconData _selectedIcon = Icons.notifications;
  ReminderCategory _selectedCategory = ReminderCategory.personal;

  final List<EveryAyahTrack> _everyAyahTracks = const [
    EveryAyahTrack(
      title: 'Ayatul Kursi',
      url: 'https://everyayah.com/data/Alafasy_128kbps/002255.mp3',
      reciter: 'Mishary Alafasy',
      description: 'Soothing reminder of protection and calm.',
    ),
    EveryAyahTrack(
      title: 'Surah Al-Asr',
      url: 'https://everyayah.com/data/Alafasy_128kbps/103001.mp3',
      reciter: 'Mishary Alafasy',
      description: 'Short and motivating for quick resets.',
    ),
    EveryAyahTrack(
      title: 'Surah Ar-Rahman (selected verses)',
      url: 'https://everyayah.com/data/Alafasy_128kbps/055026.mp3',
      reciter: 'Mishary Alafasy',
      description: 'Gentle verses on gratitude.',
    ),
    EveryAyahTrack(
      title: 'Surah Al-Ikhlas',
      url: 'https://everyayah.com/data/Alafasy_128kbps/112001.mp3',
      reciter: 'Mishary Alafasy',
      description: 'Minimalist chime-free recitation.',
    ),
    EveryAyahTrack(
      title: 'Surah Al-Fatiha',
      url: 'https://everyayah.com/data/Alafasy_128kbps/001001.mp3',
      reciter: 'Mishary Alafasy',
      description: 'Universal opening for mindful starts.',
    ),
  ];
  
  final List<IconData> _availableIcons = [
    Icons.notifications,
    Icons.phone,
    Icons.favorite,
    Icons.volunteer_activism,
    Icons.fitness_center,
    Icons.self_improvement,
    Icons.mosque,
    Icons.family_restroom,
    Icons.healing,
    Icons.school,
    Icons.work,
    Icons.home,
  ];
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  Future<void> _selectCustomSound() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _customSoundPath = result.files.single.path;
          _selectedEveryAyahTrack = null;
        });

        // Play preview
        if (_customSoundPath != null) {
          await _previewSound(_customSoundPath!);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Custom sound selected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting sound: $e')),
      );
    }
  }
  
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = Directory.systemTemp;
        final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          RecordConfig(),
          path: path,
        );
        
        setState(() {
          _isRecording = true;
          _recordedVoicePath = path;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone permission required')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      
      // Play preview
      if (_recordedVoicePath != null) {
        await _audioPlayer.play(DeviceFileSource(_recordedVoicePath!));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice recorded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  Future<void> _previewSound(String sourcePath) async {
    if (sourcePath.isEmpty) return;

    if (sourcePath.startsWith('http')) {
      await _audioPlayer.play(UrlSource(sourcePath));
    } else {
      await _audioPlayer.play(DeviceFileSource(sourcePath));
    }

    await Future.delayed(Duration(seconds: 2));
    await _audioPlayer.stop();
  }

  Future<void> _selectEveryAyahSound() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EveryAyah library',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pure Qur\'an recitations only — no bells or harsh tones.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ..._everyAyahTracks.map((track) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                      child: Icon(Icons.play_arrow, color: AppTheme.primaryGreen),
                    ),
                    title: Text(track.title),
                    subtitle: Text('${track.reciter} · ${track.description}'),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() {
                        _selectedEveryAyahTrack = track;
                        _customSoundPath = track.url;
                      });
                      await _previewSound(track.url);
                    },
                  )),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final reminder = Reminder(
        title: _titleController.text,
        description: _descriptionController.text,
        frequency: _selectedFrequency,
        scheduledTime: _selectedTime,
        weekDays: _selectedWeekDays.isEmpty ? null : _selectedWeekDays,
        dayOfMonth: _selectedDayOfMonth,
        intervalMinutes: _intervalMinutes,
        soundPath: _customSoundPath,
        recordedVoicePath: _recordedVoicePath,
        icon: _selectedIcon,
        category: _selectedCategory,
        customData: {
          'everyAyahTitle': _selectedEveryAyahTrack?.title,
          'reciter': _selectedEveryAyahTrack?.reciter,
        },
      );
      
      // Schedule the alarm
      await AlarmService.scheduleReminder(reminder);
      
      // Log creation
      LoggingService.logStatic(
        'Created reminder: ${reminder.title}',
        LogLevel.info,
        metadata: {
          'reminderId': reminder.id,
          'frequency': _selectedFrequency.toString(),
          'everyAyah': _selectedEveryAyahTrack?.title,
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, reminder);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTimeOfDay(TimeOfDay timeOfDay) {
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final suffix = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  String _recurrenceSummaryText() {
    switch (_selectedFrequency) {
      case ReminderFrequency.daily:
        return 'Repeats daily at ${_formatTimeOfDay(_selectedTime)}';
      case ReminderFrequency.weekly:
        final days = _selectedWeekDays.isEmpty
            ? 'Pick days to repeat'
            : _selectedWeekDays
                .map((d) => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1])
                .join(', ');
        return 'Weekly on $days';
      case ReminderFrequency.monthly:
        return 'Monthly on day $_selectedDayOfMonth at ${_formatTimeOfDay(_selectedTime)}';
      case ReminderFrequency.interval:
        return 'Every $_intervalMinutes minutes';
      case ReminderFrequency.once:
        return 'One-time reminder at ${_formatTimeOfDay(_selectedTime)}';
      default:
        return 'Custom schedule';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Design your reminder',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Container(
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGreen.withOpacity(0.14),
                    AppTheme.primaryGreen.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(Icons.checklist_rounded, color: AppTheme.primaryGreen),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Streamlined recurring reminder',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _recurrenceSummaryText(),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPill('Pause-friendly', Icons.pause_rounded),
                      SizedBox(width: 8),
                      _buildPill('Feedback-ready', Icons.rate_review_outlined),
                      SizedBox(width: 8),
                      _buildPill('EveryAyah audio', Icons.library_music),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            _buildSection(
              title: 'Reminder basics',
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration('Title *', 'e.g., Call Mom', Icons.title),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: _inputDecoration('Description', 'What do you want to get done?', Icons.description),
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            _buildSection(
              title: 'Personalise it',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableIcons.length,
                      itemBuilder: (context, index) {
                        final icon = _availableIcons[index];
                        final isSelected = icon == _selectedIcon;
                        return Padding(
                          padding: EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedIcon = icon),
                            child: Container(
                              width: 64,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : AppTheme.background,
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryGreen : AppTheme.border,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<ReminderCategory>(
                    value: _selectedCategory,
                    decoration: _inputDecoration('Category', 'Organise your habit', Icons.category),
                    items: ReminderCategory.values.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            _buildSection(
              title: 'Recurring schedule',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReminderFrequency.values.map((freq) {
                      return ChoiceChip(
                        label: Text(freq.name.toUpperCase()),
                        selected: _selectedFrequency == freq,
                        onSelected: (_) => setState(() => _selectedFrequency = freq),
                        selectedColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          color: _selectedFrequency == freq ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: AppTheme.background,
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 14),
                  if (_selectedFrequency != ReminderFrequency.interval)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.access_time, color: AppTheme.primaryGreen),
                      title: Text('Reminder time'),
                      subtitle: Text(_selectedTime.format(context)),
                      trailing: Icon(Icons.chevron_right),
                      onTap: _selectTime,
                    ),
                  if (_selectedFrequency == ReminderFrequency.interval)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Every $_intervalMinutes minutes'),
                        Slider(
                          value: _intervalMinutes.toDouble(),
                          min: 5,
                          max: 180,
                          divisions: 35,
                          label: '$_intervalMinutes mins',
                          onChanged: (value) {
                            setState(() {
                              _intervalMinutes = value.round();
                            });
                          },
                        ),
                      ],
                    ),
                  if (_selectedFrequency == ReminderFrequency.weekly) ...[
                    SizedBox(height: 8),
                    Text('Pick the weekdays that work best', style: TextStyle(color: AppTheme.textSecondary)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index];
                        final isSelected = _selectedWeekDays.contains(day);
                        return FilterChip(
                          label: Text(dayName),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
                          checkmarkColor: AppTheme.primaryGreen,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedWeekDays.add(day);
                              } else {
                                _selectedWeekDays.remove(day);
                              }
                            });
                          },
                        );
                      }),
                    ),
                  ],
                  if (_selectedFrequency == ReminderFrequency.monthly)
                    TextFormField(
                      initialValue: _selectedDayOfMonth.toString(),
                      decoration: _inputDecoration('Day of month', '1-31', Icons.calendar_today),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final day = int.tryParse(value) ?? 1;
                        _selectedDayOfMonth = day.clamp(1, 31);
                      },
                    ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.repeat_rounded, color: AppTheme.info),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _recurrenceSummaryText(),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            _buildSection(
              title: 'Audio (EveryAyah, no bells)',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.library_music, color: AppTheme.primaryGreen),
                    title: Text('Choose recitation'),
                    subtitle: Text(
                      _selectedEveryAyahTrack != null
                          ? '${_selectedEveryAyahTrack!.title} · ${_selectedEveryAyahTrack!.reciter}'
                          : 'Select a gentle EveryAyah MP3',
                    ),
                    trailing: Icon(Icons.chevron_right),
                    onTap: _selectEveryAyahSound,
                  ),
                  SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.music_note, color: AppTheme.info),
                    title: Text('Use your own audio'),
                    subtitle: Text(
                      _customSoundPath != null && !_customSoundPath!.startsWith('http')
                          ? 'Sound selected'
                          : 'Optional upload',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.folder_open),
                      onPressed: _selectCustomSound,
                    ),
                  ),
                  SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.mic, color: AppTheme.warning),
                    title: Text('Record a personal note'),
                    subtitle: Text(
                      _recordedVoicePath != null
                          ? 'Voice recorded'
                          : 'Add your own encouragement',
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        _isRecording ? Icons.stop : Icons.fiber_manual_record,
                        color: _isRecording ? AppTheme.error : AppTheme.textSecondary,
                      ),
                      onPressed: _isRecording ? _stopRecording : _startRecording,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _saveReminder,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
              ),
              icon: Icon(Icons.save_alt),
              label: Text(
                'Save recurring reminder',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'You can pause or add feedback later from the detail screen.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      filled: true,
      fillColor: AppTheme.surface,
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Spacer(),
              Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 18),
            ],
          ),
          SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPill(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryGreen),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
