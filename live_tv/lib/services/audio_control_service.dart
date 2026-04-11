import 'package:flutter/services.dart';
import 'dart:async';

class AudioControlService {
  static const _methodChannel = MethodChannel('audio_control');
  static const _eventChannel = EventChannel('audio_control_events');

  static final StreamController<Map<String, dynamic>> _eventStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  static Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  static void init() {
    _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        _eventStreamController.add(Map<String, dynamic>.from(event));
      }
    });
  }

  static Future<void> loadPlaylist(List<String> urls, int index) async {
    await _methodChannel.invokeMethod('loadPlaylist', {
      'urls': urls,
      'index': index,
    });
  }

  static Future<void> play() async => await _methodChannel.invokeMethod('play');
  static Future<void> pause() async => await _methodChannel.invokeMethod('pause');
  static Future<void> skipToNext() async => await _methodChannel.invokeMethod('skipToNext');
  static Future<void> skipToPrevious() async => await _methodChannel.invokeMethod('skipToPrevious');
  static Future<void> stop() async => await _methodChannel.invokeMethod('stop');
  
  static Future<void> setBalance(double value) async {
    await _methodChannel.invokeMethod('setBalance', value);
  }

  static Future<void> setMono(bool isMono) async {
    await _methodChannel.invokeMethod('setMono', isMono);
  }

  static Future<void> setVolume(double value) async {
    await _methodChannel.invokeMethod('setVolume', value);
  }
}
