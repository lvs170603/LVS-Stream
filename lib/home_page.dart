import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/channel.dart';
import 'services/api_service.dart';
import 'video_player_page.dart';
import 'radio_player_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Channel> channels = [];
  bool isLoading = true;
  int _selectedIndex = 0;

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
    final isMobile = MediaQuery.of(context).size.width <= 800;

    Widget mainContent;
    {
      final isRadioFilter = _selectedIndex == 1;
      final filteredChannels = channels.where((c) {
        final isCategoryRadio = c.category.toLowerCase() == 'radio';
        return isRadioFilter ? isCategoryRadio : !isCategoryRadio;
      }).toList();

      mainContent = isLoading
          ? _buildSkeletonGrid()
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.8,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredChannels.length,
              itemBuilder: (context, index) {
                final channel = filteredChannels[index];
                return _ChannelCard(channel: channel, channels: filteredChannels);
              },
            );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f13),
      drawer: isMobile ? Drawer(backgroundColor: const Color(0xFF141419), child: _buildSidebar(isMobile: true)) : null,
      body: Row(
        children: [
          // Sidebar (Desktop style)
          if (!isMobile)
            Container(
              width: 300,
              color: const Color(0xFF141419),
              child: _buildSidebar(isMobile: false),
            ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Mobile Header
                if (isMobile)
                  SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      color: const Color(0xFF141419),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Builder(
                                builder: (context) => IconButton(
                                  icon: const Icon(Icons.menu, color: Colors.white),
                                  onPressed: () => Scaffold.of(context).openDrawer(),
                                  tooltip: 'Open Menu',
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "LVS Live TV",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
                
                // Channel Grid or Settings
                Expanded(child: mainContent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 15,
      itemBuilder: (context, index) {
        return const _SkeletonChannelCard();
      },
    );
  }

  Widget _buildSidebar({bool isMobile = false}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: isMobile ? 48.0 : 24.0, left: 24.0, right: 24.0, bottom: 24.0),
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
              if (!isMobile)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshChannelsFromBackend,
                  tooltip: 'Refresh Channels',
                ),
            ],
          ),
        ),
        _buildNavItem(0, Icons.tv, 'TV Channels', isMobile),
        _buildNavItem(1, Icons.radio, 'Radio Channels', isMobile),
        _buildNavItem(2, Icons.settings, 'Settings', isMobile),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title, bool isMobile) {
    return _SidebarItem(
      index: index,
      icon: icon,
      title: title,
      isMobile: isMobile,
      isSelected: _selectedIndex == index,
      onTap: () {
        if (index == 2) {
          // Push Settings as a proper route so BACK returns here
          if (isMobile) Navigator.pop(context); // close drawer first
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        } else {
          setState(() {
            _selectedIndex = index;
          });
          if (isMobile) Navigator.pop(context);
        }
      },
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final String title;
  final bool isMobile;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.index,
    required this.icon,
    required this.title,
    required this.isMobile,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isSelected ? Colors.white.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: _isFocused ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
          boxShadow: _isFocused
              ? [BoxShadow(color: Colors.white.withAlpha(80), blurRadius: 15, spreadRadius: 2)]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onFocusChange: (value) => setState(() => _isFocused = value),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.isSelected || _isFocused ? Colors.white : Colors.white54),
                  const SizedBox(width: 16),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.isSelected || _isFocused ? Colors.white : Colors.white54,
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
      scale: _isFocused ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: _isFocused ? Border.all(color: Colors.white, width: 3) : Border.all(color: Colors.transparent, width: 3),
          boxShadow: _isFocused
            ? [BoxShadow(color: Colors.white.withAlpha(80), blurRadius: 20, spreadRadius: 3)]
            : [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: const Color(0xFF1E1E28),
          borderRadius: BorderRadius.circular(16),
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
              final radioChannels = widget.channels.where((c) => c.category.toLowerCase() == 'radio').toList();
              final index = radioChannels.indexOf(widget.channel);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RadioPlayerPage(
                    channels: radioChannels,
                    initialIndex: index,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.channel.category,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _SkeletonChannelCard extends StatelessWidget {
  const _SkeletonChannelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E28),
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[850]!,
        highlightColor: Colors.grey[700]!,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 14,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
