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
  
  // Ad Frequency logic
  int _channelClickCount = 0;
  final int _adClickThreshold = 3; // Show ad every 3 clicks
  
  DateTime? _lastAdShownTime;
  final Duration _adCooldown = const Duration(seconds: 60); // 60 seconds cooldown

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
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

  /// Should be called whenever a channel is clicked
  void showInterstitialIfReady(VoidCallback onContinue) {
    _channelClickCount++;

    bool meetsTimeCondition = true;
    if (_lastAdShownTime != null) {
      meetsTimeCondition = DateTime.now().difference(_lastAdShownTime!) >= _adCooldown;
    }

    // Check Combined Logic: At least 3 clicks AND at least 60 seconds passed
    if (_channelClickCount < _adClickThreshold || !meetsTimeCondition) {
      debugPrint("Ad conditions not met (Clicks: $_channelClickCount/$_adClickThreshold, Time ok: $meetsTimeCondition). Skipping ad.");
      onContinue();
      return;
    }

    // 3. Show Ad if Loaded
    if (_interstitialAd == null) {
      debugPrint("Interstitial ad not ready yet. Skipping.");
      _loadInterstitialAd(); // Try to load one just in case
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
    
    // Reset counters and timers
    _channelClickCount = 0;
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
