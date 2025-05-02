# Keep only English (Latin) text recognition and ignore others
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**

# Optional: Fully keep the English recognizer class if needed
-keep class com.google.mlkit.vision.text.latin.** { *; }

# Keep classes for device_calendar
-keep class com.builttoroam.devicecalendar.** { *; }
-keep class com.builttoroam.devicecalendar.models.** { *; }
-keep class com.builttoroam.devicecalendar.platforms.** { *; }
