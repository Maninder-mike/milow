# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase
-keep class com.supabase.** { *; }
-keep class io.supabase.** { *; }
-keep class gotrue.** { *; }
-keep class realtime.** { *; }
-keep class storage.** { *; }
-keep class postgrest.** { *; }
-keep class functions.** { *; }

# Flutter Map & LatLong
-keep class org.osmdroid.** { *; }
-keep class org.locationtech.jts.** { *; }
-keep class com.github.jts.** { *; }
-keep class net.sf.geographiclib.** { *; }
# Keep generic map implementation classes
-keep class flutter_map.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# OkHttp (Used by many dart packages internally)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Retrofit (if used)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

# Generic warnings usually safe to ignore in Flutter
-dontwarn java.nio.**
-dontwarn javax.xml.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
-dontwarn sun.misc.Unsafe

# Keep all flutter plugins
-keep class com.baseflow.** { *; }
-keep class io.flutter.plugins.** { *; }

# Deferred Components / Play Core (Safe to ignore if not using dynamic features)
-dontwarn com.google.android.play.core.**

# ML Kit Text Recognition (Optional language sub-packages)
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.mlkit.vision.text.** { *; }
