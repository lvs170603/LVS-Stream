import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Wraps the entire app and shows a non-dismissible animated banner
/// at the top whenever there is no internet connection.
/// Automatically hides when connectivity is restored.
///
/// Design:
/// - Slides down from the top (no dialog → no stacking issues).
/// - Never shows twice simultaneously (guarded by [_isOffline]).
/// - Handles WiFi ↔ mobile data switches gracefully.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),  // starts above the screen
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    // Check initial state
    Connectivity().checkConnectivity().then(_handleResult);

    // Listen for changes
    _sub = Connectivity().onConnectivityChanged.listen(_handleResult);
  }

  void _handleResult(List<ConnectivityResult> results) {
    final hasInternet = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    if (!hasInternet && !_isOffline) {
      setState(() => _isOffline = true);
      _animController.forward();
    } else if (hasInternet && _isOffline) {
      _animController.reverse().then((_) {
        if (mounted) setState(() => _isOffline = false);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Offline banner — only mounted when ever offline at least once
        if (_isOffline || _animController.isAnimating)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: const _OfflineBanner(),
            ),
          ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    // Respect system safe area (notch / status bar)
    final topPadding = MediaQuery.of(context).padding.top;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 14),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFE53935)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'No Internet Connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Please turn on WiFi or Mobile Data.',
                    style: TextStyle(
                      color: Color(0xFFFFCDD2),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Spinner to show the app is actively watching for reconnection
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
