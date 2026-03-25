import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/channel.dart';
import 'main.dart'; // To access the global audioHandler

class RadioPlayerPage extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;

  const RadioPlayerPage({Key? key, required this.channels, required this.initialIndex}) : super(key: key);

  @override
  State<RadioPlayerPage> createState() => _RadioPlayerPageState();
}

class _RadioPlayerPageState extends State<RadioPlayerPage> {
  double _volume = 1.0;
  bool _isVolumeSliderFocused = false;
  bool _isMuteFocused = false;
  late final FocusNode _volumeFocusNode;
  late final FocusNode _playerFocusNode;

  @override
  void initState() {
    super.initState();
    _volumeFocusNode = FocusNode();
    _playerFocusNode = FocusNode();
    _volume = Hive.box('settingsBox').get('audioVolume', defaultValue: 1.0);
    _playRadio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playerFocusNode.requestFocus();
    });
  }

  Future<void> _playRadio() async {
    await audioHandler.loadPlaylist(widget.channels, widget.initialIndex);
    audioHandler.play();
  }

  @override
  void dispose() {
    _volumeFocusNode.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  // ── TV remote playback helpers ───────────────────────
  void _playPreviousChannel() {
    final idx = audioHandler.playbackState.value.queueIndex ?? 0;
    if (idx > 0) audioHandler.skipToPrevious();
  }

  void _playNextChannel() {
    final idx = audioHandler.playbackState.value.queueIndex ?? 0;
    if (idx < widget.channels.length - 1) audioHandler.skipToNext();
  }

  void _togglePlayPause() {
    if (audioHandler.playbackState.value.playing) {
      audioHandler.pause();
    } else {
      audioHandler.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_volumeFocusNode.hasFocus) {
          _volumeFocusNode.unfocus();
          return false;
        }
        return true;
      },
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.arrowLeft):  const PrevRadioIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextRadioIntent(),
          LogicalKeySet(LogicalKeyboardKey.select):     const ToggleRadioIntent(),
          LogicalKeySet(LogicalKeyboardKey.enter):      const ToggleRadioIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            PrevRadioIntent:   CallbackAction<PrevRadioIntent>(onInvoke: (_) => _playPreviousChannel()),
            NextRadioIntent:   CallbackAction<NextRadioIntent>(onInvoke: (_) => _playNextChannel()),
            ToggleRadioIntent: CallbackAction<ToggleRadioIntent>(onInvoke: (_) => _togglePlayPause()),
          },
          child: Focus(
            autofocus: true,
            focusNode: _playerFocusNode,
            child: Scaffold(
      backgroundColor: const Color(0xFF0f0f13),
      appBar: AppBar(
        title: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final item = snapshot.data;
            return Text(item?.title ?? 'Radio');
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, itemSnapshot) {
            final item = itemSnapshot.data;
            final artUri = item?.artUri?.toString() ?? 'https://via.placeholder.com/512x512.png?text=Radio';
            final title = item?.title ?? 'Loading...';
            final category = item?.album ?? 'Radio Streams';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 250,
                  width: 250,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: artUri,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, err) => const Icon(Icons.radio, size: 100, color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Live $category Stream",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 60),
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final processingState = state?.processingState ?? AudioProcessingState.idle;
                    final playing = state?.playing ?? false;
                    final queueIndex = state?.queueIndex ?? 0;
                    
                    final hasPrevious = queueIndex > 0;
                    final hasNext = queueIndex < widget.channels.length - 1;

                    if (processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering) {
                      return Container(
                        margin: const EdgeInsets.all(24.0),
                        width: 64.0,
                        height: 64.0,
                        child: const CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _FocusableIconButton(
                          iconSize: 52,
                          icon: Icons.skip_previous_rounded,
                          color: hasPrevious ? Colors.white : Colors.white24,
                          onPressed: hasPrevious ? () => audioHandler.skipToPrevious() : null,
                        ),
                        const SizedBox(width: 20),
                        _FocusableIconButton(
                          iconSize: 84,
                          icon: playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                          color: Colors.white,
                          onPressed: () {
                            if (playing) {
                              audioHandler.pause();
                            } else {
                              audioHandler.play();
                            }
                          },
                        ),
                        const SizedBox(width: 20),
                        _FocusableIconButton(
                          iconSize: 52,
                          icon: Icons.skip_next_rounded,
                          color: hasNext ? Colors.white : Colors.white24,
                          onPressed: hasNext ? () => audioHandler.skipToNext() : null,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    children: [
                      AnimatedScale(
                        scale: _isMuteFocused ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: _isMuteFocused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                            boxShadow: _isMuteFocused ? [BoxShadow(color: Colors.white.withAlpha(80), blurRadius: 15, spreadRadius: 2)] : [],
                          ),
                          child: InkWell(
                            onFocusChange: (val) => setState(() => _isMuteFocused = val),
                            onTap: () {
                              final newVol = _volume > 0 ? 0.0 : 1.0;
                              setState(() => _volume = newVol);
                              audioHandler.setVolume(newVol);
                            },
                            customBorder: const CircleBorder(),
                            child: Icon(
                              _volume <= 0.0 ? Icons.volume_off : (_volume < 0.5 ? Icons.volume_down : Icons.volume_up),
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: _isVolumeSliderFocused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                            boxShadow: _isVolumeSliderFocused ? [BoxShadow(color: Colors.white.withAlpha(50), blurRadius: 10, spreadRadius: 1)] : [],
                          ),
                          child: Focus(
                            focusNode: _volumeFocusNode,
                            onFocusChange: (val) => setState(() => _isVolumeSliderFocused = val),
                            onKeyEvent: (node, event) {
                              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                                return KeyEventResult.ignored;
                              }
                              double? newVol;
                              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                newVol = (_volume - 0.05).clamp(0.0, 1.0);
                              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                newVol = (_volume + 0.05).clamp(0.0, 1.0);
                              }
                              if (newVol != null) {
                                setState(() => _volume = newVol!);
                                audioHandler.setVolume(newVol);
                                Hive.box('settingsBox').put('audioVolume', newVol);
                                return KeyEventResult.handled; // prevent bubbling to Shortcuts
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Slider(
                              value: _volume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                              onChanged: (val) {
                                setState(() => _volume = val);
                                audioHandler.setVolume(val);
                                Hive.box('settingsBox').put('audioVolume', val);
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          "${(_volume * 100).toInt()}%",
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
      ),
      ),
      ),
    );
  }
}

class _FocusableIconButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onPressed;
  final Color color;

  const _FocusableIconButton({
    required this.icon,
    required this.iconSize,
    required this.onPressed,
    this.color = Colors.white,
  });

  @override
  State<_FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<_FocusableIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: _isFocused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
          boxShadow: _isFocused
            ? [BoxShadow(color: Colors.white.withAlpha(80), blurRadius: 15, spreadRadius: 2)]
            : [],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onFocusChange: (val) => setState(() => _isFocused = val),
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(widget.icon, size: widget.iconSize, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── TV Remote Intent classes ──────────────────────────────
class PrevRadioIntent   extends Intent { const PrevRadioIntent(); }
class NextRadioIntent   extends Intent { const NextRadioIntent(); }
class ToggleRadioIntent extends Intent { const ToggleRadioIntent(); }
