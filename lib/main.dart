import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_service.dart';
import 'app.dart';
import 'data/db.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();
  final state = AppState(AppDb(), prefs);
  await state.load();

  runApp(DayWiseApp(state: state));

  // Ads start in the background after the first frame; the app never waits for them.
  AdService.instance.init();
}
