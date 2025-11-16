import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/reminder.dart';
import '../services/logging_service.dart';

/// Full-screen alarm screen that shows over the lock screen
/// This is CRITICAL for the app's main functionality
class FullScreenAlarmScreen extends StatefulWidget {
  @override
  _FullScreenAlarmScreenState createState() => _FullScreenAlarmScreenState();
}

class _FullScreenAlarmScreenState extends State<FullScreenAlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _vibrationTimer;
  Reminder? _reminder;
  bool _isSnoozing = false;
  int _secondsElapsed = 0;
  Timer? _elapsedTimer;
  
  @override
  void initState() {
    super.initState();
    
    // CRITICAL: Keep screen awake
    WakelockPlus.enable();
    
    // Set system UI for full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween(
      begin: 0.95,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));
    
    // Start animations
    _slideController.forward();
    
    // Get reminder data from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        setState(() {
          _reminder = Reminder.fromJson(args['reminder']);
        });
      }
      
      // Start alarm actions
      _startAlarm();
      _startElapsedTimer();
    });
  }
  
  void _startAlarm() async {
    // Play alarm sound on loop
    _playAlarmSound();
    
    // Start vibration pattern
    _startVibration();
    
    // Log alarm trigger
    if (_reminder != null) {
      LoggingService.logStatic(
        "Full screen alarm displayed: ${_reminder!.title}",
        LogLevel.info,
        metadata: {'reminderId': _reminder!.id},
      );
    }
  }
  
  void _playAlarmSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0); // Maximum volume
      
      if (_reminder?.soundPath != null) {
        await _audioPlayer.play(DeviceFileSource(_reminder!.soundPath!));
      } else if (_reminder?.recordedVoicePath != null) {
        await _audioPlayer.play(DeviceFileSource(_reminder!.recordedVoicePath!));
      } else {
        // Play default alarm sound
        await _audioPlayer.play(AssetSource('sounds/default_alarm.mp3'));
      }
    } catch (e) {
      print('Error playing alarm sound: $e');
    }
  }
  
  void _startVibration() {
    // Vibrate pattern every 2 seconds
    _vibrationTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      Vibration.vibrate(
        pattern: [0, 500, 200, 500],
        intensities: [0, 255, 128, 255],
      );
    });
  }
  
  void _startElapsedTimer() {
    _elapsedTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }
  
  void _stopAlarm() {
    _audioPlayer.stop();
    _vibrationTimer?.cancel();
    _elapsedTimer?.cancel();
    Vibration.cancel();
  }
  
  void _handleComplete() async {
    setState(() {
      _isSnoozing = true;
    });
    
    _stopAlarm();
    
    if (_reminder != null) {
      // Log completion
      await LoggingService.logCompletion(
        _reminder!.id,
        _reminder!.title,
        additionalData: {
          'completedAfterSeconds': _secondsElapsed,
        },
      );
      
      _reminder!.markCompleted();
      
      // Show success animation
      _showSuccessDialog();
    }
  }
  
  void _handleSnooze() async {
    setState(() {
      _isSnoozing = true;
    });
    
    _stopAlarm();
    
    if (_reminder != null) {
      // Snooze for 5 minutes
      _reminder!.snooze(5);
      
      await LoggingService.logSnooze(
        _reminder!.id,
        _reminder!.title,
        5,
      );
      
      // Show snooze confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snoozed for 5 minutes'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Close after delay
      Future.delayed(Duration(seconds: 2), () {
        Navigator.of(context).pop();
      });
    }
  }
  
  void _handleDismiss() async {
    _stopAlarm();
    
    if (_reminder != null) {
      await LoggingService.logDismissal(
        _reminder!.id,
        _reminder!.title,
      );
    }
    
    Navigator.of(context).pop();
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.green,
                  size: 48,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Good Deed Complete!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'May your good deed be rewarded',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close alarm screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _stopAlarm();
    _pulseController.dispose();
    _slideController.dispose();
    _audioPlayer.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
  
  String _formatElapsedTime() {
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal.shade700,
              Colors.teal,
              Colors.teal.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top time display
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      DateTime.now().toString().substring(11, 16),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      DateTime.now().toString().substring(0, 10),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main alarm content
              Expanded(
                child: Center(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 32),
                            padding: EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Animated bell icon
                                TweenAnimationBuilder(
                                  tween: Tween(begin: -0.1, end: 0.1),
                                  duration: Duration(milliseconds: 100),
                                  curve: Curves.easeInOut,
                                  builder: (context, double value, child) {
                                    return Transform.rotate(
                                      angle: math.sin(DateTime.now().millisecondsSinceEpoch / 100) * value,
                                      child: Icon(
                                        Icons.notifications_active,
                                        size: 80,
                                        color: Colors.teal,
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 24),
                                
                                // Reminder title
                                Text(
                                  _reminder?.title ?? 'Good Deed Reminder',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 12),
                                
                                // Reminder description
                                Text(
                                  _reminder?.description ?? 'Time to do your good deed!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24),
                                
                                // Elapsed time
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Ringing for ${_formatElapsedTime()}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              // Action buttons
              Container(
                padding: EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Dismiss button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSnoozing ? null : _handleDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          padding: EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'DISMISS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    
                    // Snooze button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSnoozing ? null : _handleSnooze,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SNOOZE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '5 min',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    
                    // Complete button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSnoozing ? null : _handleComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'COMPLETE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Swipe hint
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Swipe up for more options',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
