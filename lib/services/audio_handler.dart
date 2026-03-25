import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'audio_control_service.dart';
import 'media_manager.dart';

Future<MyAudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.lvstv.app.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  
  MyAudioHandler() {
    AudioControlService.init();
    _applyAudioSettings();
    Hive.box('settingsBox').listenable().addListener(() {
      _applyAudioSettings();
    });

    AudioControlService.eventStream.listen((event) {
      if (event['event'] == 'isPlayingChanged') {
        final playing = event['isPlaying'] as bool;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.stop,
            MediaControl.skipToNext,
          ],
          playing: playing,
        ));
      } else if (event['event'] == 'playbackStateChanged') {
        final stateInt = event['state'] as int;
        final processingState = {
          1: AudioProcessingState.idle,
          2: AudioProcessingState.buffering,
          3: AudioProcessingState.ready,
          4: AudioProcessingState.completed,
        }[stateInt] ?? AudioProcessingState.idle;
        
        playbackState.add(playbackState.value.copyWith(
          processingState: processingState,
        ));
      } else if (event['event'] == 'queueIndexChanged') {
        final index = event['index'] as int;
        playbackState.add(playbackState.value.copyWith(queueIndex: index));
        if (queue.value.isNotEmpty && index >= 0 && index < queue.value.length) {
          mediaItem.add(queue.value[index]);
        }
      } else if (event['event'] == 'positionChanged') {
        final positionMs = event['position'] as int;
        final durationMs = event['duration'] as int;
        
        playbackState.add(playbackState.value.copyWith(
          updatePosition: Duration(milliseconds: positionMs),
        ));
        
        if (mediaItem.value != null && durationMs > 0) {
          mediaItem.add(mediaItem.value!.copyWith(
            duration: Duration(milliseconds: durationMs),
          ));
        }
      }
    });
  }

  Future<void> loadPlaylist(List<dynamic> channels, int initialIndex) async {
    // MediaManager intercepts and guarantees TV exclusivity when starting radio
    await MediaManager().prepareRadioAudio();

    final mediaItems = channels.map((c) {
      final artUri = c.icon.isNotEmpty ? c.icon : 'https://via.placeholder.com/512x512.png?text=Radio';
      return MediaItem(
        id: c.url,
        album: c.category,
        title: c.name,
        artist: c.name,
        artUri: Uri.parse(artUri),
      );
    }).toList();

    queue.add(mediaItems);
    if (initialIndex >= 0 && initialIndex < mediaItems.length) {
      mediaItem.add(mediaItems[initialIndex]);
    }
    
    final urls = channels.map((c) => c.url.toString()).toList();
    await AudioControlService.loadPlaylist(urls, initialIndex);
  }

  void _applyAudioSettings() {
    final box = Hive.box('settingsBox');
    final bool mono = box.get('monoAudio', defaultValue: false);
    final double balance = box.get('audioBalance', defaultValue: 0.0);
    final double volume = box.get('audioVolume', defaultValue: 1.0);
    
    AudioControlService.setMono(mono);
    AudioControlService.setBalance(balance);
    AudioControlService.setVolume(volume);
  }

  Future<void> setVolume(double volume) async {
    final box = Hive.box('settingsBox');
    await box.put('audioVolume', volume);
    await AudioControlService.setVolume(volume);
  }

  @override
  Future<void> play() => AudioControlService.play();

  @override
  Future<void> pause() => AudioControlService.pause();

  @override
  Future<void> skipToNext() => AudioControlService.skipToNext();

  @override
  Future<void> skipToPrevious() => AudioControlService.skipToPrevious();

  @override
  Future<void> stop() async {
    await AudioControlService.stop();
    return super.stop();
  }
}
