# Release guide: from this folder to Google Play

## Requirements checked on 5 November 2026

* New phone/tablet submissions and updates must target API 36 or higher:
  https://support.google.com/googleplay/android-developer/answer/11926878
  The installed Flutter SDK supplies compile/target API 36; the app minimum is API 24.
* Build with the pinned stable AGP 9.5.0, Gradle 9.8.2, Kotlin 2.4.21 and Java 17.
  Flutter compatibility flags in gradle.properties remain necessary for plugins.
* Verify the final release bundle's 16 KB native-library/page alignment in Play Console
  and run it on a 16 KB emulator. Updated tools alone do not prove runtime compatibility:
  https://developer.android.com/guide/practices/page-sizes
* Review the merged release manifest and Data safety disclosures for every bundled SDK:
  https://developers.google.com/admob/android/privacy/play-data-disclosure
* Configure AdMob Privacy & messaging for EEA/UK/Switzerland and applicable US states.
  Test consent, refusal, and reopening Settings > Ad privacy choices with test devices:
  https://developers.google.com/admob/flutter/privacy
* Before upload, replace developer/contact placeholders, host the matching privacy policy,
  configure real AdMob IDs, create the upload signing key, complete Ads, Data safety,
  target audience, content rating, financial features and developer verification in Play Console.
  Select the actual audience; excluding children must reflect the app's real audience.
* Device checks: backup save/restore/share, biometric/PIN lock and cancellation, consent,
  banners/interstitials, edge-to-edge insets, and large-screen layouts on API 36+.
  Complete Play Console's required testing and pre-launch report before production.

These are release requirements to verify, not a guarantee of Play approval.

### Local verification on 5 November 2026

Using installed Flutter 3.47.1 / Dart 3.13.1 and the versions above:
`flutter analyze` passed, all 36 `flutter test` cases passed, and `flutter build apk --debug`
produced `build/app/outputs/flutter-apk/app-debug.apk`.
APK metadata confirms target/compile SDK 36 and minimum SDK 24.
`zipalign -c -P 16 4` passed, and all nine packaged ARM64/x86-64 shared libraries
have ELF load alignment >=16384 bytes. These checks cover the debug artifact;
repeat them for the signed release and test on a 16 KB device/emulator.

## 0. One-time setup (do this first)
    dart tool/setup.dart --org com.yourname
    flutter analyze
    flutter test
    flutter run

Your Play package name is `<org>.daywise` (e.g. `com.yourname.daywise`). It is permanent once published.

### If something does not compile
Use Flutter >=3.38.1 and Dart >=3.10, Java 17, and SDK 36. The current project uses
google_mobile_ads 9.x, local_auth 3.x, share_plus 13.x, and file_picker 13.x.
The code uses their current APIs; do not downgrade to the old plugin versions.
Run `flutter pub outdated` after updates. Some indirect versions are constrained by
Flutter or the plugins; do not bypass those constraints with dependency overrides.
Commit `pubspec.lock` so release builds use the dependency versions you tested.

### Manual Gradle edits (only if setup.dart printed a WARNING)
In `android/app/build.gradle.kts`:
* `defaultConfig { minSdk = 24; manifestPlaceholders["admobAppId"] = (project.findProperty("admobAppId") as String?) ?: "ca-app-pub-3940256099942544~3347511713" }`
* add the `keystoreProperties` loading block and a `signingConfigs { create("release") { ... } }`, then
  `buildTypes { release { signingConfig = signingConfigs.getByName("release") } }`
  (the standard recipe: docs.flutter.dev/deployment/android#sign-the-app)
* `MainActivity` must extend `FlutterFragmentActivity` (app lock) and `styles.xml` must use `Theme.AppCompat` parents.

## 1. Fill in your details
* `lib/core/app_info.dart`: `developer` and `contactEmail` (shown in the in-app privacy policy)
* `docs/privacy_policy.html` and `docs/PRIVACY_POLICY.md`: replace `YOUR NAME` and `your-email@example.com`
  (and the date if you change the policy). Keep them identical to the in-app text in `lib/ui/privacy_text.dart`.

## 2. Host the privacy policy (Play requires a URL)
Easiest free options: GitHub Pages (put `privacy_policy.html` in a public repo, enable Pages) or a Google Site.
Paste the public URL into Play Console. The text must match the in-app policy.

## 3. AdMob
1. admob.google.com -> Apps -> Add app (Android; "not yet published" is fine).
2. Copy the **App ID** (`ca-app-pub-XXXX~YYYY`) into `android/gradle.properties`: `admobAppId=ca-app-pub-XXXX~YYYY`
3. Create a **Banner** and an **Interstitial** ad unit; paste their ids into `lib/ads/ad_config.dart`
   (`_bannerReal`, `_interstitialReal`).
4. Until both are set, and in debug builds, Google TEST ads are shown. Never click your own live ads.
5. After publishing, link the Play listing in AdMob -> App settings. Set up the EEA/UK consent message in
   AdMob -> Privacy & messaging (the app already calls Google's UMP consent API; the message must exist in AdMob).
6. Add `app-ads.txt` only if you own a developer website (optional).

## 4. Create the signing key (once, keep it safe!)
    keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
Copy `android/key.properties.example` to `android/key.properties` and fill it in. Back up the `.jks` file and
passwords somewhere safe (not in git). With Play App Signing, a lost *upload* key can be reset, but do not rely on it.

## 5. Version + build
`pubspec.yaml` -> `version: 1.0.0+1` (the number after `+` must increase with every upload).

    flutter build appbundle --release
Output: `build/app/outputs/bundle/release/app-release.aab`. Configure `android/key.properties`
and the upload key first. Release builds require release signing; they do not fall back to a debug key.

Optional: `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols` (keep `build/symbols`).

## 6. Play Console
1. Create a developer account (one-time US$25 fee, identity verification).
2. Create app -> Free -> declare it contains ads.
3. Fill: store listing (`docs/STORE_LISTING.md`, graphics in `store/`), privacy policy URL, App content
   (`docs/DATA_SAFETY.md`), content rating, target audience, data safety.
4. Production or testing track -> create release -> upload the `.aab`.
5. **New personal developer accounts must first run a closed test with a minimum number of testers for
   a minimum number of days (at the time of writing: 12 testers for 14 days) before production access.**
   Check the current rule in Play Console under Testing and release; organisation accounts are exempt.
6. Check the pre-launch report and any "target API level" warning (Flutter's current default is normally fine).

## 7. Pre-launch checklist
- [ ] `flutter analyze` clean, `flutter test` passes
- [ ] Tried on a real phone: add / edit / delete, week, insights, dark mode, rotate (locked to portrait)
- [ ] Recurring: add a monthly rule starting last month -> entries appear on the calendar; stop the rule -> old entries remain
- [ ] Backup -> uninstall -> reinstall -> restore works
- [ ] App lock works, and also after switching apps for > 20 s
- [ ] Real AdMob ids in `ad_config.dart` + `gradle.properties`; ads show (test ads first)
- [ ] developer name + email filled in app and in the hosted policy
- [ ] version code increased; signed with the upload key
- [ ] 2+ real phone screenshots uploaded
