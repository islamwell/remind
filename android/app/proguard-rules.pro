# Flutter specific
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Good Deeds Reminder specific
-keep class com.gooddeeds.reminder.** { *; }

# AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Notifications
-keep class com.google.android.gms.** { *; }
-keep class android.support.v4.app.NotificationCompat$* { *; }

# Alarm Manager
-keep class android.app.AlarmManager { *; }
-keep class android.app.PendingIntent { *; }

# System Alert Window
-keep class android.view.WindowManager$LayoutParams { *; }

-dontwarn io.flutter.embedding.**
-ignorewarnings
