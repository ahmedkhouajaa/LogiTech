# ==============================================================================
# LogiTech Pro - Android ProGuard & R8 Obfuscation Rules
# ==============================================================================

# Flutter & Core Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve custom security channel in MainActivity
-keep class com.example.business_manager_pro.MainActivity { *; }

# Firebase Core & Firestore
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Local Auth & Biometrics
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# Secure Storage / Crypto
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Google Play Core & Deferred Components (to prevent R8 missing classes errors)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.gms.**

# General Optimization
-repackageclasses ''
-allowaccessmodification
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose
