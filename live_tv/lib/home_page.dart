import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/channel.dart';
import 'services/api_service.dart';
import 'video_player_page.dart';
import 'radio_player_page.dart';
import 'settings_page.dart';
import 'services/ad_manager.dart';
import 'widgets/mini_player.dart';
import 'main.dart';

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

      final categoryOrder = [
        "Entertainment",
        "Movies",
        "Music",
        "Comedy",
        "Spiritual",
        "News",
        "Sports"
      ];

      // 1. Group channels
      final Map<String, List<Channel>> groupedCategories = {};
      for (var c in filteredChannels) {
        final cat = c.category.isNotEmpty ? c.category : "Others";
        groupedCategories.putIfAbsent(cat, () => []).add(c);
      }

      // 2. Sort categories based on categoryOrder
      final List<String> sortedKeys = groupedCategories.keys.toList()..sort((a, b) {
        int indexA = categoryOrder.indexOf(a);
        int indexB = categoryOrder.indexOf(b);
        if (indexA == -1 && indexB == -1) return a.compareTo(b); // Alphabetical if both unknown
        if (indexA == -1) return 1; // Put unknown at the end
        if (indexB == -1) return -1; // Put unknown at the end
        return indexA.compareTo(indexB);
      });

      // 3. Flatten into a single list
      final List<Channel> sortedChannels = [];
      for (var key in sortedKeys) {
        sortedChannels.addAll(groupedCategories[key]!);
      }

      if (isLoading) {
        mainContent = _buildSkeletonGrid();
      } else if (sortedChannels.isEmpty) {
        mainContent = const Center(child: Text("No channels found.", style: TextStyle(color: Colors.white70)));
      } else {
        mainContent = GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: sortedChannels.length,
          itemBuilder: (context, index) {
            final channel = sortedChannels[index];
            return _ChannelCard(
              channel: channel, 
              channels: sortedChannels // Fixes channel +/- skipping across wrong orders
            );
          },
        );
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: isMobile ? Drawer(backgroundColor: Theme.of(context).colorScheme.surface, child: _buildSidebar(isMobile: true)) : null,
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar (Desktop style)
              if (!isMobile)
                Container(
                  width: 300,
                  color: Theme.of(context).colorScheme.surface,
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
                          color: Theme.of(context).colorScheme.surface,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Builder(
                                    builder: (context) => IconButton(
                                      icon: Icon(Icons.menu, color: Theme.of(context).iconTheme.color),
                                      onPressed: () => Scaffold.of(context).openDrawer(),
                                      tooltip: 'Open Menu',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "LVS Live TV",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(Icons.refresh, color: Theme.of(context).iconTheme.color),
                                onPressed: _refreshChannelsFromBackend,
                                tooltip: 'Refresh Channels',
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    Expanded(child: mainContent),
                    
                    const AdBanner(),
                  ],
                ),
              ),
            ],
          ),
          
          const Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: MiniPlayer(),
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
              Text(
                "LVS Live TV",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (!isMobile)
                IconButton(
                  icon: Icon(Icons.refresh, color: Theme.of(context).iconTheme.color),
                  onPressed: _refreshChannelsFromBackend,
                  tooltip: 'Refresh Channels',
                ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SidebarItem(
                icon: Icons.tv,
                title: 'Live TV',
                isSelected: _selectedIndex == 0,
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  if (isMobile && Navigator.canPop(context)) Navigator.pop(context);
                },
              ),
              _SidebarItem(
                icon: Icons.radio,
                title: 'Radio',
                isSelected: _selectedIndex == 1,
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  if (isMobile && Navigator.canPop(context)) Navigator.pop(context);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              _SidebarItem(
                icon: Icons.settings,
                title: 'Settings',
                isSelected: false,
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.title,
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
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: _isFocused ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isSelected ? theme.colorScheme.onSurface.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: _isFocused ? Border.all(color: theme.colorScheme.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
          boxShadow: _isFocused
              ? [BoxShadow(color: theme.colorScheme.primary.withAlpha(80), blurRadius: 15, spreadRadius: 2)]
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
                  Icon(
                    widget.icon, 
                    color: widget.isSelected || _isFocused ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.isSelected || _isFocused ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Light mode palette
    const Color lightCardBg       = Colors.white;
    const Color lightIconBubble   = Color(0xFFF0F4FF);  // Very light blue tint
    const Color lightFocusBubble  = Color(0xFFE3F2FD);  // Material blue-50
    const Color lightBorder       = Color(0xFFE0E0E0);  // Visible TV border
    const Color lightFocusBorder  = Color(0xFF2196F3);  // OTT blue focus ring
    const Color lightCategoryText = Color(0xFF555555);

    // Dark mode palette
    const Color darkCardBg        = Color(0xFF1E1E28);
    const Color darkIconBubble    = Color(0xFF2A2A38);
    const Color darkFocusBubble   = Color(0xFF2D2D42);

    final cardColor    = isDark ? darkCardBg : lightCardBg;
    final iconBubble   = isDark
        ? (_isFocused ? darkFocusBubble : darkIconBubble)
        : (_isFocused ? lightFocusBubble : lightIconBubble);
    final borderColor  = _isFocused
        ? lightFocusBorder
        : (isDark ? Colors.transparent : lightBorder);
    final borderWidth  = _isFocused ? 2.5 : (isDark ? 0.0 : 1.0);
    final shadowColor  = _isFocused
        ? colorScheme.primary.withOpacity(0.35)
        : (isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.08));
    final shadowBlur   = _isFocused ? 18.0 : 10.0;
    final shadowSpread = _isFocused ? 2.0 : 0.0;

    return AnimatedScale(
      scale: _isFocused ? 1.06 : 1.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: shadowBlur,
              spreadRadius: shadowSpread,
              offset: _isFocused ? Offset.zero : const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            splashColor: colorScheme.primary.withOpacity(0.12),
            highlightColor: colorScheme.primary.withOpacity(0.06),
            onTap: () {
              if (widget.channel.url.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Stream not available")),
                );
                return;
              }
              if (_isLoading) return;
              setState(() => _isLoading = true);
              Future.delayed(const Duration(milliseconds: 50), () {
                AdManager.instance.showInterstitialIfReady(() {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
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
                    
                    // Force landscape before navigating
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeLeft,
                      DeviceOrientation.landscapeRight,
                    ]);
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerPage(
                          channels: widget.channels,
                          initialIndex: index,
                        ),
                      ),
                    ).then((_) {
                      // Restore orientation behavior based on device type
                      if (!isGlobalTVDevice) {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]);
                      }
                    });
                  }
                });
              });
            },
            onFocusChange: (value) => setState(() => _isFocused = value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon bubble
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 72,
                    width: 72,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBubble,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.channel.icon,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Icon(
                            Icons.tv_rounded,
                            color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
                            size: 36,
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.tv_off_rounded,
                            color: isDark ? Colors.white38 : const Color(0xFF90A4AE),
                            size: 36,
                          ),
                        ),
                        if (_isLoading)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Channel name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      widget.channel.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.25,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Category badge
                  if (widget.channel.category.isNotEmpty)
                    Text(
                      widget.channel.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white38
                            : lightCategoryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
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

class _SkeletonChannelCard extends StatelessWidget {
  const _SkeletonChannelCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: isDark ? 4 : 6,
      shadowColor: Colors.black.withOpacity(isDark ? 0.4 : 0.10),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[850]! : const Color(0xFFEEEEEE),
        highlightColor: isDark ? Colors.grey[700]! : const Color(0xFFFAFAFA),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 13,
                width: 90,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 11,
                width: 55,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
