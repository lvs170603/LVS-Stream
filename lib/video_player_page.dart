import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/src/player/native/player/real.dart';
import 'services/media_manager.dart';
import '../main.dart';
import 'models/channel.dart';

class VideoPlayerPage extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;

  const VideoPlayerPage({
    super.key,
    required this.channels,
    required this.initialIndex,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;
  late int _currentIndex;

  // State
  bool _isError = false;
  bool _isLoading = true;
  bool _showOverlay = false;
  Timer? _overlayTimer;

  // Channel list bottom sheet
  bool _showChannelList = false;
  int _channelListFocusIndex = 0;
  late final ScrollController _channelScrollController;
  late final AnimationController _sheetAnimController;
  late final Animation<Offset> _sheetSlide;
  late final Animation<double> _sheetFade;

  // Gesture hint
  String _gestureHintIcon = '';
  String _gestureHintLabel = '';
  bool _showGestureHint = false;
  Timer? _gestureHintTimer;

  final FocusNode _focusNode = FocusNode();

  // Width of each card in the horizontal channel row
  static const double _itemWidth = 120.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _channelListFocusIndex = _currentIndex;
    _channelScrollController = ScrollController();

    // Slide animation for the bottom sheet
    _sheetAnimController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sheetAnimController,
      curve: Curves.easeOutCubic,
    ));
    _sheetFade = CurvedAnimation(
      parent: _sheetAnimController,
      curve: Curves.easeOut,
    );

    _player = Player();
    _videoController = VideoController(_player);
    _initializePlayer();
    WakelockPlus.enable();
    // Force landscape + hide status & navigation bars
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _overlayTimer?.cancel();
    _gestureHintTimer?.cancel();
    _channelScrollController.dispose();
    _sheetAnimController.dispose();
    MediaManager().disposeVideoPlayer();
    _player.dispose();
    WakelockPlus.disable();
    // Restore portrait orientation and system UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─────────────────────────── Player ───────────────────────────

  Future<void> _initializePlayer() async {
    final channel = widget.channels[_currentIndex];
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isError = false;
        _showOverlay = true;
      });
    }
    _startOverlayTimer();

    try {
      await MediaManager().registerAndPlayVideo(_player);
      await _player.open(
        Media(channel.url, httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
        }),
      );
      await _player.setVolume(100.0);
      _applyAudioSettings();
      if (mounted) {
        setState(() => _isLoading = false);
        _focusNode.requestFocus();
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
    }
  }

  void _applyAudioSettings() {
    final box = Hive.box('settingsBox');
    final bool isMono = box.get('monoAudio', defaultValue: false);
    final double balance = box.get('audioBalance', defaultValue: 0.0);

    List<String> filters = [];
    if (isMono) {
      filters.add('pan=mono|c0=0.5*c0+0.5*c1');
    } else if (balance != 0.0) {
      final leftVol = balance < 0 ? 1.0 : (1.0 - balance);
      final rightVol = balance > 0 ? 1.0 : (1.0 + balance);
      filters.add('pan=stereo|c0=$leftVol*c0|c1=$rightVol*c1');
    }

    try {
      final nativePlayer = _player.platform as NativePlayer;
      if (filters.isNotEmpty) {
        nativePlayer.setProperty('af', filters.join(','));
      } else {
        nativePlayer.setProperty('af', '');
      }
    } catch (e) {
      debugPrint("Cannot apply audio filters natively: $e");
    }
  }

  void _changeChannel(int offset) {
    int newIndex = _currentIndex + offset;
    if (newIndex < 0) newIndex = widget.channels.length - 1;
    if (newIndex >= widget.channels.length) newIndex = 0;
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
      _initializePlayer();
    }
  }

  void _switchToChannel(int index) {
    if (index == _currentIndex) {
      _closeChannelList();
      return;
    }
    setState(() => _currentIndex = index);
    _initializePlayer();
    _closeChannelList();
  }

  void _togglePlay() {
    if (_player.state.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    _showOverlayWithOptions(force: true);
  }


  // ─────────────────────── Channel List Sheet ───────────────────────

  void _openChannelList() {
    setState(() {
      _showChannelList = true;
      _channelListFocusIndex = _currentIndex;
    });
    _sheetAnimController.forward();
    // Scroll to current channel horizontally
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offset = (_currentIndex * _itemWidth) -
          (_channelScrollController.hasClients
              ? _channelScrollController.position.viewportDimension / 2
              : 0) +
          _itemWidth / 2;
      if (_channelScrollController.hasClients) {
        _channelScrollController.animateTo(
          offset.clamp(0.0, _channelScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _closeChannelList() {
    _sheetAnimController.reverse().then((_) {
      if (mounted) setState(() => _showChannelList = false);
    });
  }

  void _navigateChannelList(int direction) {
    final newIndex =
        (_channelListFocusIndex + direction).clamp(0, widget.channels.length - 1);
    setState(() => _channelListFocusIndex = newIndex);

    // Auto-scroll horizontally to keep the focused card visible
    if (_channelScrollController.hasClients) {
      final offset = newIndex * _itemWidth;
      final viewport = _channelScrollController.position.viewportDimension;
      final current = _channelScrollController.offset;
      if (offset < current) {
        _channelScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      } else if (offset + _itemWidth > current + viewport) {
        _channelScrollController.animateTo(
          offset + _itemWidth - viewport,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    }
  }

  // ─────────────────────────── OSD ───────────────────────────────

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing) {
        setState(() => _showOverlay = false);
      }
    });
  }

  void _showOverlayWithOptions({bool force = false}) {
    setState(() => _showOverlay = true);
    if (!_player.state.playing && force) {
      _overlayTimer?.cancel();
    } else {
      _startOverlayTimer();
    }
  }

  // ─────────────────────────── Gestures ──────────────────────────

  void _showGestureHintOverlay(String icon, String label) {
    _gestureHintTimer?.cancel();
    setState(() {
      _gestureHintIcon = icon;
      _gestureHintLabel = label;
      _showGestureHint = true;
    });
    _gestureHintTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showGestureHint = false);
    });
  }

  void _handleSwipe(DragEndDetails details) {
    // Don't intercept swipes while the channel list is open
    if (_showChannelList) return;

    const double swipeThreshold = 300.0;
    final dx = details.velocity.pixelsPerSecond.dx;
    final dy = details.velocity.pixelsPerSecond.dy;

    if (dx.abs() > dy.abs()) {
      if (dx < -swipeThreshold) {
        _showGestureHintOverlay('⏭', 'Next Channel');
        _changeChannel(1);
      } else if (dx > swipeThreshold) {
        _showGestureHintOverlay('⏮', 'Previous Channel');
        _changeChannel(-1);
      }
    } else {
      if (dy < -swipeThreshold) {
        // Swipe UP → open channel list
        _showGestureHintOverlay('📋', 'Channel List');
        _openChannelList();
      } else if (dy > swipeThreshold) {
        // Swipe DOWN → back to home
        _showGestureHintOverlay('🏠', 'Channel List');
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  void _handleTap(TapUpDetails details) {
    if (_showChannelList) {
      _closeChannelList();
      return;
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    final inCenterX = tapX > screenWidth * 0.25 && tapX < screenWidth * 0.75;
    final inCenterY = tapY > screenHeight * 0.25 && tapY < screenHeight * 0.75;

    if (inCenterX && inCenterY) {
      _togglePlay();
      _showGestureHintOverlay(
        _player.state.playing ? '⏸' : '▶',
        _player.state.playing ? 'Paused' : 'Playing',
      );
    } else {
      _showOverlayWithOptions();
    }
  }

  // ─────────────────────────── Build ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentChannel = widget.channels[_currentIndex];

    return PopScope(
      canPop: !_showChannelList,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showChannelList) _closeChannelList();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PreviousChannelIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextChannelIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowUp): const ChannelListUpIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowDown): const ChannelListDownIntent(),
            LogicalKeySet(LogicalKeyboardKey.escape): const CloseChannelListIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
                if (_showChannelList) {
                  _switchToChannel(_channelListFocusIndex);
                } else {
                  _togglePlay();
                }
                return null;
              }),
              PreviousChannelIntent: CallbackAction<PreviousChannelIntent>(
                  onInvoke: (_) => _showChannelList
                      ? _navigateChannelList(-1)
                      : _changeChannel(-1)),
              NextChannelIntent: CallbackAction<NextChannelIntent>(
                  onInvoke: (_) => _showChannelList
                      ? _navigateChannelList(1)
                      : _changeChannel(1)),
              ChannelListUpIntent: CallbackAction<ChannelListUpIntent>(
                  onInvoke: (_) =>
                      _showChannelList ? null : _openChannelList()),
              ChannelListDownIntent: CallbackAction<ChannelListDownIntent>(
                  onInvoke: (_) => null),
              CloseChannelListIntent: CallbackAction<CloseChannelListIntent>(
                  onInvoke: (_) =>
                      _showChannelList ? _closeChannelList() : null),
            },
            child: Focus(
              autofocus: true,
              focusNode: _focusNode,
              child: GestureDetector(
                onPanEnd: _handleSwipe,
                onTapUp: _handleTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Video
                    Video(controller: _videoController),

                    // 2. Loading
                    if (_isLoading)
                      const ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        ),
                      ),

                    // 3. Error
                    if (_isError)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white, size: 64),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load ${currentChannel.name}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _initializePlayer,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Retry'),
                            )
                          ],
                        ),
                      ),

                    // 4. OSD
                    AnimatedOpacity(
                      opacity: _showOverlay ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black87, Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('LIVE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ]),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.tv,
                                      color: Colors.white54, size: 40),
                                ),
                                const SizedBox(width: 20),
                                StreamBuilder<bool>(
                                  stream: _player.stream.playing,
                                  builder: (context, snapshot) {
                                    final isPlaying = snapshot.data ?? false;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(currentChannel.name,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                          '${currentChannel.category} • Tap to ${isPlaying ? "Pause" : "Play"} • ↑ Channel List',
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const Spacer(),
                                StreamBuilder<bool>(
                                  stream: _player.stream.playing,
                                  builder: (context, snapshot) {
                                    final isPlaying = snapshot.data ?? false;
                                    return !isPlaying
                                        ? const Icon(
                                            Icons.pause_circle_filled,
                                            color: Colors.white,
                                            size: 64)
                                        : const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const LinearProgressIndicator(
                              value: null,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Channel List Bottom Sheet
                    if (_showChannelList) ...[
                      // Semi-transparent scrim
                      FadeTransition(
                        opacity: _sheetFade,
                        child: GestureDetector(
                          onTap: _closeChannelList,
                          child: Container(color: Colors.black54),
                        ),
                      ),
                      // Slide-up panel
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SlideTransition(
                          position: _sheetSlide,
                          child: _buildChannelListPanel(),
                        ),
                      ),
                    ],

                    // 6. Gesture hint
                    AnimatedOpacity(
                      opacity: _showGestureHint ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                                color: Colors.white24, width: 1),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_gestureHintIcon,
                                  style: const TextStyle(fontSize: 36)),
                              const SizedBox(height: 6),
                              Text(
                                _gestureHintLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelListPanel() {
    return Container(
      height: 205,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF141419),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title row
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.live_tv, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Channels',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // Horizontal channel card row
          Expanded(
            child: ListView.builder(
              controller: _channelScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.channels.length,
              itemExtent: _itemWidth + 12, // card + gap
              itemBuilder: (context, index) {
                final ch = widget.channels[index];
                final isCurrent = index == _currentIndex;
                final isFocused = index == _channelListFocusIndex;

                return GestureDetector(
                  onTap: () => _switchToChannel(index),
                  child: AnimatedScale(
                    scale: isFocused ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _itemWidth,
                      margin: const EdgeInsets.only(right: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? const Color(0xFF6366f1)
                            : isCurrent
                                ? Colors.white12
                                : const Color(0xFF22222E),
                        borderRadius: BorderRadius.circular(12),
                        border: isFocused
                            ? Border.all(color: Colors.white, width: 2)
                            : isCurrent
                                ? Border.all(color: Colors.red, width: 2)
                                : Border.all(color: Colors.transparent, width: 2),
                        boxShadow: isFocused
                            ? [BoxShadow(color: Colors.white.withAlpha(80), blurRadius: 15, spreadRadius: 2)]
                            : [],
                      ),
                      child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Channel icon
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: ch.icon,
                            width: 52,
                            height: 52,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Icon(
                                Icons.tv, color: Colors.grey, size: 32),
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.tv_off, color: Colors.grey, size: 32),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Channel name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            ch.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isFocused ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: isCurrent || isFocused
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // LIVE badge for current channel
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text('LIVE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Intents ───────────────────────

class PreviousChannelIntent extends Intent {
  const PreviousChannelIntent();
}

class NextChannelIntent extends Intent {
  const NextChannelIntent();
}

class ChannelListUpIntent extends Intent {
  const ChannelListUpIntent();
}

class ChannelListDownIntent extends Intent {
  const ChannelListDownIntent();
}

class CloseChannelListIntent extends Intent {
  const CloseChannelListIntent();
}
