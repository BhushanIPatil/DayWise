import 'package:flutter/material.dart';

import 'core/app_info.dart';
import 'core/theme.dart';
import 'state/app_state.dart';
import 'ui/home_shell.dart';
import 'ui/lock_gate.dart';

class DayWiseApp extends StatelessWidget {
  const DayWiseApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(state: state, child: const _Root());
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: buildTheme(Brightness.light, s.accent),
      darkTheme: buildTheme(Brightness.dark, s.accent),
      builder: (context, child) => LockGate(child: child ?? const SizedBox.shrink()),
      home: const HomeShell(),
    );
  }
}
