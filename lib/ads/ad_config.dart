import 'package:flutter/foundation.dart';

/// AdMob configuration.
///
/// BEFORE PUBLISHING:
///  1. In the AdMob console create an app, then a Banner and an Interstitial ad unit.
///  2. Paste the two ad UNIT ids below (they contain a slash: ca-app-pub-123/456).
///  3. Put your AdMob APP id (contains a tilde: ca-app-pub-123~456) in
///     android/gradle.properties as  admobAppId=ca-app-pub-123~456
///
/// While these are empty, and always in debug builds, Google's official TEST ads are
/// used. Never click your own real ads - that can get your AdMob account banned.
class AdConfig {
  AdConfig._();

  /// Launch without ads. Set to true and restart the app to enable ads later.
  static const bool enabled = false;

  // TODO: paste real ad unit ids.
  static const String _bannerReal = '';
  static const String _interstitialReal = '';

  static const String _bannerTest = 'ca-app-pub-3940256099942544/9214589741';
  static const String _interstitialTest = 'ca-app-pub-3940256099942544/1033173712';

  static bool get usingTestAds =>
      !kReleaseMode || _bannerReal.isEmpty || _interstitialReal.isEmpty;

  static String get banner => usingTestAds ? _bannerTest : _bannerReal;
  static String get interstitial => usingTestAds ? _interstitialTest : _interstitialReal;

  // Interstitial pacing. Kept gentle on purpose: aggressive ads cost ratings and installs.
  /// No interstitial until the user has saved this many entries in total.
  static const int minSavesBeforeFirstAd = 6;

  /// After that, one every N saved entries...
  static const int saveInterval = 4;

  /// ...but never more often than this.
  static const Duration minGap = Duration(minutes: 4);
}
