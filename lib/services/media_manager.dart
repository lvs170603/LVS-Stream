import 'package:media_kit/media_kit.dart';
import '../main.dart'; // To access global audioHandler

class MediaManager {
  static final MediaManager _instance = MediaManager._internal();
  factory MediaManager() => _instance;
  MediaManager._internal();

  Player? _activeVideoPlayer;

  /// Call this when a TV channel starts playing to ensure the Radio stops
  Future<void> registerAndPlayVideo(Player videoPlayer) async {
    _activeVideoPlayer = videoPlayer;
    // Guarantee Radio EXCLUSIVITY: Stop radio immediately before video begins
    await audioHandler.stop();
  }

  /// Call this when the Video Player is closed gracefully
  void disposeVideoPlayer() {
    _activeVideoPlayer = null;
  }

  /// Call this when a Radio stream starts to ensure the Video stops securely
  Future<void> prepareRadioAudio() async {
    // Guarantee TV EXCLUSIVITY in case background processes kept media_kit alive
    if (_activeVideoPlayer != null) {
      await _activeVideoPlayer!.pause();
      // Since videoPlayer will be disposed by its StatefulWidget anyway, 
      // we just nullify our reference.
      _activeVideoPlayer = null;
    }
  }
}
