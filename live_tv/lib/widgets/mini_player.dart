import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/channel.dart';
import '../main.dart';
import '../radio_player_page.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _isMainFocused = false;

  void _openFullPlayer(BuildContext context, MediaItem item) {
    final box = Hive.box('channelsBox');
    final String? cachedData = box.get('channels');
    List<Channel> channels = [];
    
    if (cachedData != null) {
      final List<dynamic> data = json.decode(cachedData);
      channels = data.map((j) => Channel.fromJson(j)).toList();
    }

    // Only route to radio channels list as the audio engine is strictly scoped for Radio
    final radioChannels = channels.where((c) => c.category.toLowerCase() == 'radio').toList();
    int initialIndex = radioChannels.indexWhere((c) => c.url == item.id);
    
    if (initialIndex == -1) initialIndex = 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RadioPlayerPage(
          channels: radioChannels,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink(); // Hide safely if not playing

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final isPlaying = state?.playing ?? false;
            final processingState = state?.processingState ?? AudioProcessingState.idle;

            // Hide completely if playback has stopped organically or errored aggressively
            if (processingState == AudioProcessingState.idle || processingState == AudioProcessingState.error) {
              return const SizedBox.shrink();
            }

            return Focus(
              onFocusChange: (value) {
                if (mounted) {
                  setState(() => _isMainFocused = value);
                }
              },
              child: GestureDetector(
                onTap: () => _openFullPlayer(context, mediaItem),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 70,
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1a1a24) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      if (_isMainFocused)
                        BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(80), blurRadius: 15, spreadRadius: 2)
                      else
                        BoxShadow(
                          color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                    ],
                    border: Border.all(
                      color: _isMainFocused ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      width: _isMainFocused ? 2 : 1,
                    ),
                  ),
                child: Row(
                  children: [
                    // Channel Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                        child: CachedNetworkImage(
                          imageUrl: mediaItem.artUri?.toString() ?? '',
                          fit: BoxFit.contain,
                          errorWidget: (context, url, err) => const Icon(Icons.radio, color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Title and Subtitle Matrix
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mediaItem.title,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Live ${mediaItem.album ?? 'Radio'}",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    // Controls
                    if (processingState == AudioProcessingState.loading || processingState == AudioProcessingState.buffering)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    else ...[
                      _MiniFocusIconButton(
                        icon: isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        iconSize: 36,
                        color: Theme.of(context).colorScheme.onSurface,
                        onPressed: () {
                          if (isPlaying) {
                            audioHandler.pause();
                          } else {
                            audioHandler.play();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _MiniFocusIconButton(
                        icon: Icons.close,
                        iconSize: 28,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        onPressed: () {
                          audioHandler.stop();
                        },
                      ),
                    ]
                  ],
                ),
              ),
            ));
          },
        );
      },
    );
  }
}

class _MiniFocusIconButton extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onPressed;
  final Color color;

  const _MiniFocusIconButton({
    required this.icon,
    required this.iconSize,
    required this.onPressed,
    this.color = Colors.white,
  });

  @override
  State<_MiniFocusIconButton> createState() => _MiniFocusIconButtonState();
}

class _MiniFocusIconButtonState extends State<_MiniFocusIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: _isFocused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onFocusChange: (val) {
              if (mounted) setState(() => _isFocused = val);
            },
            onTap: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(widget.icon, size: widget.iconSize, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}
