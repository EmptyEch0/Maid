## flutter_local_notifications persists scheduled notifications with GSON.
## R8 strips the generic type info GSON needs, which makes zonedSchedule() throw
## "Missing type parameter" in release builds, so no alarm or reminder is ever scheduled.
## Rules from https://github.com/google/gson/blob/main/examples/android-proguard-example/proguard.cfg

-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

## The plugin's serialized model classes (NotificationDetails etc.)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
