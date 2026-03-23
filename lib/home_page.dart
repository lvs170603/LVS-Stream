import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/channel.dart';
import 'services/api_service.dart';
import 'video_player_page.dart';
import 'radio_player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Channel> channels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadChannels();
  }

  Future<void> loadChannels() async {
    final box = Hive.box('channelsBox');
    final String? cachedData = box.get('channels');
    
    if (cachedData != null) {
      final List<dynamic> data = json.decode(cachedData);
      setState(() {
        channels = data.map((json) => Channel.fromJson(json)).toList();
        isLoading = false;
      });
    } else {
      await _refreshChannelsFromBackend();
    }
  }

  Future<void> _refreshChannelsFromBackend() async {
    setState(() {
      isLoading = true;
    });
    try {
      final apiService = ApiService();
      final fetchedChannels = await apiService.fetchChannels();
      
      // Update local cache
      final box = Hive.box('channelsBox');
      final channelsJsonList = fetchedChannels.map((c) => c.toJson()).toList();
      await box.put('channels', json.encode(channelsJsonList));

      if (mounted) {
        setState(() {
          channels = fetchedChannels;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching channels: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh channels. Please check your internet connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f13),
      body: Row(
        children: [
          // Sidebar (Desktop style)
          if (MediaQuery.of(context).size.width > 800)
            Container(
              width: 300,
              color: const Color(0xFF141419),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "LVS Live TV",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _refreshChannelsFromBackend,
                          tooltip: 'Refresh Channels',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Mobile Header
                if (MediaQuery.of(context).size.width <= 800)
                  SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      color: const Color(0xFF141419),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "LVS Live TV",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            onPressed: _refreshChannelsFromBackend,
                            tooltip: 'Refresh Channels',
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Channel Grid
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: channels.length,
                          itemBuilder: (context, index) {
                            final channel = channels[index];
                            return _ChannelCard(channel: channel, channels: channels);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final Channel channel;
  final List<Channel> channels;

  const _ChannelCard({required this.channel, required this.channels});

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Material(
        color: _isFocused ? Colors.white : const Color(0xFF1E1E28),
        borderRadius: BorderRadius.circular(16),
        elevation: _isFocused ? 12 : 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (widget.channel.url.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Stream not available")),
              );
              return;
            }
            if (widget.channel.category.toLowerCase() == 'radio') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RadioPlayerPage(
                    channel: widget.channel,
                  ),
                ),
              );
            } else {
              final index = widget.channels.indexOf(widget.channel);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerPage(
                    channels: widget.channels,
                    initialIndex: index,
                  ),
                ),
              );
            }
          },
          onFocusChange: (value) {
            setState(() {
              _isFocused = value;
            });
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 80,
                width: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isFocused ? Colors.grey[200] : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.channel.icon,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Icon(Icons.tv, color: Colors.grey, size: 40),
                  errorWidget: (context, url, error) => const Icon(Icons.tv_off, color: Colors.grey, size: 40),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  widget.channel.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isFocused ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.channel.category,
                style: TextStyle(
                  color: _isFocused ? Colors.black54 : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
