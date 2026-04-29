import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  static final AdManager instance = AdManager._init();
  AdManager._init();

  // Real Production Ad Units
  final String _interstitialAdUnitId = 'ca-app-pub-2468428188857257/2851937387';
  final String _bannerAdUnitId = 'ca-app-pub-2468428188857257/6208728461';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  
  // Passive Time-Based logic
  DateTime? _lastAdShownTime;
  final Duration _adCooldown = const Duration(minutes: 5); // 5 minutes ad-free window

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    
    // Start tracking the 5-minute grace period silently as soon as the app successfully launches
    _lastAdShownTime = DateTime.now();
    
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    if (_isInterstitialAdLoading || _interstitialAd != null) return;
    
    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          debugPrint('InterstitialAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
          // Retry later logic could be added here
        },
      ),
    );
  }

  /// Smart trigger validates if the 5-minute passive viewing threshold has expired.
  /// If it has expired, and the user triggers a physical action, intercept it with an Ad!
  void showInterstitialIfReady(VoidCallback onContinue) {

    bool meetsTimeCondition = true;
    if (_lastAdShownTime != null) {
      meetsTimeCondition = DateTime.now().difference(_lastAdShownTime!) >= _adCooldown;
    }

    // Check Passive Time Window
    if (!meetsTimeCondition) {
      debugPrint("Under 5-minute ad-free umbrella. Skipping ad visually without interrupting flow.");
      onContinue();
      return;
    }

    // Show Ad if Loaded. If they hit the threshold but the network hasn't buffered an ad yet, drop it so we never freeze the UI.
    if (_interstitialAd == null) {
      debugPrint("Interstitial ad hit timing threshold but ad wasn't heavily buffered yet. Skipping.");
      _loadInterstitialAd(); 
      onContinue();
      return;
    }

    // Attach callback right before showing to ensure the current context's continuation runs
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        onContinue(); // Continue to channel
        _loadInterstitialAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        onContinue(); // Continue to channel
        _loadInterstitialAd(); // Retry loading
      },
    );

    debugPrint("Showing Interstitial Ad");
    _interstitialAd!.show();
    
    // Reset passive tracker for the next 5 empty minutes
    _lastAdShownTime = DateTime.now();
  }

  // Helper method for the banner ID
  String get bannerAdUnitId => _bannerAdUnitId;
}

/// A Reusable Banner Ad Widget
class AdBanner extends StatefulWidget {
  final AdSize size;
  
  const AdBanner({
    super.key, 
    this.size = AdSize.banner,
  });

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  AdSize? _adaptiveSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null && _adaptiveSize == null) {
      _loadBannerAd();
    }
  }

  Future<void> _loadBannerAd() async {
    final size = MediaQuery.of(context).size;
    final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      size.width.truncate()
    );

    _adaptiveSize = adSize ?? widget.size;
    if (!mounted) return;

    _bannerAd = BannerAd(
      adUnitId: AdManager.instance.bannerAdUnitId,
      request: const AdRequest(),
      size: _adaptiveSize!,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _bannerAd != null) {
      return Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    // Return empty sized box when loading or failed
    return const SizedBox(height: 50); 
  }
}
