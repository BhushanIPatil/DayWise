// One-time project setup. Run from the project root:
//
//     dart tool/setup.dart --org com.yourname
//
// What it does:
//   1. runs `flutter create` to generate the android/ folder (if missing)
//   2. installs the DayWise manifest, themes and MainActivity (needed for ads + app lock)
//   3. patches android/app/build.gradle.kts: minSdk 24, release signing, AdMob app id
//   4. runs `flutter pub get` and generates the launcher icons
//
// --org is YOUR reverse-domain id. The Play Store package name becomes <org>.daywise
// and can never be changed after you publish, so choose it carefully.

import 'dart:io';

const String _testAdmobAppId = 'ca-app-pub-3940256099942544~3347511713';

Future<void> main(List<String> args) async {
  final org = _arg(args, '--org');
  final valid = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');
  if (org == null || !valid.hasMatch(org) || org.startsWith('com.example')) {
    stderr.writeln('Usage: dart tool/setup.dart --org com.yourname');
    stderr.writeln(
      '  (lowercase letters, digits, underscores and dots; "com.example" is not allowed)',
    );
    exit(64);
  }
  if (!File('pubspec.yaml').existsSync() ||
      !File('lib/main.dart').existsSync()) {
    stderr.writeln(
      'Run this from the project root (the folder containing pubspec.yaml).',
    );
    exit(66);
  }

  if (!Directory('android').existsSync()) {
    _step('Generating the Android project');
    await _run('flutter', [
      'create',
      '.',
      '--platforms=android',
      '--org',
      org,
      '--project-name',
      'daywise',
    ]);
  } else {
    _step('android/ already exists - keeping it');
  }

  _updateBuildVersions();

  _step('Installing manifest, themes and MainActivity');
  _copy(
    'tool/android/AndroidManifest.xml',
    'android/app/src/main/AndroidManifest.xml',
  );
  _copy(
    'tool/android/styles.xml',
    'android/app/src/main/res/values/styles.xml',
  );
  _copy(
    'tool/android/styles-night.xml',
    'android/app/src/main/res/values-night/styles.xml',
  );
  _copy(
    'tool/android/key.properties.example',
    'android/key.properties.example',
  );
  _writeMainActivity();

  _step('Patching android/app/build.gradle');
  _patchGradle();

  _step('Setting the AdMob app id (test id for now)');
  final props = File('android/gradle.properties');
  final text = props.existsSync() ? props.readAsStringSync() : '';
  if (!text.contains('admobAppId=')) {
    props.writeAsStringSync(
      '$text${text.endsWith('\n') || text.isEmpty ? '' : '\n'}admobAppId=$_testAdmobAppId\n',
    );
  }

  // `flutter create` adds a counter-app test that no longer matches this app.
  final stale = File('test/widget_test.dart');
  if (stale.existsSync() && stale.readAsStringSync().contains('MyApp')) {
    stale.deleteSync();
  }

  _step('Fetching packages');
  await _run('flutter', ['pub', 'get']);

  _step('Generating launcher icons');
  await _run('dart', ['run', 'flutter_launcher_icons']);

  stdout.writeln('\nDone. Next:');
  stdout.writeln('  flutter run                  # try it on a phone/emulator');
  stdout.writeln(
    '  see docs/RELEASE_GUIDE.md    # AdMob ids, signing key, Play Store upload',
  );
}

// ----------------------------------------------------------------------------

void _updateBuildVersions() {
  final settings = File('android/settings.gradle.kts');
  if (settings.existsSync()) {
    var text = settings.readAsStringSync();
    text = text.replaceAll(
      RegExp(r'id\("com.android.application"\) version "[^"]+"'),
      'id("com.android.application") version "9.5.0"',
    );
    text = text.replaceAll(
      RegExp(r'id\("org.jetbrains.kotlin.android"\) version "[^"]+"'),
      'id("org.jetbrains.kotlin.android") version "2.4.21"',
    );
    settings.writeAsStringSync(text);
  }
  final wrapper = File('android/gradle/wrapper/gradle-wrapper.properties');
  if (wrapper.existsSync()) {
    wrapper.writeAsStringSync(
      wrapper.readAsStringSync().replaceAll(
        RegExp(r'gradle-[\d.]+-(all|bin)\.zip'),
        'gradle-9.8.2-all.zip',
      ),
    );
  }
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}

void _step(String msg) => stdout.writeln('\n==> $msg');

