## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

## Video Player
-keep class io.flutter.plugins.videoplayer.** { *; }

## Media3 / ExoPlayer - keep all decoders including FFmpeg AC3 extension
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.material.** { *; }
-keep class androidx.** { *; }
