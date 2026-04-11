import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_page.dart';
import 'services/audio_handler.dart';
import 'services/ad_manager.dart';

late MyAudioHandler audioHandler;

bool isGlobalTVDevice = false;

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep splash visible while initializing
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Detect Device Type automatically
  final double logicalWidth = ui.PlatformDispatcher.instance.views.first.physicalSize.width /
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
  isGlobalTVDevice = logicalWidth > 600;

  // Set adaptive orientation lock
  if (isGlobalTVDevice) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
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

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomePage(),
  ));
}