Future<void> _run(String cmd, List<String> args) async {
  final p = await Process.start(
    cmd,
    args,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await p.exitCode;
  if (code != 0) {
    stderr.writeln('`$cmd ${args.join(' ')}` failed with exit code $code');
    exit(code);
  }
}

void _copy(String from, String to) {
  final src = File(from);
  if (!src.existsSync()) {
    stderr.writeln('Missing template: $from');
    exit(66);
  }
  File(to).parent.createSync(recursive: true);
  src.copySync(to);
}

void _writeMainActivity() {
  final root = Directory('android/app/src/main');
  File? existing;
  for (final e in root.listSync(recursive: true)) {
    if (e is File &&
        (e.path.endsWith('MainActivity.kt') ||
            e.path.endsWith('MainActivity.java'))) {
      existing = e;
      if (e.path.endsWith('.kt')) break;
    }
  }
  String? pkg;
  if (existing != null) {
    final m = RegExp(
      r'^\s*package\s+([\w.]+)',
      multiLine: true,
    ).firstMatch(existing.readAsStringSync());
    pkg = m?.group(1);
  }
  if (pkg == null) {
    final gradle = _gradleFile();
    final m = gradle == null
        ? null
        : RegExp(
            r'applicationId\s*=?\s*"([\w.]+)"',
          ).firstMatch(gradle.readAsStringSync());
    pkg = m?.group(1);
  }
  if (pkg == null) {
    stderr.writeln(
      'Could not work out the package name. Edit MainActivity manually (see docs/RELEASE_GUIDE.md).',
    );
    return;
  }
  final dir = existing != null
      ? existing.parent.path
      : 'android/app/src/main/kotlin/${pkg.replaceAll('.', '/')}';
  if (existing != null && existing.path.endsWith('.java')) {
    existing.deleteSync();
  }
  Directory(dir).createSync(recursive: true);
  File('$dir/MainActivity.kt').writeAsStringSync(
    'package $pkg\n\n'
    'import io.flutter.embedding.android.FlutterFragmentActivity\n\n'
    '// local_auth (app lock) requires a FragmentActivity.\n'
    'class MainActivity : FlutterFragmentActivity()\n',
  );
}

File? _gradleFile() {
  final kts = File('android/app/build.gradle.kts');
  if (kts.existsSync()) return kts;
  final groovy = File('android/app/build.gradle');
  return groovy.existsSync() ? groovy : null;
}

void _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  if (!kts.existsSync()) {
    stderr.writeln(
      'WARNING: android/app/build.gradle.kts not found (older Flutter uses build.gradle).\n'
      'Apply the manual steps in docs/RELEASE_GUIDE.md section "Manual Gradle edits".',
    );
    return;
  }
  var s = kts.readAsStringSync();
  if (s.contains('keystoreProperties')) {
    stdout.writeln('Already patched.');
    return;
  }

  s = 'import java.io.FileInputStream\nimport java.util.Properties\n\n$s';

  // 1. load key.properties just before the android { block
  s = s.replaceFirstMapped(
    RegExp(r'\nandroid\s*\{'),
    (m) =>
        '\nval keystoreProperties = Properties()\n'
        'val keystorePropertiesFile = rootProject.file("key.properties")\n'
        'if (keystorePropertiesFile.exists()) {\n'
        '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
        '}\n\n'
        'android {',
  );

  // 2. minSdk 24 (needed by the ads SDK) + AdMob app id placeholder
  var minSdkPatched = false;
  s = s.replaceFirstMapped(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion'), (m) {
    minSdkPatched = true;
    return 'minSdk = 24\n'
        '        manifestPlaceholders["admobAppId"] = (project.findProperty("admobAppId") as String?) ?: "$_testAdmobAppId"';
  });
  if (!minSdkPatched) {
    stderr.writeln(
      'WARNING: could not find minSdk line; set minSdk = 24 and the admobAppId placeholder manually.',
    );
  }

  // 3. release signing config
  var signingPatched = false;
  s = s.replaceFirstMapped(RegExp(r'\n(\s*)buildTypes\s*\{'), (m) {
    signingPatched = true;
    final i = m[1] ?? '    ';
    return '\n${i}signingConfigs {\n'
        '$i    create("release") {\n'
        '$i        if (keystorePropertiesFile.exists()) {\n'
        '$i            keyAlias = keystoreProperties["keyAlias"] as String\n'
        '$i            keyPassword = keystoreProperties["keyPassword"] as String\n'
        '$i            storeFile = file(keystoreProperties["storeFile"] as String)\n'
        '$i            storePassword = keystoreProperties["storePassword"] as String\n'
        '$i        }\n'
        '$i    }\n'
        '$i}\n\n'
        '${i}buildTypes {';
  });
  s = s.replaceFirstMapped(
    RegExp(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'),
    (m) =>
        'signingConfig = signingConfigs.getByName("release")',
  );
  if (!signingPatched) {
    stderr.writeln(
      'WARNING: could not add the signing config; follow the manual steps in docs/RELEASE_GUIDE.md.',
    );
  }

  kts.writeAsStringSync(s);
}
