import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'models/channel.dart';
import 'main.dart'; // To access the global audioHandler

class RadioPlayerPage extends StatefulWidget {
  final Channel channel;

  const RadioPlayerPage({Key? key, required this.channel}) : super(key: key);

  @override
  State<RadioPlayerPage> createState() => _RadioPlayerPageState();
}

class _RadioPlayerPageState extends State<RadioPlayerPage> {
  @override
  void initState() {
    super.initState();
    _playRadio();
  }

  Future<void> _playRadio() async {
    // Determine the artUri, falling back to a placeholder if none exists
    final artUri = (widget.channel.icon.isNotEmpty) 
        ? widget.channel.icon 
        : 'https://via.placeholder.com/512x512.png?text=Radio';

    await audioHandler.loadChannel(
      widget.channel.url,
      widget.channel.name,
      widget.channel.category,
      artUri,
    );
    audioHandler.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f13),
      appBar: AppBar(
        title: Text(widget.channel.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Radio continues playing in the background when popping the route
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
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
                  imageUrl: widget.channel.icon,
                  fit: BoxFit.contain,
                  errorWidget: (context, url, err) => const Icon(Icons.radio, size: 100, color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 50),
            Text(
              widget.channel.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Live ${widget.channel.category} Stream",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 60),
            StreamBuilder<PlaybackState>(
              stream: audioHandler.playbackState,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final processingState = state?.processingState ?? AudioProcessingState.idle;
                final playing = state?.playing ?? false;

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
                    IconButton(
                      iconSize: 84,
                      icon: Icon(
                        playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (playing) {
                          audioHandler.pause();
                        } else {
                          audioHandler.play();
                        }
                      },
                    ),
                    const SizedBox(width: 30),
                    IconButton(
                      iconSize: 52,
                      icon: const Icon(Icons.stop_circle_outlined, color: Colors.white70),
                      onPressed: () {
                        audioHandler.stop();
                        // Also exit page when stopped completely
                        Navigator.pop(context);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
