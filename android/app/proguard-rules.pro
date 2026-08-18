# Flutter ProGuard/R8 Rules for Release Build Shrinking

# Flutter Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase Native Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Local Authentication Plugin
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Native Code Serialization / Deserialization
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Suppress warnings from third-party libraries
-dontwarn **
