import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';

/// Google AdMob: consent (UMP) -> SDK init -> banner + interstitial.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  /// True once the SDK is initialised and ads may be requested.
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);

  /// True when Google says the user must be offered a privacy-options form (EEA/UK).
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier<bool>(false);

  InterstitialAd? _interstitial;
  bool _started = false;
  bool _showingAd = false;
  int _totalSaves = 0;
  DateTime? _lastInterstitial;
  DateTime? _quietUntil;
  int _quietDepth = 0;

  /// True while a full-screen ad or a system dialog (biometric prompt, file picker,
  /// share sheet) is up. The app lock uses this so it does not re-lock the user
  /// the moment they come back from one of those.
  bool get isBusy =>
      _showingAd ||
      _quietDepth > 0 ||
      (_quietUntil != null && DateTime.now().isBefore(_quietUntil!));

  /// Wrap anything that leaves the app (system dialogs, pickers) with this.
  Future<T> quiet<T>(Future<T> Function() action) async {
    _quietDepth++;
    try {
      return await action();
    } finally {
      _quietDepth--;
      _quietUntil = DateTime.now().add(const Duration(seconds: 3));
    }
  }

  Future<void> init() async {
    if (!AdConfig.enabled || _started) return;
    _started = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSaves = prefs.getInt('adSaves') ?? 0;
    } catch (_) {}

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            _startAds();
          });
        },
        (FormError error) {
          _startAds();
        },
      );
    } catch (_) {
      _startAds();
    }
  }

  Future<void> _startAds() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      privacyOptionsRequired.value =
          status == PrivacyOptionsRequirementStatus.required;
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      ready.value = true;
      _loadInterstitial();
    } catch (_) {
      // Ads are optional. The app works without them.
    }
  }

  /// Opens Google's privacy choices form (Settings -> Ad privacy choices).
  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((FormError? error) {});
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdConfig.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) => _interstitial = null,
      ),
    );
  }

  /// Call after a NEW entry is saved. Shows an interstitial only occasionally.
  Future<void> onEntrySaved() async {
    if (!AdConfig.enabled) return;
    _totalSaves++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('adSaves', _totalSaves);
    } catch (_) {}

    if (!ready.value || _showingAd) return;
    if (_totalSaves < AdConfig.minSavesBeforeFirstAd) return;
    if ((_totalSaves - AdConfig.minSavesBeforeFirstAd) %
            AdConfig.saveInterval !=
        0) {
      return;
    }
    final last = _lastInterstitial;
    if (last != null && DateTime.now().difference(last) < AdConfig.minGap) {
      return;
    }

    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    // Let the entry sheet finish closing first.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _interstitial = null;
    _showingAd = true;
    _lastInterstitial = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _showingAd = false;
        _quietUntil = DateTime.now().add(const Duration(seconds: 3));
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        _showingAd = false;
        _loadInterstitial();
      },
    );
    ad.show();
  }
}

/// Adaptive banner. Collapses to nothing until an ad has actually loaded.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  int _width = 0;

  @override
  void initState() {
    super.initState();
    AdService.instance.ready.addListener(_maybeLoad);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _width = MediaQuery.sizeOf(context).width.truncate() - 24;
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (_ad != null || _loading || !mounted) return;
    if (!AdConfig.enabled || !AdService.instance.ready.value || _width <= 0) return;
    _loading = true;
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(_width);
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: AdConfig.banner,
      size: size ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (a) {
          if (!mounted) {
            a.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, error) {
          a.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
              _loading = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdService.instance.ready.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.enabled) return const SizedBox.shrink();
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
