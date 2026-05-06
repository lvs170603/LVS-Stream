import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'models/channel.dart';
import 'services/api_service.dart';
import 'main.dart';

class WebPlayerPage extends StatefulWidget {
  final Channel channel;

  const WebPlayerPage({super.key, required this.channel});

  @override
  State<WebPlayerPage> createState() => _WebPlayerPageState();
}

class _WebPlayerPageState extends State<WebPlayerPage> {
  // ── State ──────────────────────────────────────────────────────
  WebViewController? _controller;
  bool _isUrlLoading = true;   // fetching URL from backend
  bool _isPageLoading = true;  // WebView page loading
  bool _hasError = false;
  String _errorMessage = '';

  // ── Lifecycle ──────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();

    // Force landscape for the player screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fetchAndLoad();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    // Restore orientation based on device type
    if (!isGlobalTVDevice) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── URL Fetch ──────────────────────────────────────────────────

  Future<void> _fetchAndLoad() async {
    setState(() {
      _isUrlLoading = true;
      _isPageLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final url = await ApiService().fetchStreamUrl(widget.channel.id);
      _buildController(url);
      if (mounted) setState(() => _isUrlLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUrlLoading = false;
          _isPageLoading = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // ── WebView Controller ─────────────────────────────────────────

  void _buildController(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isPageLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isPageLoading = false);
          },
          onWebResourceError: (error) {
            // Only surface critical errors; ignore sub-resource 4xx
            if (error.isForMainFrame == true) {
              if (mounted) {
                setState(() {
                  _isPageLoading = false;
                  _hasError = true;
                  _errorMessage = 'Failed to load player (${error.errorCode})';
                });
              }
            }
          },
          onNavigationRequest: (request) {
            // Allow all navigation inside the WebView (handles redirects)
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    if (mounted) setState(() => _controller = controller);
  }

  // ── Back Navigation ────────────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
      return false; // stay on page
    }
    return true; // exit player
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── 1. WebView ──────────────────────────────────────
            if (!_isUrlLoading && !_hasError && _controller != null)
              WebViewWidget(controller: _controller!),

            // ── 2. Full-screen loading (URL fetch + page load) ─
            if (_isUrlLoading || (_isPageLoading && !_hasError))
              _buildLoadingLayer(),

            // ── 3. Error screen ─────────────────────────────────
            if (_hasError) _buildErrorLayer(),

            // ── 4. Top bar with channel name + back button ──────
            _buildTopBar(context),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────

  Widget _buildLoadingLayer() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated logo shimmer
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.tv_rounded, color: Colors.white30, size: 40),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                color: Colors.redAccent,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isUrlLoading
                  ? 'Fetching stream…'
                  : 'Loading player…',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorLayer() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                  color: Colors.redAccent, size: 72),
              const SizedBox(height: 20),
              Text(
                widget.channel.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _fetchAndLoad,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _isPageLoading || _isUrlLoading ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 400),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black87, Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () async {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(width: 8),
                // LIVE badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                // Channel name
                Expanded(
                  child: Text(
                    widget.channel.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
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
