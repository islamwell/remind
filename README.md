# Good Deeds Reminder App

## 🎯 CRITICAL FEATURE: Reliable Alarms Even When Phone is Locked

This Flutter app provides **100% reliable reminders** that work even when:
- Phone is locked
- App is in background
- Phone is in Doze/sleep mode
- App has been terminated

## ⚡ Key Features

### 1. **ULTRA-RELIABLE ALARM SYSTEM** (Primary Focus)
- **Full-screen alarms** that appear over lock screen
- **Multiple redundant alarm systems** to ensure no reminder is missed
- **Wake device from deep sleep**
- **Override Do Not Disturb mode**
- **Persist through device reboots**

### 2. Reminder Features
- Built-in templates (Call Mom, Visit Sick, Feed Poor, Exercise, etc.)
- Custom MP3 alarm sounds
- Voice recording for personalized reminders
- Flexible scheduling (daily, weekly, monthly, intervals)

### 3. Comprehensive Logging
- Track all completions
- Monitor snoozes and dismissals
- Export detailed statistics
- Debug logs for troubleshooting

## 🚀 Architecture Overview

### Critical Alarm Implementation (3-Layer System)

```
Layer 1: Android AlarmManager
├── Exact alarms with wakeup
├── Survives app termination
└── Most reliable for timing

Layer 2: Awesome Notifications
├── Full-screen intents
├── Critical alerts
└── Rich notification actions

Layer 3: System Alert Window
├── Overlay on lock screen
├── Custom UI over everything
└── Direct user interaction
```

### Permission Requirements (CRITICAL)

The app requires these permissions for reliable operation:

```xml
<!-- Core Alarm Permissions -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Full Screen Permissions (CRITICAL) -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.DISABLE_KEYGUARD" />

<!-- Battery Optimization Bypass -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
```

## 📱 Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Add Default Alarm Sound

Create `assets/sounds/` directory and add `default_alarm.mp3`:

```bash
mkdir -p assets/sounds
# Add your default alarm sound file here
```

### 3. Configure Android Settings

The app will automatically request permissions on first launch, but users must:

1. **Allow "Display over other apps"** (CRITICAL)
   - Settings → Apps → Good Deeds Reminder → Advanced → Display over other apps → Allow

2. **Disable Battery Optimization**
   - Settings → Battery → Battery Optimization → Good Deeds Reminder → Don't optimize

3. **Allow Exact Alarms** (Android 12+)
   - Settings → Apps → Good Deeds Reminder → Alarms & Reminders → Allow

### 4. Build and Run

```bash
# For debug mode
flutter run

# For release build
flutter build apk --release
```

## 🔧 Technical Implementation Details

### AlarmService (Most Critical Component)

```dart
// Multiple redundant systems ensure alarms always trigger:

1. AndroidAlarmManager.oneShotAt()
   - Hardware-level alarms
   - Survives app kills
   - Exact timing

2. AwesomeNotifications with fullScreenIntent
   - Shows over lock screen
   - Critical alert category
   - Cannot be dismissed easily

3. SystemAlertWindow
   - Custom overlay UI
   - Appears above everything
   - Interactive buttons
```

### Background Isolate Handling

```dart
@pragma('vm:entry-point')
static Future<void> _alarmCallback() async {
  // Runs in separate isolate
  // Wakes device
  // Shows full-screen alarm
  // Plays sound and vibrates
}
```

### Persistence Through Reboots

```dart
// BootReceiver automatically restores all alarms
android:directBootAware="true"  // Works even before unlock
```

## 📊 Logging System

### Completion Tracking
- Timestamp of every completion
- Time taken to complete
- Streak tracking
- Category statistics

### Export Format
```json
{
  "exportDate": "2025-01-15T10:30:00Z",
  "completions": [...],
  "statistics": {
    "total": 150,
    "thisWeek": 12,
    "longestStreak": 30
  }
}
```

## 🎨 Modern UI/UX (2025 Best Practices)

- **Rounded corners** (20px radius on cards)
- **Deep shadows** for depth
- **Material 3 design system**
- **Smooth animations**
- **Dark mode support**
- **Haptic feedback**

## 📈 Performance Optimizations

- Lazy loading of reminders
- Efficient battery usage with exact alarms
- Minimal background processing
- Smart scheduling to batch operations

## 🧪 Testing Checklist

### Critical Tests (MUST PASS)

- [ ] Alarm triggers when phone is locked
- [ ] Alarm triggers when app is closed
- [ ] Full-screen shows over lock screen
- [ ] Sound plays at maximum volume
- [ ] Vibration works
- [ ] Survives phone reboot
- [ ] Works in Doze mode
- [ ] Works with Do Not Disturb on

### Feature Tests

- [ ] Custom MP3 selection works
- [ ] Voice recording plays correctly
- [ ] Snooze reschedules properly
- [ ] Completion logging accurate
- [ ] Templates create reminders
- [ ] Statistics calculate correctly

## 🔐 Privacy & Security

- All data stored locally
- No network requests (offline-first)
- Encrypted preferences
- No personal data collection

## 🚧 Future Enhancements (After iOS Version)

1. Cloud sync between devices
2. Family sharing of reminders
3. AI-suggested good deeds
4. Gamification with rewards
5. Community challenges
6. Integration with calendar apps
7. Widget for quick actions
8. Wear OS companion app

## 📞 Support

For issues with alarms not triggering:

1. Check all permissions are granted
2. Verify battery optimization is disabled
3. Check notification channels are not blocked
4. Review debug logs in app
5. Test with test notification feature

## License

MIT License - Feel free to use for good deeds!

---

**Remember**: The #1 priority is RELIABILITY. Every reminder must trigger, even if the phone has been locked for hours. This is achieved through multiple redundant systems working together.
