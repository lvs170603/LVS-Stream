import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:media_kit/media_kit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_page.dart';
import 'services/audio_handler.dart';

late MyAudioHandler audioHandler;

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep splash visible while initializing
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

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
