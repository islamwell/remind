import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../models/reminder.dart';
import '../services/alarm_service.dart';
import '../services/logging_service.dart';

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
  String? _recordedVoicePath;
  bool _isRecording = false;
  IconData _selectedIcon = Icons.notifications;
  ReminderCategory _selectedCategory = ReminderCategory.personal;
  
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
        });
        
        // Play preview
        if (_customSoundPath != null) {
          await _audioPlayer.play(DeviceFileSource(_customSoundPath!));
          await Future.delayed(Duration(seconds: 2));
          await _audioPlayer.stop();
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Custom Reminder'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Title
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminder Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g., Call Mom',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g., Check in with family',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Icon and Category
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Icon & Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Icon selector
                    Container(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableIcons.length,
                        itemBuilder: (context, index) {
                          final icon = _availableIcons[index];
                          final isSelected = icon == _selectedIcon;
                          
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedIcon = icon;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 60,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                    ? Theme.of(context).primaryColor 
                                    : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected ? Colors.white : Colors.grey[600],
                                  size: 28,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Category dropdown
                    DropdownButtonFormField<ReminderCategory>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.category),
                      ),
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
            ),
            
            SizedBox(height: 16),
            
            // Frequency Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Frequency selector
                    DropdownButtonFormField<ReminderFrequency>(
                      value: _selectedFrequency,
                      decoration: InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items: ReminderFrequency.values.map((freq) {
                        return DropdownMenuItem(
                          value: freq,
                          child: Text(freq.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedFrequency = value;
                          });
                        }
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Time selector (for non-interval)
                    if (_selectedFrequency != ReminderFrequency.interval)
                      ListTile(
                        title: Text('Time'),
                        subtitle: Text(_selectedTime.format(context)),
                        leading: Icon(Icons.access_time),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: _selectTime,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                    
                    // Interval minutes (for interval frequency)
                    if (_selectedFrequency == ReminderFrequency.interval)
                      TextFormField(
                        initialValue: _intervalMinutes.toString(),
                        decoration: InputDecoration(
                          labelText: 'Interval (minutes)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.timer),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _intervalMinutes = int.tryParse(value) ?? 20;
                        },
                      ),
                    
                    // Week days selector (for weekly)
                    if (_selectedFrequency == ReminderFrequency.weekly) ...[
                      SizedBox(height: 16),
                      Text('Select Days'),
                      Wrap(
                        spacing: 8,
                        children: List.generate(7, (index) {
                          final day = index + 1;
                          final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][index];
                          final isSelected = _selectedWeekDays.contains(day);
                          
                          return FilterChip(
                            label: Text(dayName),
                            selected: isSelected,
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
                    
                    // Day of month (for monthly)
                    if (_selectedFrequency == ReminderFrequency.monthly)
                      TextFormField(
                        initialValue: _selectedDayOfMonth.toString(),
                        decoration: InputDecoration(
                          labelText: 'Day of Month (1-31)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final day = int.tryParse(value) ?? 1;
                          _selectedDayOfMonth = day.clamp(1, 31);
                        },
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Sound Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alarm Sound',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Custom sound selector
                    ListTile(
                      title: Text('Custom Sound'),
                      subtitle: Text(
                        _customSoundPath != null 
                          ? 'Sound selected' 
                          : 'Default alarm sound',
                      ),
                      leading: Icon(Icons.music_note),
                      trailing: IconButton(
                        icon: Icon(Icons.folder_open),
                        onPressed: _selectCustomSound,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Voice recorder
                    ListTile(
                      title: Text('Record Voice Message'),
                      subtitle: Text(
                        _recordedVoicePath != null 
                          ? 'Voice recorded' 
                          : 'No recording',
                      ),
                      leading: Icon(Icons.mic),
                      trailing: IconButton(
                        icon: Icon(
                          _isRecording ? Icons.stop : Icons.fiber_manual_record,
                          color: _isRecording ? Colors.red : Colors.grey,
                        ),
                        onPressed: _isRecording ? _stopRecording : _startRecording,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Save button
            ElevatedButton(
              onPressed: _saveReminder,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.teal,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Create Reminder',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
