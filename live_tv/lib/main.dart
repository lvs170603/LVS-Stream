import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'services/audio_handler.dart';
import 'services/ad_manager.dart';
import 'providers/theme_provider.dart';
import 'widgets/connectivity_wrapper.dart';

late MyAudioHandler audioHandler;

bool isGlobalTVDevice = false;

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep splash visible while initializing
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // ── TV Detection (multi-signal, robust at cold-boot) ──────────────────
  // Signal 1: physical screen width — TVs are always landscape & wide.
  // A width > 800dp strongly indicates TV/tablet landscape; phones are < 450dp.
  // We use the MAX of width/height so portrait phones don't accidentally qualify.
  final view = ui.PlatformDispatcher.instance.views.first;
  final physW = view.physicalSize.width  / view.devicePixelRatio;
  final physH = view.physicalSize.height / view.devicePixelRatio;
  final longestSide = physW > physH ? physW : physH;
  final shortestSide = physW < physH ? physW : physH;

  // Signal 2: Ask Android whether the device declares leanback / TV mode.
  // This returns 'tv' on Android TV and Fire TV devices.
  bool nativeTVMode = false;
  try {
    const _ch = MethodChannel('tv_device_check');
    final String result = await _ch.invokeMethod('isTV') ?? 'false';
    nativeTVMode = result == 'true';
  } catch (_) {
    // Channel not wired yet — fall back to size heuristic only.
  }

  // Detect if device is a tablet (shortest side >= 600dp)
  bool isTablet = shortestSide >= 600;

  // TV = native flag OR (wide screen > 800dp AND landscape aspect ratio)
  // We use platform-specific checks and screen width heuristic.
  isGlobalTVDevice = nativeTVMode || (!isTablet && longestSide > 800 && longestSide > shortestSide * 1.2);

  debugPrint('[Boot] physW=$physW physH=$physH longest=$longestSide nativeTV=$nativeTVMode isTablet=$isTablet → isTV=$isGlobalTVDevice');

  // ── Orientation lock ─────────────────────────────────────────────────
  if (isGlobalTVDevice) {
    // Android TV: Always run in landscape mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Full immersive mode for TV: hide status + nav bars
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    // Mobile & Tablet: Follow system auto-rotate setting.
    // By allowing all orientations, the app opens in portrait by default (if auto-rotate is off)
    // and rotates freely if auto-rotate is enabled in device settings.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // Initialize Ads
  await AdManager.instance.initialize();

  MediaKit.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('channelsBox');
  await Hive.openBox('settingsBox');
  
  audioHandler = await initAudioService();

  // Initialization done — dismiss splash
  FlutterNativeSplash.remove();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const _LvsApp(),
    ),
  );
}

class _LvsApp extends StatelessWidget {
  const _LvsApp();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.mode,   // <-- reacts instantly to user changes
    
    // LIGHT MODE DEFINITION
    theme: ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF2196F3),          // Professional OTT blue accent
      scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Soft neutral background
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Color(0xFF2196F3)),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Color(0x1A000000),
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: const Color(0xFF2196F3),             // Blue focus/accent
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE3F2FD),    // Light blue tint for containers
        onPrimaryContainer: const Color(0xFF0D47A1),
        secondary: const Color(0xFF1565C0),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFBBDEFB),
        onSecondaryContainer: const Color(0xFF0D47A1),
        surface: Colors.white,
        onSurface: const Color(0xFF1A1A1A),           // High-contrast title text
        onSurfaceVariant: const Color(0xFF555555),    // Secondary text
        error: const Color(0xFFD32F2F),
        onError: Colors.white,
        outline: const Color(0xFFE0E0E0),             // Card border on TV
        outlineVariant: const Color(0xFFEEEEEE),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
      textTheme: const TextTheme(
        titleMedium: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: Color(0xFF1A1A1A)),
        bodySmall: TextStyle(color: Color(0xFF555555)),
        labelSmall: TextStyle(color: Color(0xFF555555)),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
      dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE), thickness: 1),
    ),
    
    // DARK MODE DEFINITION
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF6366f1),
      scaffoldBackgroundColor: const Color(0xFF0f0f13),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Colors.white),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6366f1),
        brightness: Brightness.dark,
        surface: const Color(0xFF141419), // Sidebar & Cards
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white54,
        primary: const Color(0xFF6366f1),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white54),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF141419)),
    ),

      home: const ConnectivityWrapper(child: HomePage()),
    );
  }
}
