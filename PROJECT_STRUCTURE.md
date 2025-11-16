# Good Deeds Reminder - Android Project Structure

## 📁 Project Structure

```
good_deeds_reminder_android/
├── android/                      # Android native code
│   ├── app/
│   │   ├── src/
│   │   │   ├── main/
│   │   │   │   ├── AndroidManifest.xml  # App permissions & components
│   │   │   │   ├── kotlin/              # Kotlin native code
│   │   │   │   │   └── com/gooddeeds/reminder/
│   │   │   │   │       ├── MainActivity.kt
│   │   │   │   │       ├── AlarmReceiver.kt
│   │   │   │   │       ├── BootReceiver.kt
│   │   │   │   │       ├── AlarmForegroundService.kt
│   │   │   │   │       └── FullScreenAlarmActivity.kt
│   │   │   │   └── res/                 # Android resources
│   │   │   │       ├── drawable/
│   │   │   │       ├── values/
│   │   │   │       └── xml/
│   │   │   ├── debug/
│   │   │   └── profile/
│   │   ├── build.gradle          # App-level build configuration
│   │   └── proguard-rules.pro    # ProGuard rules for release
│   ├── gradle/
│   │   └── wrapper/
│   │       └── gradle-wrapper.properties
│   ├── build.gradle              # Project-level build configuration
│   ├── settings.gradle
│   └── gradle.properties
├── lib/                          # Flutter/Dart code
│   ├── main.dart                 # App entry point
│   ├── config/
│   │   └── app_theme.dart        # Design system & theme
│   ├── models/
│   │   └── reminder.dart         # Data models
│   ├── screens/
│   │   ├── modern_main_screen.dart
│   │   ├── add_reminder.dart
│   │   ├── full_screen_alarm.dart
│   │   ├── reminder_detail_screen.dart
│   │   ├── logs_screen.dart
│   │   └── settings_screen.dart
│   ├── services/
│   │   ├── alarm_service.dart    # Core alarm logic
│   │   ├── notification_service.dart
│   │   └── logging_service.dart
│   └── widgets/
│       ├── reminder_card.dart
│       └── stat_card.dart
├── assets/                       # App assets
│   ├── sounds/                   # Alarm sounds
│   ├── images/                   # Images
│   └── fonts/                    # Custom fonts
├── test/                         # Unit & widget tests
├── pubspec.yaml                  # Flutter dependencies
├── analysis_options.yaml         # Dart linter rules
├── README.md                     # Main documentation
└── .gitignore                    # Git ignore rules
```

## 🚀 Setup Instructions

### Prerequisites
1. **Flutter SDK** (3.0.0 or higher)
2. **Android Studio** or **VS Code** with Flutter plugin
3. **Android SDK** (API 21+)
4. **JDK 11** or higher

### Installation Steps

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/good-deeds-reminder.git
cd good-deeds-reminder
```

2. **Install dependencies:**
```bash
flutter pub get
```

3. **Add default alarm sound:**
   - Place an MP3 file named `default_alarm.mp3` in `assets/sounds/`

4. **Configure Android permissions:**
   - All permissions are already configured in `AndroidManifest.xml`
   - The app will request necessary permissions on first launch

5. **Build and run:**
```bash
# For debug mode
flutter run

# For release APK
flutter build apk --release

# For App Bundle (Google Play)
flutter build appbundle --release
```

## ✨ New Features Added

### 🔕 Do Not Disturb Mode
- **Location**: Settings → Do Not Disturb
- **Features**:
  - Toggle to enable/disable
  - Set start and end times
  - Automatically silences reminders during set hours
  - Saves preferences locally
  - Works even when app is closed

### Implementation Details:
- Settings stored in `SharedPreferences`
- Checked before triggering alarms
- Respects user's quiet hours
- Can handle overnight periods (e.g., 10 PM to 7 AM)

## 📱 Key Components

### Native Android Components

1. **MainActivity.kt**
   - Main Flutter activity
   - Configured to show over lock screen

2. **AlarmReceiver.kt**
   - Receives alarm broadcasts
   - Wakes device from sleep
   - Launches full-screen alarm

3. **FullScreenAlarmActivity.kt**
   - Native full-screen alarm
   - Shows over lock screen
   - Handles wake lock
   - Plays alarm sound & vibration

4. **BootReceiver.kt**
   - Restores alarms after reboot
   - Works with direct boot

5. **AlarmForegroundService.kt**
   - Keeps app alive in background
   - Prevents Doze mode interference

### Flutter Components

1. **AlarmService**
   - Core alarm scheduling logic
   - Multiple redundant systems
   - Do Not Disturb integration

2. **Modern UI Screens**
   - Professional Material Design
   - Smooth animations
   - Consistent theming

## 🔒 Critical Permissions

The app requires these permissions for reliable operation:

- `SCHEDULE_EXACT_ALARM` - Exact alarm timing
- `USE_EXACT_ALARM` - Android 12+ exact alarms
- `SYSTEM_ALERT_WINDOW` - Show over other apps
- `USE_FULL_SCREEN_INTENT` - Full screen alarms
- `WAKE_LOCK` - Wake device from sleep
- `DISABLE_KEYGUARD` - Show over lock screen
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` - Prevent Doze mode
- `RECEIVE_BOOT_COMPLETED` - Restore after reboot
- `VIBRATE` - Vibration alerts
- `RECORD_AUDIO` - Voice recording
- `POST_NOTIFICATIONS` - Show notifications

## 🎨 Design System

- **Primary Color**: #4CAF50 (Material Green)
- **Border Radius**: 16px standard
- **Shadows**: Soft, multi-layered
- **Typography**: SF Pro Display
- **Spacing**: 8px grid system

## 🧪 Testing

Run tests:
```bash
# Unit tests
flutter test

# Integration tests
flutter test integration_test/

# With coverage
flutter test --coverage
```

## 📦 Building for Production

### Release Checklist
- [ ] Update version in `pubspec.yaml`
- [ ] Test on multiple Android versions (10-14)
- [ ] Verify all permissions work
- [ ] Test alarm reliability
- [ ] Check Do Not Disturb functionality
- [ ] Generate signed APK/AAB
- [ ] Test on locked devices

### Build Commands
```bash
# Clean build
flutter clean
flutter pub get

# Release APK
flutter build apk --release --target-platform android-arm,android-arm64,android-x64

# App Bundle for Play Store
flutter build appbundle --release
```

## 🐛 Troubleshooting

### Alarms not triggering
1. Check battery optimization is disabled
2. Verify all permissions are granted
3. Check Do Not Disturb settings
4. Review logs in app

### Full screen not showing
1. Enable "Display over other apps" permission
2. Check lock screen notification settings
3. Verify USE_FULL_SCREEN_INTENT permission

## 📄 License

MIT License - See LICENSE file

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Open pull request

## 📞 Support

For issues or questions:
- Open an issue on GitHub
- Check the FAQ in the wiki
- Contact: support@gooddeedsreminder.com

---

**Remember**: The app's #1 priority is RELIABILITY. Every reminder must trigger, even when the phone is locked!
